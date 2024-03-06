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
// ===================== OrchestratorHelper =====================
// ==============================================================
// Amplify Protocol: https://github.com/AmplifyProtocol

// ==============================================================

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {CommonHelper, Keys, IDataStore} from "./CommonHelper.sol";
import {SharesHelper} from "./SharesHelper.sol";

import {IReferralManager} from "../../utilities/interfaces/IReferralManager.sol";

import {IScoreGauge} from "../../tokenomics/interfaces/IScoreGauge.sol";

import {IBaseOrchestrator, IBaseRoute} from "../interfaces/IBaseOrchestrator.sol";
import {IBaseRouteFactory} from "../interfaces/IBaseRouteFactory.sol";

/// @title OrchestratorHelper
/// @author johnnyonline
/// @notice Helper functions for Orchestrator
library OrchestratorHelper {

    using SafeCast for int256;

    struct ScoreData {
        uint256 length;
        uint256[] volumes;
        uint256[] profits;
        address[] users;
    }

    // ============================================================================================
    // View Functions
    // ============================================================================================

    function validateRouteKey(IDataStore _dataStore, bytes32 _routeKey) public view returns (address _route) {
        _route = CommonHelper.routeAddress(_dataStore, _routeKey);
        if (_route == address(0)) revert RouteNotRegistered();
    }

    function validatePuppetInput(IDataStore _dataStore, uint256 _amount, address _puppet, address _token) external view {
        if (_amount == 0) revert ZeroAmount();
        if (_puppet == address(0)) revert ZeroAddress();
        if (_token == address(0)) revert ZeroAddress();
        if (!_dataStore.getBool(Keys.isCollateralTokenKey(_token))) revert NotCollateralToken();
    }

    function validatePuppets(IDataStore _dataStore, address _route, address[] memory _puppets) external view {
        uint256 _puppetsLength = _puppets.length;
        if (CommonHelper.isPositionOpen(_dataStore, _route)) {
            if (_puppetsLength > 0) revert InvalidPuppetsArray();
        } else {
            if (CommonHelper.maxPuppets(_dataStore) < _puppetsLength) revert PuppetsArrayExceedsMaxPuppets();
            for (uint256 i = 0; i < _puppetsLength; i++) {
                if (CommonHelper.puppetSubscriptionExpiry(_dataStore, _puppets[i], _route) <= block.timestamp) revert PuppetSubscriptionExpired();
            }
        }
    }

    function validateExecutionFees(
        IDataStore _dataStore,
        IBaseRoute.SwapParams memory _swapParams,
        IBaseRoute.ExecutionFees memory _executionFees
    ) external view {
        uint256 _executionFee = _executionFees.dexKeeper + _executionFees.puppetKeeper;
        if (
            msg.value == 0 ||
            msg.value < _executionFee ||
            msg.value > _executionFee && _swapParams.path[0] != CommonHelper.wnt(_dataStore) ||
            msg.value > _executionFee && _swapParams.amount != msg.value - _executionFee ||
            _executionFees.dexKeeper < CommonHelper.minExecutionFee(_dataStore) ||
            (_executionFees.puppetKeeper > 0 && _executionFees.puppetKeeper < CommonHelper.minPuppetExecutionFee(_dataStore))
        ) revert InvalidExecutionFee();
    }

    // ============================================================================================
    // Mutated Function
    // ============================================================================================

    function registerRoute(
        IDataStore _dataStore,
        address _trader,
        bytes32 _routeTypeKey
    ) external returns (address _route, bytes32 _routeKey) {
        if (!_dataStore.getBool(Keys.isRouteTypeRegisteredKey(_routeTypeKey))) revert RouteTypeNotRegistered();

        _routeKey = CommonHelper.routeKey(_dataStore, _trader, _routeTypeKey);
        if (CommonHelper.isRouteRegistered(_dataStore, _routeKey)) revert RouteAlreadyRegistered();

        _route = IBaseRouteFactory(_dataStore.getAddress(Keys.ROUTE_FACTORY)).registerRoute(_dataStore, _routeTypeKey);

        _dataStore.updateOwnership(_route, true);

        _dataStore.setAddress(Keys.routeCollateralTokenKey(_route), _dataStore.getAddress(Keys.routeTypeCollateralTokenKey(_routeTypeKey)));
        _dataStore.setAddress(Keys.routeIndexTokenKey(_route), _dataStore.getAddress(Keys.routeTypeIndexTokenKey(_routeTypeKey)));
        _dataStore.setAddress(Keys.routeAddressKey(_routeKey), _route);
        _dataStore.setAddress(Keys.routeTraderKey(_route), _trader);

        _dataStore.setBool(Keys.routeIsLongKey(_route), _dataStore.getBool(Keys.routeTypeIsLongKey(_routeTypeKey)));
        _dataStore.setBool(Keys.isRouteRegisteredKey(_route), true);

        _dataStore.setBytes32(Keys.routeRouteTypeKey(_route), _routeTypeKey);

        _dataStore.pushAddressArray(Keys.ROUTES, _route);
    }

    function updateSubscription(
        IDataStore _dataStore,
        uint256 _expiry,
        uint256 _allowance,
        address _caller,
        address _trader,
        address _puppet,
        bytes32 _routeTypeKey
    ) external returns (address _route) {
        if (_caller != _dataStore.getAddress(Keys.MULTI_SUBSCRIBER)) _puppet = _caller;

        _route = validateRouteKey(_dataStore, CommonHelper.routeKey(_dataStore, _trader, _routeTypeKey));
        if (_dataStore.getBool(Keys.isWaitingForCallbackKey(_route))) revert RouteWaitingForCallback();

        {
            bytes32 _puppetSubscriptionExpiryKey = Keys.puppetSubscriptionExpiryKey(_puppet, _route);
            bytes32 _puppetSubscribedAtKey = Keys.puppetSubscribedAtKey(_puppet, _route);
            bytes32 _puppetAllowancesKey = Keys.puppetAllowancesKey(_puppet);
            if (_expiry > 0) {
                if (_allowance > CommonHelper.basisPointsDivisor() || _allowance == 0) revert InvalidAllowancePercentage();
                if (_expiry < block.timestamp + 24 hours) revert InvalidSubscriptionExpiry();

                _dataStore.setUint(_puppetSubscriptionExpiryKey, _expiry);
                _dataStore.setUint(_puppetSubscribedAtKey, block.timestamp);

                _dataStore.addAddressToUint(_puppetAllowancesKey, _route, _allowance);
            } else {
                if (_allowance != 0) revert InvalidAllowancePercentage();
                if (block.timestamp < _dataStore.getUint(_puppetSubscribedAtKey) + 24 hours) revert CannotUnsubscribeYet();

                _dataStore.removeUint(_puppetSubscriptionExpiryKey);
                _dataStore.removeUint(_puppetSubscribedAtKey);

                _dataStore.removeUintToAddress(_puppetAllowancesKey, _route);
            }
        }
    }

    function updateLastPositionOpenedTimestamp(
        IDataStore _dataStore,
        address _route,
        address[] memory _puppets
    ) external returns (bytes32 _routeType) {
        _routeType = _dataStore.getBytes32(Keys.routeRouteTypeKey(_route));
        for (uint256 i = 0; i < _puppets.length; i++) {
            _dataStore.setUint(Keys.puppetLastPositionOpenedTimestampKey(_puppets[i], _routeType), block.timestamp);
        }
    }

    function updateExecutionFeeBalance(IDataStore _dataStore, uint256 _fee, bool _increase) external {
        _increase
        ? _dataStore.incrementUint(Keys.EXECUTION_FEE_BALANCE, _fee)
        : _dataStore.decrementUint(Keys.EXECUTION_FEE_BALANCE, _fee);
    }

    function withdrawPlatformFees(IDataStore _dataStore, address _token) external returns (uint256 _balance, address _platformFeeRecipient) {
        _balance = _dataStore.getUint(Keys.platformAccountKey(_token));
        if (_balance == 0) revert ZeroAmount();

        _platformFeeRecipient = _dataStore.getAddress(Keys.PLATFORM_FEES_RECIPIENT);
        if (_platformFeeRecipient == address(0)) revert ZeroAddress();

        _dataStore.setUint(Keys.platformAccountKey(_token), 0);
    }

    function setInitializeData(
        IDataStore _dataStore,
        uint256 _minExecutionFee,
        address _wnt,
        address _platformFeesRecipient,
        address _routeFactory,
        address _gauge,
        address _referralManager
    ) external {
        _dataStore.setUint(Keys.MIN_EXECUTION_FEE, _minExecutionFee);
        _dataStore.setAddress(Keys.WNT, _wnt);
        _dataStore.setAddress(Keys.PLATFORM_FEES_RECIPIENT, _platformFeesRecipient);
        _dataStore.setAddress(Keys.ROUTE_FACTORY, _routeFactory);
        _dataStore.setAddress(Keys.SCORE_GAUGE, _gauge);
        _dataStore.setAddress(Keys.REFERRAL_MANAGER, _referralManager);
        _dataStore.setAddress(Keys.ORCHESTRATOR, address(this));

        uint256 _maxPuppets = 100;
        _dataStore.setUint(Keys.MAX_PUPPETS, _maxPuppets);

        _dataStore.setBool(Keys.PAUSED, false);
    }

    function setRouteType(
        IDataStore _dataStore,
        bytes32 _routeTypeKey,
        address _collateralToken,
        address _indexToken,
        bool _isLong,
        bytes memory _data
    ) external {
        _dataStore.setAddress(Keys.routeTypeCollateralTokenKey(_routeTypeKey), _collateralToken);
        _dataStore.setAddress(Keys.routeTypeIndexTokenKey(_routeTypeKey), _indexToken);

        _dataStore.setBool(Keys.routeTypeIsLongKey(_routeTypeKey), _isLong);
        _dataStore.setBool(Keys.isRouteTypeRegisteredKey(_routeTypeKey), true);
        _dataStore.setBool(Keys.isCollateralTokenKey(_collateralToken), true);

        _dataStore.setUint(Keys.collateralTokenDecimalsKey(_collateralToken), 10 ** IERC20Metadata(_collateralToken).decimals());

        _dataStore.setBytes(Keys.routeTypeDataKey(_routeTypeKey), _data);
    }

    function updateFees(IDataStore _dataStore, uint256 _managementFee, uint256 _withdrawalFee, uint256 _performanceFee) external {
        _dataStore.setUint(Keys.MANAGEMENT_FEE, _managementFee);
        _dataStore.setUint(Keys.WITHDRAWAL_FEE, _withdrawalFee);
        _dataStore.setUint(Keys.PERFORMANCE_FEE, _performanceFee);
    }

    function debitPuppetAccount(
        IDataStore _dataStore,
        uint256 _amount,
        address _token,
        address _puppet,
        bool _isWithdraw
    ) external returns (uint256 _feeAmount) {
        _feeAmount = (
            _isWithdraw
            ? (_amount * _dataStore.getUint(Keys.WITHDRAWAL_FEE))
            : (_amount * _dataStore.getUint(Keys.MANAGEMENT_FEE))
        ) / CommonHelper.basisPointsDivisor();

        _dataStore.decrementUint(Keys.puppetDepositAccountKey(_puppet, _token), _amount);
        _dataStore.incrementUint(Keys.platformAccountKey(_token), _feeAmount);
    }

    function usersScore(
        IDataStore _dataStore,
        address _route
    ) external returns (uint256[] memory _volumes, uint256[] memory _profits, address[] memory _users) {
        uint256 _positionIndex = _dataStore.getUint(Keys.positionIndexKey(_route));
        uint256 _cumulativeVolumeGenerated = _dataStore.getUint(Keys.cumulativeVolumeGeneratedKey(_positionIndex, _route));
        if (_cumulativeVolumeGenerated > 0) {
            uint256 _puppetsProfitInUSD = 0;
            int256 _puppetsPnL = _dataStore.getInt(Keys.puppetsPnLKey(_positionIndex, _route));
            address _collateralToken = CommonHelper.collateralToken(_dataStore, _route);
            if (_puppetsPnL < 0) {
                _puppetsProfitInUSD = IBaseOrchestrator(CommonHelper.orchestrator(_dataStore)).getPrice(_collateralToken)
                    * ((_puppetsPnL * -1).toUint256()) / CommonHelper.collateralTokenDecimals(_dataStore, _collateralToken);
            }

            uint256 _totalSupply = _dataStore.getUint(Keys.positionTotalSupplyKey(_positionIndex,_route));
            ScoreData memory _scoreData = _usersScoreData(
                _dataStore,
                _route,
                _cumulativeVolumeGenerated,
                _totalSupply,
                _puppetsProfitInUSD
            );

            return (_scoreData.volumes, _scoreData.profits, _scoreData.users);
        }
    }

    // ============================================================================================
    // Private Functions
    // ============================================================================================

    function _usersScoreData(
        IDataStore _dataStore,
        address _route,
        uint256 _cumulativeVolumeGenerated,
        uint256 _totalSupply,
        uint256 _puppetsProfitInUSD
    ) private returns (ScoreData memory _scoreData) {
        uint256 _positionIndex = _dataStore.getUint(Keys.positionIndexKey(_route));
        uint256 _traderShares = _dataStore.getUint(Keys.positionTraderSharesKey(_positionIndex, _route));
        address[] memory _puppets = _dataStore.getAddressArray(Keys.positionPuppetsKey(_positionIndex, _route));

        _scoreData.length = _puppets.length;
        _scoreData.volumes = new uint256[](_scoreData.length + 1);
        _scoreData.profits = new uint256[](_scoreData.length + 1);
        _scoreData.users = new address[](_scoreData.length + 1);

        {
            uint256[] memory _puppetsShares = _dataStore.getUintArray(Keys.positionPuppetsSharesKey(_positionIndex, _route));
            for (uint256 i = 0; i < _scoreData.length; i++) {
                _scoreData.users[i] = _puppets[i];
                uint256 _shares = _puppetsShares[i];
                if (_shares > 0) {
                    uint256 _profit = 0;
                    uint256 _volume = SharesHelper.convertToAssets(_cumulativeVolumeGenerated, _totalSupply, _shares);
                    if (_puppetsProfitInUSD > 0) {
                        _profit = SharesHelper.convertToAssets(_puppetsProfitInUSD, _totalSupply - _traderShares, _shares);
                    }

                    (_volume, _profit) = _applyReferralBoost(_dataStore, _volume, _profit, _puppets[i]);

                    _scoreData.volumes[i] = _volume;
                    _scoreData.profits[i] = _profit;
                }
            }
        }

        _scoreData.users[_scoreData.length] = CommonHelper.trader(_dataStore, _route);

        {
            uint256 _volume = SharesHelper.convertToAssets(
                _cumulativeVolumeGenerated,
                _totalSupply,
                _traderShares
            );

            uint256 _profit = 0;
            int256 _traderPnL = _dataStore.getInt(Keys.traderPnLKey(_positionIndex, _route));
            if (_traderPnL < 0) {
                address _collateralToken = CommonHelper.collateralToken(_dataStore, _route);
                IBaseOrchestrator _orchestrator = IBaseOrchestrator(CommonHelper.orchestrator(_dataStore));
                _profit = _orchestrator.getPrice(_collateralToken)
                    * ((_traderPnL * -1).toUint256()) / CommonHelper.collateralTokenDecimals(_dataStore, _collateralToken);
            }

            (_volume, _profit) = _applyReferralBoost(_dataStore, _volume, _profit, _scoreData.users[_scoreData.length]);

            _scoreData.volumes[_scoreData.length] = _volume;
            _scoreData.profits[_scoreData.length] = _profit;
        }
    }

    function _applyReferralBoost(
        IDataStore _dataStore,
        uint256 _volume,
        uint256 _profit,
        address _user
    ) internal returns (uint256, uint256) {
        IReferralManager _referralManager = IReferralManager(_dataStore.getAddress(Keys.REFERRAL_MANAGER));
        bytes32 _referralCode = _referralManager.userCode(_user);
        if (_referralCode != bytes32(0)) {
            uint256 _referrerProfit = 0;
            uint256 _boost = _referralManager.codeBoost(_referralCode);
            uint256 _basisPointsDivisor = CommonHelper.basisPointsDivisor();
            _volume = _volume * _boost / _basisPointsDivisor;
            if (_profit > 0) {
                _profit = _profit * _boost / _basisPointsDivisor;
                _referrerProfit = _profit * _referralManager.referrerShare() / _basisPointsDivisor;
            }

            uint256 _referrerVolume = _volume * _referralManager.referrerShare() / _basisPointsDivisor;
            IScoreGauge(CommonHelper.scoreGauge(_dataStore)).updateReferrerScore(
                _referrerVolume,
                _referrerProfit,
                _referralManager.codeOwner(_referralCode)
            );
        }

        return (_volume, _profit);
    }

    // ============================================================================================
    // Errors
    // ============================================================================================

    error ZeroAddress();
    error ZeroAmount();
    error RouteTypeNotRegistered();
    error RouteAlreadyRegistered();
    error RouteNotRegistered();
    error RouteWaitingForCallback();
    error NotCollateralToken();
    error InvalidAllowancePercentage();
    error InvalidSubscriptionExpiry();
    error CannotUnsubscribeYet();
    error InvalidPuppetsArray();
    error PuppetsArrayExceedsMaxPuppets();
    error PuppetSubscriptionExpired();
    error InvalidExecutionFee();
}