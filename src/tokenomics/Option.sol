// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.24;

// ==============================================================
// _______                   __________________       ________             _____                  ______
// ___    |______ ______________  /__(_)__  __/____  ____  __ \______________  /_____________________  /
// __  /| |_  __ `__ \__  __ \_  /__  /__  /_ __  / / /_  /_/ /_  ___/  __ \  __/  __ \  ___/  __ \_  / 
// _  ___ |  / / / / /_  /_/ /  / _  / _  __/ _  /_/ /_  ____/_  /   / /_/ / /_ / /_/ / /__ / /_/ /  /  
// /_/  |_/_/ /_/ /_/_  .___//_/  /_/  /_/    _\__, / /_/     /_/    \____/\__/ \____/\___/ \____//_/   
//                   /_/                      /____/                                                    
// ==============================================================
// ========================== Option ============================
// ==============================================================
// Amplify Protocol: https://github.com/AmplifyProtocol

// ==============================================================

import {Auth, Authority} from "@solmate/auth/Auth.sol";

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IFlashLoanHandler} from "./utilities/interfaces/IFlashLoanHandler.sol";
import {IPriceOracle} from "./utilities/interfaces/IPriceOracle.sol";

import {IOption, IERC20Metadata} from "./interfaces/IOption.sol";

/// @title Option
/// @author johnnyonline
/// @notice Creates and manages options
contract Option is IOption, Auth, ERC721, ReentrancyGuard {

    using SafeERC20 for IERC20Metadata;

    uint256 public discount;
    uint256 public id;

    address public treasury;
    address public minter;

    IERC20Metadata public usd;
    IPriceOracle public priceOracle;
    IFlashLoanHandler public flashLoanHandler;

    mapping(address => bool) public isScoreGauge;
    mapping(address => uint256) public rewards;
    mapping(uint256 => Option) public options;

    IERC20Metadata public immutable underlying;

    uint256 public constant OPTION_EXPIRY = 7 days;
    uint256 public constant BASE = 100;
    uint256 public constant DECIMALS = 18;

    // ============================================================================================
    // Constructor
    // ============================================================================================

    /// @notice Contract constructor
    /// @param _authority Authority contract
    /// @param _underlying The option's underlying token
    /// @param _usd USD stablecoin address
    /// @param _priceOracle Price oracle address
    /// @param _flashLoanHandler Flash loan handler address
    /// @param _treasury Treasury address
    /// @param _name Token full name
    /// @param _symbol Token symbol
    constructor(
        Authority _authority,
        IERC20Metadata _underlying,
        IERC20Metadata _usd,
        address _priceOracle,
        address _flashLoanHandler,
        address _treasury,
        string memory _name,
        string memory _symbol
    ) Auth(address(0), _authority) ERC721(_name, _symbol) {
        if (_priceOracle == address(0)) revert ZeroAddress();
        if (_treasury == address(0)) revert ZeroAddress();

        underlying = _underlying;
        usd = _usd;

        priceOracle = IPriceOracle(_priceOracle);
        flashLoanHandler = IFlashLoanHandler(_flashLoanHandler);

        treasury = _treasury;

        discount = 100; // 100%
    }

    // ============================================================================================
    // Modifiers
    // ============================================================================================

    /// @notice Ensures the caller is the Minter
    modifier onlyMinter() {
        if (msg.sender != minter) revert NotMinter();
        _;
    }

    /// @notice Ensures the caller is a ScoreGauge
    modifier onlyScoreGauge() {
        if (!isScoreGauge[msg.sender]) revert NotScoreGauge();
        _;
    }

    // ============================================================================================
    // External View Functions
    // ============================================================================================

    /// @inheritdoc IOption
    function amountToPay(uint256 _id) public view returns (uint256 _amountToPay) {
        uint256 _decimals = DECIMALS;
        Option memory _option = options[_id];
        _amountToPay = _option.strike * _option.amount / 10 ** _decimals;
        _amountToPay = usd.decimals() == _decimals ? _amountToPay : _amountToPay / 10 ** (_decimals - usd.decimals());
    }

    /// @inheritdoc IOption
    function strike(uint256 _id) external view returns (uint256) {
        return options[_id].strike;
    }

    /// @inheritdoc IOption
    function amount(uint256 _id) external view returns (uint256) {
        return options[_id].amount;
    }

    /// @inheritdoc IOption
    function expiry(uint256 _id) external view returns (uint256) {
        return options[_id].expiry;
    }

    /// @inheritdoc IOption
    function price() external view returns (uint256) {
        return _getPrice();
    }

    /// @inheritdoc IOption
    function exercised(uint256 _id) external view returns (bool) {
        return options[_id].exercised;
    }

    /// @inheritdoc IOption
    function payWith() external view returns (address) {
        return address(usd);
    }

    // ============================================================================================
    // External Mutated Functions
    // ============================================================================================

    /// @inheritdoc IOption
    function addRewards(uint256 _amount, address _gauge) external nonReentrant onlyMinter {
        rewards[_gauge] += _amount;

        emit AddRewards(_amount, _gauge);
    }

    /// @inheritdoc IOption
    function mint(uint256 _amount, address _receiver) external nonReentrant onlyScoreGauge returns (uint256) {
        rewards[msg.sender] -= _amount;

        id++;

        _safeMint(_receiver, id);

        uint256 _price = _getPrice();
        uint256 _strike = _price * (BASE - discount) / BASE;
        uint256 _expiry = block.timestamp + OPTION_EXPIRY;
        options[id] = Option(_amount, _strike, _expiry, false);

        emit Mint(_price, _amount, _strike, _expiry, id, msg.sender, _receiver);

        return id;
    }

    /// @inheritdoc IOption
    function exercise(uint256 _id, address _receiver, bool _useFlashLoan) external {
        if (_requireOwned(_id) != msg.sender) revert NotOwner();

        Option storage _option = options[_id];
        if (_option.expiry < block.timestamp) revert Expired();
        if (_option.exercised) revert AlreadyExercised();

        _option.exercised = true;
        _burn(_id);

        uint256 _amountToPay = amountToPay(_id);
        if (_useFlashLoan && _option.strike > 0) {
            underlying.safeTransfer(address(flashLoanHandler), _option.amount);
            /// @dev swaps just enough PUPPET to USD, sends USD to treasury and remaining PUPPET to _receiver
            flashLoanHandler.execute(_amountToPay, address(usd), treasury, _receiver);
        } else {
            usd.safeTransferFrom(msg.sender, treasury, _amountToPay);
            underlying.safeTransfer(_receiver, _option.amount);
        }

        emit Exercise(_option.amount, _option.strike, _id, _receiver, msg.sender);
    }

    /// @inheritdoc IOption
    function refund(uint256[] memory _ids) external returns (uint256 _amount) {
        for (uint256 i = 0; i < _ids.length; i++) {
            Option storage _option = options[_ids[i]];
            if (_option.expiry < block.timestamp && !_option.exercised) {
                address _owner = ownerOf(_ids[i]);

                _amount += _option.amount;

                _option.exercised = true;
                _burn(_ids[i]);

                underlying.safeTransfer(treasury, _option.amount);

                emit Refund(msg.sender, _owner, _option.amount, _option.strike, _ids[i]);
            }
        }
    }

    // Owner

    /// @inheritdoc IOption
    function setMinter(address _minter) external requiresAuth {
        if (minter != address(0)) revert MinterAlreadySet();

        minter = _minter;

        emit SetMinter(_minter);
    }

    /// @inheritdoc IOption
    function setScoreGauge(address _scoreGauge, bool _isScoreGauge) external requiresAuth {
        isScoreGauge[_scoreGauge] = _isScoreGauge;

        emit SetScoreGauge(_scoreGauge, _isScoreGauge);
    }

    /// @inheritdoc IOption
    function setUSD(IERC20Metadata _usd) external requiresAuth {
        usd = _usd;

        emit SetUSD(_usd);
    }

    /// @inheritdoc IOption
    function setDiscount(uint256 _discount) external requiresAuth {
        if (_discount > BASE) revert InvalidDiscount();

        discount = _discount;

        emit SetDiscount(_discount);
    }

    /// @inheritdoc IOption
    function setTreasury(address _treasury) external requiresAuth {
        treasury = _treasury;

        emit SetTreasury(_treasury);
    }

    /// @inheritdoc IOption
    function setPriceOracle(address _priceOracle) external requiresAuth {
        priceOracle = IPriceOracle(_priceOracle);

        emit SetPriceOracle(_priceOracle);
    }

    /// @inheritdoc IOption
    function setFlashLoanHandler(address _flashLoanHandler) external requiresAuth {
        flashLoanHandler = IFlashLoanHandler(_flashLoanHandler);

        emit SetFlashLoanHandler(_flashLoanHandler);
    }

    // ============================================================================================
    // Internal Functions
    // ============================================================================================

    /// @notice Returns the current price of PUPPET in USD with 18 decimals
    /// @return _price Current price of PUPPET in USD with 18 decimals
    function _getPrice() internal view returns (uint256 _price) {
        _price = priceOracle.price();
    }
}