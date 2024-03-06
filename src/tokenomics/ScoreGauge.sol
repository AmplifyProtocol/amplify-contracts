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
// ======================= ScoreGauge ===========================
// ==============================================================
// Amplify Protocol: https://github.com/AmplifyProtocol

// ==============================================================

import {Auth, Authority} from "@solmate/auth/Auth.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {CommonHelper, OrchestratorHelper, IDataStore} from "../integrations/libraries/OrchestratorHelper.sol";

import {IMinter} from "./interfaces/IMinter.sol";
import {IDiscountedAmplify} from "./interfaces/IDiscountedAmplify.sol";
import {IVotingEscrow} from "./interfaces/IVotingEscrow.sol";
import {IGaugeController} from "./interfaces/IGaugeController.sol";
import {IScoreGauge} from "./interfaces/IScoreGauge.sol";

/// @title Score Gauge
/// @author johnnyonline
/// @notice Used to measure scores of Traders and Copy-traders, according to pre defined metrics with configurable weights, and distributes rewards to them
contract ScoreGauge is IScoreGauge, IERC721Receiver, Auth, ReentrancyGuard {

    using SafeERC20 for IERC20;
    using Address for address payable;

    bool private _isKilled;

    mapping(uint256 => EpochInfo) public epochInfo; // epoch => EpochInfo

    uint256 internal constant _BASIS_POINTS_DIVISOR = 10_000;
    uint256 internal constant _PRECISION = 1e18;
    address internal constant _WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    IERC20 public immutable token;
    IMinter public immutable minter;
    IDiscountedAmplify public immutable dToken;
    IDataStore public immutable dataStore;
    IVotingEscrow public immutable votingEscrow;
    IGaugeController public immutable controller;

    // ============================================================================================
    // Constructor
    // ============================================================================================

    /// @notice Contract constructor
    /// @param _authority The Authority contract
    /// @param _votingEscrow The VotingEscrow contract address
    /// @param _minter The Minter contract address
    /// @param _dataStore The DataStore contract address
    /// @param _dToken The dAMPL contract address
    /// @param _token The Amplify token contract address
    constructor(
        Authority _authority,
        IVotingEscrow _votingEscrow,
        IMinter _minter,
        IDataStore _dataStore,
        IDiscountedAmplify _dToken,
        IERC20 _token
    ) Auth(address(0), _authority) {
        votingEscrow = _votingEscrow;
        minter = _minter;
        dataStore = _dataStore;
        dToken = _dToken;

        token = _token;

        controller = IGaugeController(_minter.controller());
    }

    // ============================================================================================
    // Modifiers
    // ============================================================================================

    /// @notice Ensures the caller is a route
    modifier onlyRoute() {
        if (!CommonHelper.isRouteRegistered(dataStore, msg.sender)) revert NotRoute();
        _;
    }

    // ============================================================================================
    // External Functions
    // ============================================================================================

    // view functions

    /// @inheritdoc IScoreGauge
    function claimableRewards(uint256 _epoch, address _user) external view returns (uint256) {
        return _claimableRewards(_epoch, _user);
    }

    /// @inheritdoc IScoreGauge
    function userPerformance(uint256 _epoch, address _user) external view returns (uint256 _volume, uint256 _profit) {
        EpochInfo storage _epochInfo = epochInfo[_epoch];
        _volume = _epochInfo.userPerformance[_user].volume;
        _profit = _epochInfo.userPerformance[_user].profit;
    }

    /// @inheritdoc IScoreGauge
    function hasClaimed(uint256 _epoch, address _user) external view returns (bool) {
        return epochInfo[_epoch].claimed[_user];
    }

    /// @inheritdoc IScoreGauge
    function isKilled() external view returns (bool) {
        return _isKilled;
    }

    /// @inheritdoc IERC721Receiver
    function onERC721Received(address, address, uint256, bytes calldata) external view returns (bytes4) {
        if (msg.sender != address(dToken)) revert NotOption();

        return this.onERC721Received.selector;
    }

    // mutated functions

    /// @inheritdoc IScoreGauge
    function claim(uint256 _epoch, address _receiver) external nonReentrant returns (uint256 _rewards, uint256 _id) {
        (_rewards, _id) = _claim(_epoch, _receiver);
    }

    /// @inheritdoc IScoreGauge
    function claimMany(
        uint256[] calldata _epochs,
        address _receiver
    ) external nonReentrant returns (uint256 _rewards, uint256[] memory _ids) {
        _ids = new uint256[](_epochs.length);
        for (uint256 i = 0; i < _epochs.length; i++) {
            uint256 _reward;
            (_reward, _ids[i]) = _claim(_epochs[i], _receiver);

            _rewards += _reward;
        }
    }

    /// @inheritdoc IScoreGauge
    function claimAndExcercise(
        uint256 _epoch,
        address _receiver,
        bool _useFlashLoan
    ) external nonReentrant returns (uint256 _rewards, uint256 _id) {
        (_rewards, _id) = _claimAndExcercise(_epoch, _receiver, _useFlashLoan);
    }

    /// @inheritdoc IScoreGauge
    function claimAndExcerciseMany(
        uint256[] calldata _epochs,
        address _receiver,
        bool _useFlashLoan
    ) external nonReentrant returns (uint256 _rewards, uint256[] memory _ids) {
        uint256 _epochsLength = _epochs.length;
        _ids = new uint256[](_epochsLength);
        for (uint256 i = 0; i < _epochsLength; i++) {
            uint256 _reward;
            (_reward, _ids[i]) = _claimAndExcercise(_epochs[i], _receiver, _useFlashLoan);

            _rewards += _reward;
        }
    }

    /// @inheritdoc IScoreGauge
    function claimExcerciseAndLock(
        uint256 _epoch,
        uint256 _unlockTime,
        bool _useFlashLoan
    ) external nonReentrant returns (uint256 _rewards, uint256 _id) {
        (_rewards, _id) = _claimAndExcercise(_epoch, address(this), _useFlashLoan);

        _lock(_rewards, _unlockTime);
    }

    /// @inheritdoc IScoreGauge
    function claimExcerciseAndLockMany(
        uint256[] memory _epochs,
        uint256 _unlockTime,
        bool _useFlashLoan
    ) external nonReentrant returns (uint256 _rewards, uint256[] memory _ids) {
        uint256 _epochsLength = _epochs.length;
        _ids = new uint256[](_epochsLength);
        for (uint256 i = 0; i < _epochsLength; i++) {
            uint256 _reward;
            (_reward, _ids[i]) = _claimAndExcercise(_epochs[i], address(this), _useFlashLoan);

            _rewards += _reward;
        }

        _lock(_rewards, _unlockTime);
    }

    /// @inheritdoc IScoreGauge
    function addRewards(uint256 _epoch, uint256 _amount) external nonReentrant {
        if (msg.sender != address(minter)) revert NotMinter();

        _updateWeights(_epoch);

        EpochInfo storage _epochInfo = epochInfo[_epoch];
        if (_epochInfo.profitWeight > 0) _epochInfo.profitRewards += _amount * _epochInfo.profitWeight / _BASIS_POINTS_DIVISOR;
        if (_epochInfo.volumeWeight > 0) _epochInfo.volumeRewards += _amount * _epochInfo.volumeWeight / _BASIS_POINTS_DIVISOR;

        emit DepositRewards(_amount);
    }

    /// @inheritdoc IScoreGauge
    function updateUsersScore(address _route) external onlyRoute {
        if (!_isKilled) {
            (
                uint256[] memory _volumes,
                uint256[] memory _profits,
                address[] memory _users
            ) = OrchestratorHelper.usersScore(dataStore, _route);

            uint256 _epoch = controller.epoch();
            EpochInfo storage _epochInfo = epochInfo[_epoch];

            for (uint256 i = 0; i < _users.length; i++) _updateUserScore(_epochInfo, _volumes[i], _profits[i], _users[i]);

            _updateWeights(_epoch);
        }
    }

    /// @inheritdoc IScoreGauge
    function updateReferrerScore(uint256 _volume, uint256 _profit, address _user) external {
        if (msg.sender != address(this)) revert InvalidCaller(); // called by `updateUsersScore` using `OrchestratorHelper`

        if (!_isKilled) {
            uint256 _epoch = controller.epoch();
            EpochInfo storage _epochInfo = epochInfo[_epoch];

            _updateUserScore(_epochInfo, _volume, _profit, _user);

            _updateWeights(_epoch);
        }
    }

    /// @inheritdoc IScoreGauge
    function killMe() external requiresAuth {
        _isKilled = true;
    }

    // ============================================================================================
    // Internal Functions
    // ============================================================================================

    function _claimableRewards(uint256 _epoch, address _user) internal view returns (uint256) {
        EpochInfo storage _epochInfo = epochInfo[_epoch];
        if (_epochInfo.claimed[_user]) return 0;

        uint256 _userProfit = _epochInfo.userPerformance[_user].profit;
        uint256 _userVolume = _epochInfo.userPerformance[_user].volume;
        if (_userProfit == 0 && _userVolume == 0) return 0;

        uint256 _userProfitRewards = 0;
        if (_userProfit > 0 && _epochInfo.profitRewards > 0) {
            _userProfitRewards = _userProfit * _epochInfo.profitRewards / _epochInfo.totalProfit;
        }

        uint256 _userVolumeRewards = 0;
        if (_userVolume > 0 && _epochInfo.volumeRewards > 0) {
            _userVolumeRewards = _userVolume * _epochInfo.volumeRewards / _epochInfo.totalVolume;
        }

        return _userProfitRewards + _userVolumeRewards;
    }

    function _claim(uint256 _epoch, address _receiver) internal returns (uint256 _rewards, uint256 _id) {
        if (_epoch >= IGaugeController(controller).epoch()) revert InvalidEpoch();

        EpochInfo storage _epochInfo = epochInfo[_epoch];
        if (_epochInfo.claimed[msg.sender]) revert AlreadyClaimed();

        _rewards = _claimableRewards(_epoch, msg.sender);
        if (_rewards == 0) revert NoRewards();

        _epochInfo.claimed[msg.sender] = true;

        _id = dToken.mint(_rewards, _receiver);

        emit Claim(_epoch, _rewards, msg.sender, _receiver);
    }

    function _updateUserScore(EpochInfo storage _epochInfo, uint256 _volume, uint256 _profit, address _user) internal {
        _epochInfo.userPerformance[_user].volume += _volume;
        _epochInfo.userPerformance[_user].profit += _profit;
        _epochInfo.totalVolume += _volume;
        _epochInfo.totalProfit += _profit;

        emit UserScoreUpdate(_user, _volume, _profit);
    }

    function _updateWeights(uint256 _epoch) internal {
        EpochInfo storage _epochInfo = epochInfo[_epoch];
        if (_epochInfo.profitWeight == 0 && _epochInfo.volumeWeight == 0) {
            IGaugeController _controller = controller;
            _epochInfo.profitWeight = _controller.profitWeight();
            _epochInfo.volumeWeight = _controller.volumeWeight();
            if (_epochInfo.profitWeight == 0 && _epochInfo.volumeWeight == 0) revert InvalidWeights();

            emit WeightsUpdate(_epochInfo.profitWeight, _epochInfo.volumeWeight);
        }
    }

    function _claimAndExcercise(
        uint256 _epoch,
        address _receiver,
        bool _useFlashLoan
    ) internal returns (uint256 _rewards, uint256 _id) {
        (_rewards, _id) = _claim(_epoch, address(this));

        IDiscountedAmplify _dToken = dToken;
        if (!_useFlashLoan) {
            uint256 _amountToPay = _dToken.amountToPay(_id);
            IERC20 _usd = IERC20(_dToken.payWith());
            _usd.safeTransferFrom(msg.sender, address(this), _amountToPay);
            _usd.forceApprove(address(_dToken), _amountToPay);
        }

        _dToken.exercise(_id, _receiver, _useFlashLoan);
    }

    function _lock(uint256 _tokenAmount, uint256 _unlockTime) internal {
        IVotingEscrow _votingEscrow = votingEscrow;
        if (_votingEscrow.lockedEnd(msg.sender) != 0) {
            token.forceApprove(address(_votingEscrow), _tokenAmount);
            _votingEscrow.modifyLock(_tokenAmount, _unlockTime, msg.sender);
        } else {
            revert NoLock();
        }
    }
}