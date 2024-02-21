// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

// ==============================================================
// _______                   __________________       ________             _____                  ______
// ___    |______ ______________  /__(_)__  __/____  ____  __ \______________  /_____________________  /
// __  /| |_  __ `__ \__  __ \_  /__  /__  /_ __  / / /_  /_/ /_  ___/  __ \  __/  __ \  ___/  __ \_  / 
// _  ___ |  / / / / /_  /_/ /  / _  / _  __/ _  /_/ /_  ____/_  /   / /_/ / /_ / /_/ / /__ / /_/ /  /  
// /_/  |_/_/ /_/ /_/_  .___//_/  /_/  /_/    _\__, / /_/     /_/    \____/\__/ \____/\___/ \____//_/   
//                   /_/                      /____/                                                    
// ==============================================================
// ==================== IDiscountedAmplify ======================
// ==============================================================
// Amplify Protocol: https://github.com/AmplifyProtocol

// ==============================================================

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IDiscountedAmplify {

    struct Option {
        uint256 amount;
        uint256 strike;
        uint256 expiry;
        bool exercised;
    }

    // ============================================================================================
    // External Functions
    // ============================================================================================

    // view functions

    /// @notice Returns the amount to pay to exercise an option
    /// @param _id The id of the option
    /// @return _amountToPay The amount to pay
    function amountToPay(uint256 _id) external view returns (uint256 _amountToPay);

    /// @notice Returns the strike price of an option
    /// @param _id The id of the option
    /// @return _strike The strike price
    function strike(uint256 _id) external view returns (uint256 _strike);

    /// @notice Returns the amount of underlying token for an option
    /// @param _id The id of the option
    /// @return _amount The amount of underlying token
    function amount(uint256 _id) external view returns (uint256 _amount);

    /// @notice Returns the expiry of an option
    /// @param _id The id of the option
    /// @return _expiry The expiry of the option
    function expiry(uint256 _id) external view returns (uint256 _expiry);

    /// @notice Returns the price of the underlying token, in USD, with 18 decimals
    /// @return _price The price of the underlying token
    function price() external view returns (uint256 _price);

    /// @notice Returns whether an option has been exercised
    /// @param _id The id of the option
    /// @return _exercised Whether the option has been exercised
    function exercised(uint256 _id) external view returns (bool _exercised);

    /// @notice Returns the settlement token. A USD stablecoin
    /// @return _token The settlement token
    function payWith() external view returns (address _token);

    // mutated functions

    /// @notice Adds rewards to a gauge
    /// @param _amount The amount of rewards to add
    /// @param _gauge The gauge to add rewards to
    function addRewards(uint256 _amount, address _gauge) external;

    /// @notice Mints an option
    /// @param _amount The amount of underlying tokens to mint
    /// @param _receiver The address to receive the option
    /// @return _id The id of the option
    function mint(uint256 _amount, address _receiver) external returns (uint256 _id);

    /// @notice Exercises an option
    /// @param _id The id of the option
    /// @param _receiver The address to receive the underlying tokens
    /// @param _useFlashLoan Whether to use a flash loans
    function exercise(uint256 _id, address _receiver, bool _useFlashLoan) external;

    /// @notice Refunds an unexercised expired option
    /// @param _ids The ids of the options to refund
    /// @return _amount The amount of underlying tokens refunded
    function refund(uint256[] memory _ids) external returns (uint256 _amount);

    // Owner

    /// @notice Sets the minter
    /// @param _minter The address of the minter
    function setMinter(address _minter) external;

    /// @notice Sets whether an address is a score gauge
    /// @param _scoreGauge The address of the score gauge
    /// @param _isScoreGauge Whether the address is a score gauge
    function setScoreGauge(address _scoreGauge, bool _isScoreGauge) external;

    /// @notice Sets the settlement token
    /// @param _usd The address of the settlement token
    function setUSD(IERC20Metadata _usd) external;

    /// @notice Sets the discount
    /// @param _discount The discount
    function setDiscount(uint256 _discount) external;

    /// @notice Sets the treasury
    /// @param _treasury The address of the treasury
    function setTreasury(address _treasury) external;

    /// @notice Sets the price oracle
    /// @param _priceOracle The address of the price oracle
    function setPriceOracle(address _priceOracle) external;

    /// @notice Sets the flash loan handler
    /// @param _flashLoanHandler The address of the flash loan handler
    function setFlashLoanHandler(address _flashLoanHandler) external;

    // ============================================================================================
    // Events
    // ============================================================================================

    event AddRewards(uint256 amount, address gauge);
    event Mint(uint256 price, uint256 amount, uint256 strike, uint256 expiry, uint256 id, address gauge, address receiver);
    event Exercise(uint256 amount, uint256 strike, uint256 id, address receiver, address sender);
    event Refund(address sender, address receiver, uint256 amount, uint256 strike, uint256 id);
    event SetMinter(address minter);
    event SetScoreGauge(address scoreGauge, bool isScoreGauge);
    event SetUSD(IERC20Metadata usd);
    event SetDiscount(uint256 discount);
    event SetTreasury(address treasury);
    event SetPriceOracle(address priceOracle);
    event SetFlashLoanHandler(address flashLoanHandler);

    // ============================================================================================
    // Errors
    // ============================================================================================

    error NotMinter();
    error NotScoreGauge();
    error Expired();
    error AlreadyExercised();
    error NotOwner();
    error ZeroAddress();
    error MinterAlreadySet();
    error InvalidDiscount();
}