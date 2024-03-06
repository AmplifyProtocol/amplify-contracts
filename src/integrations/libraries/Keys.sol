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
// ======================== CommonHelper ========================
// ==============================================================
// Amplify Protocol: https://github.com/AmplifyProtocol

// ==============================================================

/// @title Keys
/// @author johnnyonline
/// @notice Keys for values in the DataStore
library Keys {

    // DataStore.uintValues

    /// @dev key for management fee (DataStore.uintValues)
    bytes32 public constant MANAGEMENT_FEE = keccak256(abi.encode("MANAGEMENT_FEE"));
    /// @dev key for withdrawal fee (DataStore.uintValues)
    bytes32 public constant WITHDRAWAL_FEE = keccak256(abi.encode("WITHDRAWAL_FEE"));
    /// @dev key for performance fee (DataStore.uintValues)
    bytes32 public constant PERFORMANCE_FEE = keccak256(abi.encode("PERFORMANCE_FEE"));
    /// @dev key for the execution fee balance held by the Orchestrator (DataStore.uintValues)
    bytes32 public constant EXECUTION_FEE_BALANCE = keccak256(abi.encode("EXECUTION_FEE_BALANCE"));
    /// @dev key for a global reentrancy guard
    bytes32 public constant REENTRANCY_GUARD_STATUS = keccak256(abi.encode("REENTRANCY_GUARD_STATUS"));
    /// @dev key for a global minimum execution fee
    bytes32 public constant MIN_EXECUTION_FEE = keccak256(abi.encode("MIN_EXECUTION_FEE"));
    /// @dev key for a global minimum Puppet Keeper execution fee
    bytes32 public constant PUPPET_KEEPER_MIN_EXECUTION_FEE = keccak256(abi.encode("PUPPET_KEEPER_MIN_EXECUTION_FEE"));
    /// @dev key for a global maximum number of puppets
    bytes32 public constant MAX_PUPPETS = keccak256(abi.encode("MAX_PUPPETS"));

    // DataStore.addressValues

    /// @dev key for sending received fees
    bytes32 public constant PLATFORM_FEES_RECIPIENT = keccak256(abi.encode("PLATFORM_FEES_RECIPIENT"));
    /// @dev key for subscribing to multiple Routes
    bytes32 public constant MULTI_SUBSCRIBER = keccak256(abi.encode("MULTI_SUBSCRIBER"));
    /// @dev key for the address of the WNT token
    bytes32 public constant WNT = keccak256(abi.encode("WNT"));
    /// @dev key for the address of the keeper
    bytes32 public constant KEEPER = keccak256(abi.encode("KEEPER"));
    /// @dev key for the address of the Score Gauge
    bytes32 public constant SCORE_GAUGE = keccak256(abi.encode("SCORE_GAUGE"));
    /// @dev key for the address of the Route Factory
    bytes32 public constant ROUTE_FACTORY = keccak256(abi.encode("ROUTE_FACTORY"));
    /// @dev key for the address of the Route Setter
    bytes32 public constant ROUTE_SETTER = keccak256(abi.encode("ROUTE_SETTER"));
    /// @dev key for the address of the Orchestrator
    bytes32 public constant ORCHESTRATOR = keccak256(abi.encode("ORCHESTRATOR"));
    /// @dev key for the address of the Referral Manager
    bytes32 public constant REFERRAL_MANAGER = keccak256(abi.encode("REFERRAL_MANAGER"));

    // DataStore.boolValues

    /// @dev key for pause status
    bytes32 public constant PAUSED = keccak256(abi.encode("PAUSED"));

    // DataStore.bytes32Values

    /// @dev key for the referral code
    bytes32 public constant REFERRAL_CODE = keccak256(abi.encode("REFERRAL_CODE"));

    // DataStore.addressArrayValues

    /// @dev key for the array of routes
    bytes32 public constant ROUTES = keccak256(abi.encode("ROUTES"));

    // -------------------------------------------------------------------------------------------

    // global

    function routeTypeKey(address _collateralToken, address _indexToken, bool _isLong, bytes memory _data) external pure returns (bytes32) {
        return keccak256(abi.encode(_collateralToken, _indexToken, _isLong, _data));
    }

    function routeTypeCollateralTokenKey(bytes32 _routeTypeKey) external pure returns (bytes32) {
        return keccak256(abi.encode("COLLATERAL_TOKEN", _routeTypeKey));
    }

    function routeTypeIndexTokenKey(bytes32 _routeTypeKey) external pure returns (bytes32) {
        return keccak256(abi.encode("INDEX_TOKEN", _routeTypeKey));
    }

    function routeTypeIsLongKey(bytes32 _routeTypeKey) external pure returns (bytes32) {
        return keccak256(abi.encode("IS_LONG", _routeTypeKey));
    }

    function routeTypeDataKey(bytes32 _routeTypeKey) external pure returns (bytes32) {
        return keccak256(abi.encode("DATA", _routeTypeKey));
    }

    function platformAccountKey(address _token) external pure returns (bytes32) {
        return keccak256(abi.encode("PLATFORM_ACCOUNT", _token));
    }

    function isRouteTypeRegisteredKey(bytes32 _routeTypeKey) external pure returns (bytes32) {
        return keccak256(abi.encode("IS_ROUTE_TYPE_REGISTERED", _routeTypeKey));
    }

    function isCollateralTokenKey(address _token) external pure returns (bytes32) {
        return keccak256(abi.encode("IS_COLLATERAL_TOKEN", _token));
    }

    function collateralTokenDecimalsKey(address _collateralToken) external pure returns (bytes32) {
        return keccak256(abi.encode("COLLATERAL_TOKEN_DECIMALS", _collateralToken));
    }

    // route

    function routeAddressKey(bytes32 _routeKey) external pure returns (bytes32) {
        return keccak256(abi.encode("ROUTE_ADDRESS", _routeKey));
    }

    function routeCollateralTokenKey(address _route) external pure returns (bytes32) {
        return keccak256(abi.encode("ROUTE_COLLATERAL_TOKEN", _route));
    }

    function routeIndexTokenKey(address _route) external pure returns (bytes32) {
        return keccak256(abi.encode("ROUTE_INDEX_TOKEN", _route));
    }

    function routeIsLongKey(address _route) external pure returns (bytes32) {
        return keccak256(abi.encode("ROUTE_IS_LONG", _route));
    }

    function routeTraderKey(address _route) external pure returns (bytes32) {
        return keccak256(abi.encode("ROUTE_TRADER", _route));
    }

    function routeDataKey(address _route) external pure returns (bytes32) {
        return keccak256(abi.encode("ROUTE_DATA", _route));
    }

    function routeRouteTypeKey(address _route) external pure returns (bytes32) {
        return keccak256(abi.encode("ROUTE_ROUTE_TYPE", _route));
    }

    function targetLeverageKey(address _route) external pure returns (bytes32) {
        return keccak256(abi.encode("TARGET_LEVERAGE", _route));
    }

    function isKeeperRequestsKey(address _route, bytes32 _requestKey) external pure returns (bytes32) {
        return keccak256(abi.encode("KEEPER_REQUESTS", _route, _requestKey));
    }

    function isRouteRegisteredKey(address _route) external pure returns (bytes32) {
        return keccak256(abi.encode("IS_ROUTE_REGISTERED", _route));
    }

    function isWaitingForKeeperAdjustmentKey(address _route) external pure returns (bytes32) {
        return keccak256(abi.encode("IS_WAITING_FOR_KEEPER_ADJUSTMENT", _route));
    }

    function isWaitingForCallbackKey(address _route) external pure returns (bytes32) {
        return keccak256(abi.encode("IS_WAITING_CALLBACK", _route));
    }

    function isKeeperAdjustmentEnabledKey(address _route) external pure returns (bytes32) {
        return keccak256(abi.encode("IS_KEEPER_ADJUSTMENT_ENABLED", _route));
    }

    function isPositionOpenKey(address _route) external pure returns (bytes32) {
        return keccak256(abi.encode("IS_POSITION_OPEN", _route));
    }

    // route position

    function positionIndexKey(address _route) external pure returns (bytes32) {
        return keccak256(abi.encode("POSITION_INDEX", _route));
    }

    function positionPuppetsKey(uint256 _positionIndex, address _route) external pure returns (bytes32) {
        return keccak256(abi.encode("POSITION_PUPPETS", _positionIndex, _route));
    }

    function positionTraderSharesKey(uint256 _positionIndex, address _route) external pure returns (bytes32) {
        return keccak256(abi.encode("POSITION_TRADER_SHARES", _positionIndex, _route));
    }

    function positionPuppetsSharesKey(uint256 _positionIndex, address _route) external pure returns (bytes32) {
        return keccak256(abi.encode("POSITION_PUPPETS_SHARES", _positionIndex, _route));
    }

    function positionLastTraderAmountInKey(uint256 _positionIndex, address _route) external pure returns (bytes32) {
        return keccak256(abi.encode("POSITION_LAST_TRADER_AMOUNT_IN", _positionIndex, _route));
    }

    function positionLastPuppetsAmountsInKey(uint256 _positionIndex, address _route) external pure returns (bytes32) {
        return keccak256(abi.encode("POSITION_LAST_PUPPETS_AMOUNTS_IN", _positionIndex, _route));
    }

    function positionTotalSupplyKey(uint256 _positionIndex, address _route) external pure returns (bytes32) {
        return keccak256(abi.encode("POSITION_TOTAL_SUPPLY", _positionIndex, _route));
    }

    function positionTotalAssetsKey(uint256 _positionIndex, address _route) external pure returns (bytes32) {
        return keccak256(abi.encode("POSITION_TOTAL_ASSETS", _positionIndex, _route));
    }

    function cumulativeVolumeGeneratedKey(uint256 _positionIndex, address _route) external pure returns (bytes32) {
        return keccak256(abi.encode("CUMULATIVE_VOLUME_GENERATED", _positionIndex, _route));
    }

    function puppetsPnLKey(uint256 _positionIndex, address _route) external pure returns (bytes32) {
        return keccak256(abi.encode("PUPPETS_PNL", _positionIndex, _route));
    }

    function traderPnLKey(uint256 _positionIndex, address _route) external pure returns (bytes32) {
        return keccak256(abi.encode("TRADER_PNL", _positionIndex, _route));
    }

    function performanceFeePaidKey(uint256 _positionIndex, address _route) external pure returns (bytes32) {
        return keccak256(abi.encode("PERFORMANCE_FEE_PAID", _positionIndex, _route));
    }

    // route request

    function addCollateralRequestPuppetsSharesKey(uint256 _positionIndex, address _route) external pure returns (bytes32) {
        return keccak256(abi.encode("ADD_COLLATERAL_REQUEST_PUPPETS_SHARES", _positionIndex, _route));
    }

    function addCollateralRequestPuppetsAmountsKey(uint256 _positionIndex, address _route) external pure returns (bytes32) {
        return keccak256(abi.encode("ADD_COLLATERAL_REQUEST_PUPPETS_AMOUNTS", _positionIndex, _route));
    }

    function addCollateralRequestTraderAmountInKey(uint256 _positionIndex, address _route) external pure returns (bytes32) {
        return keccak256(abi.encode("ADD_COLLATERAL_REQUEST_TRADER_AMOUNT_IN", _positionIndex, _route));
    }

    function addCollateralRequestPuppetsAmountInKey(uint256 _positionIndex, address _route) external pure returns (bytes32) {
        return keccak256(abi.encode("ADD_COLLATERAL_REQUEST_PUPPETS_AMOUNT_IN", _positionIndex, _route));
    }

    function addCollateralRequestTraderSharesKey(uint256 _positionIndex, address _route) external pure returns (bytes32) {
        return keccak256(abi.encode("ADD_COLLATERAL_REQUEST_TRADER_SHARES", _positionIndex, _route));
    }

    function addCollateralRequestTotalSupplyKey(uint256 _positionIndex, address _route) external pure returns (bytes32) {
        return keccak256(abi.encode("ADD_COLLATERAL_REQUEST_TOTAL_SUPPLY", _positionIndex, _route));
    }

    function pendingSizeDeltaKey(uint256 _positionIndex, address _route) external pure returns (bytes32) {
        return keccak256(abi.encode("PENDING_SIZE_DELTA", _positionIndex, _route));
    }

    function pendingRequestKey(uint256 _positionIndex, address _route) external pure returns (bytes32) {
        return keccak256(abi.encode("PENDING_REQUEST_KEY", _positionIndex, _route));
    }

    // puppet

    function puppetAllowancesKey(address _puppet) external pure returns (bytes32) {
        return keccak256(abi.encode("PUPPET_ALLOWANCES", _puppet));
    }

    function puppetSubscriptionExpiryKey(address _puppet, address _route) external pure returns (bytes32) {
        return keccak256(abi.encode("PUPPET_SUBSCRIPTION_EXPIRY", _puppet, _route));
    }

    function puppetSubscribedAtKey(address _puppet, address _route) external pure returns (bytes32) {
        return keccak256(abi.encode("PUPPET_SUBSCRIBED_AT", _puppet, _route));
    }

    function puppetDepositAccountKey(address _puppet, address _token) external pure returns (bytes32) {
        return keccak256(abi.encode("PUPPET_DEPOSIT_ACCOUNT", _puppet, _token));
    }

    function puppetThrottleLimitKey(address _puppet, bytes32 _routeTypeKey) external pure returns (bytes32) {
        return keccak256(abi.encode("PUPPET_THROTTLE_LIMIT", _puppet, _routeTypeKey));
    }

    function puppetLastPositionOpenedTimestampKey(address _puppet, bytes32 _routeTypeKey) external pure returns (bytes32) {
        return keccak256(abi.encode("PUPPET_LAST_POSITION_OPENED_TIMESTAMP", _puppet, _routeTypeKey));
    }
}