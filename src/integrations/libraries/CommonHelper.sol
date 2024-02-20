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
// ======================== CommonHelper ========================
// ==============================================================
// Amplify Protocol: https://github.com/AmplifyProtocol

// ==============================================================

import {Keys} from "./Keys.sol";

import {IDataStore} from "../utilities/interfaces/IDataStore.sol";

/// @title CommonHelper
/// @author johnnyonline
/// @notice Common helper functions
library CommonHelper {

    uint256 private constant _PRECISION = 1e18;
    uint256 private constant _BASIS_POINTS_DIVISOR = 10000;

    // ============================================================================================
    // View functions
    // ============================================================================================

    // global

    function precision() external pure returns (uint256) {
        return _PRECISION;
    }

    function basisPointsDivisor() external pure returns (uint256) {
        return _BASIS_POINTS_DIVISOR;
    }

    function withdrawalFeePercentage(IDataStore _dataStore) public view returns (uint256) {
        return _dataStore.getUint(Keys.WITHDRAWAL_FEE);
    }

    function managementFeePercentage(IDataStore _dataStore) public view returns (uint256) { 
        return _dataStore.getUint(Keys.MANAGEMENT_FEE);
    }

    function maxPuppets(IDataStore _dataStore) external view returns (uint256) {
        return _dataStore.getUint(Keys.MAX_PUPPETS);
    }

    function minExecutionFee(IDataStore _dataStore) external view returns (uint256) {
        return _dataStore.getUint(Keys.MIN_EXECUTION_FEE);
    }

    function minPuppetExecutionFee(IDataStore _dataStore) external view returns (uint256) {
        return _dataStore.getUint(Keys.PUPPET_KEEPER_MIN_EXECUTION_FEE);
    }

    function collateralTokenDecimals(IDataStore _dataStore, address _token) external view returns (uint256) {
        return _dataStore.getUint(Keys.collateralTokenDecimalsKey(_token));
    }

    function platformFeeRecipient(IDataStore _dataStore) external view returns (address) {
        return _dataStore.getAddress(Keys.PLATFORM_FEES_RECIPIENT);
    }

    function wnt(IDataStore _dataStore) external view returns (address) {
        return _dataStore.getAddress(Keys.WNT);
    }

    function isPaused(IDataStore _dataStore) external view returns (bool) {
        return _dataStore.getBool(Keys.PAUSED);
    }

    function isCollateralToken(IDataStore _dataStore, address _token) external view returns (bool) {
        return _dataStore.getBool(Keys.isCollateralTokenKey(_token));
    }

    function isRouteRegistered(IDataStore _dataStore, address _route) external view returns (bool) {
        return _dataStore.getBool(Keys.isRouteRegisteredKey(_route));
    }

    function isRouteRegistered(IDataStore _dataStore, bytes32 _routeKey) external view returns (bool) {
        return _dataStore.getBool(Keys.isRouteRegisteredKey(routeAddress(_dataStore, _routeKey)));
    }

    function referralCode(IDataStore _dataStore) external view returns (bytes32) {
        return _dataStore.getBytes32(Keys.REFERRAL_CODE);
    }

    function routes(IDataStore _dataStore) external view returns (address[] memory) {
        return _dataStore.getAddressArray(Keys.ROUTES);
    }

    // keys

    function routeKey(IDataStore _dataStore, address _trader, bytes32 _routeTypeKey) public view returns (bytes32) {
        address _collateralToken = _dataStore.getAddress(Keys.routeTypeCollateralTokenKey(_routeTypeKey));
        address _indexToken = _dataStore.getAddress(Keys.routeTypeIndexTokenKey(_routeTypeKey));
        bool _isLong = _dataStore.getBool(Keys.routeTypeIsLongKey(_routeTypeKey));
        return keccak256(abi.encode(_trader, _collateralToken, _indexToken, _isLong));
    }

    function routeKey(IDataStore _dataStore, address _route) public view returns (bytes32) {
        return routeKey(_dataStore, trader(_dataStore, _route), routeType(_dataStore, _route));
    }

    // deployed contracts

    function orchestrator(IDataStore _dataStore) external view returns (address) {
        return _dataStore.getAddress(Keys.ORCHESTRATOR);
    }

    function scoreGauge(IDataStore _dataStore) external view returns (address) {
        return _dataStore.getAddress(Keys.SCORE_GAUGE);
    }

    // puppets

    function puppetAccountBalance(IDataStore _dataStore, address _puppet, address _token) public view returns (uint256) {
        return _dataStore.getUint(Keys.puppetDepositAccountKey(_puppet, _token));
    }

    function puppetSubscriptionExpiry(IDataStore _dataStore, address _puppet, address _route) public view returns (uint256) {
        return _dataStore.getUint(Keys.puppetSubscriptionExpiryKey(_puppet, _route)) > block.timestamp
        ? _dataStore.getUint(Keys.puppetSubscriptionExpiryKey(_puppet, _route))
        : 0;
    }

    function puppetAllowancePercentage(IDataStore _dataStore, address _puppet, address _route) external view returns (uint256) {
        if (puppetSubscriptionExpiry(_dataStore, _puppet, _route) > 0) {
            (bool _success, uint256 _allowance) = _dataStore.tryGetAddressToUintFor(Keys.puppetAllowancesKey(_puppet), _route);
            if (_success) return _allowance;
        }
        return 0;
    }

    function canPuppetPayAmount(
        IDataStore _dataStore,
        address _puppet,
        address _collateralToken,
        uint256 _amount,
        bool _isWithdraw
    ) external view returns (bool) {
        uint256 _balance = puppetAccountBalance(_dataStore, _puppet, _collateralToken);
        uint256 _feeAmount = (
            _isWithdraw
            ? (_amount * _dataStore.getUint(Keys.WITHDRAWAL_FEE))
            : (_amount * _dataStore.getUint(Keys.MANAGEMENT_FEE))
        ) / _BASIS_POINTS_DIVISOR;

        return _balance >= (_amount + _feeAmount);
    }

    // Route data

    function trader(IDataStore _dataStore, address _route) public view returns (address) {
        return _dataStore.getAddress(Keys.routeTraderKey(_route));
    }

    function routeType(IDataStore _dataStore, address _route) public view returns (bytes32) {
        return _dataStore.getBytes32(Keys.routeRouteTypeKey(_route));
    }

    function routeAddress(IDataStore _dataStore, bytes32 _routeKey) public view returns (address) {
        return _dataStore.getAddress(Keys.routeAddressKey(_routeKey));
    }

    function routeAddress(
        IDataStore _dataStore,
        address _trader,
        address _collateralToken,
        address _indexToken,
        bool _isLong,
        bytes memory _data
    ) external view returns (address) {
        return routeAddress(_dataStore, routeKey(_dataStore, _trader, Keys.routeTypeKey(_collateralToken, _indexToken, _isLong, _data)));
    }

    function collateralToken(IDataStore _dataStore, address _route) external view returns (address) {
        return _dataStore.getAddress(Keys.routeCollateralTokenKey(_route));
    }

    function indexToken(IDataStore _dataStore, address _route) external view returns (address) {
        return _dataStore.getAddress(Keys.routeIndexTokenKey(_route));
    }

    function isLong(IDataStore _dataStore, address _route) external view returns (bool) {
        return _dataStore.getBool(Keys.routeIsLongKey(_route));
    }

    function isPositionOpen(IDataStore _dataStore, address _route) external view returns (bool) {
        return _dataStore.getBool(Keys.isPositionOpenKey(_route));
    }
}