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
// ====================== IBaseOrchestrator =====================
// ==============================================================
// Amplify Protocol: https://github.com/AmplifyProtocol

// ==============================================================

import {IBaseRoute} from "./IBaseRoute.sol";

interface IBaseOrchestrator {

    // ============================================================================================
    // View Functions
    // ============================================================================================

    /// @notice The ```positionKey``` function returns the position key of a Route
    /// @param _route The address of the Route
    /// @return _positionKey The position key
    function positionKey(address _route) external view returns (bytes32 _positionKey);

    /// @notice The ```positionAmounts``` function returns the position size and collateral of a Route
    /// @param _route The address of the Route
    /// @return _size The position size
    /// @return _collateral The position collateral
    function positionAmounts(address _route) external view returns (uint256 _size, uint256 _collateral);

    /// @notice The ```getPrice``` function returns the price for a given Token. USD denominated with 30 decimals
    /// @param _token The address of the Token
    /// @return _price The price
    function getPrice(address _token) external view returns (uint256 _price);

    /// @notice The ```isWaitingForCallback``` function returns a boolean indicating if a Route is waiting for a callback
    /// @param _routeKey The Route key
    /// @return _isWaitingForCallback The boolean indicating if a Route is waiting for a callback
    function isWaitingForCallback(bytes32 _routeKey) external view returns (bool _isWaitingForCallback);

    // ============================================================================================
    // Mutated Functions
    // ============================================================================================

    // Trader

    /// @notice The ```registerRoute``` function is called by a Trader to register a new Route Account
    /// @param _routeTypeKey The route type key
    /// @return _routeKey The Route key
    function registerRoute(bytes32 _routeTypeKey) external returns (bytes32 _routeKey);

    /// @notice The ```requestPosition``` function creates a new position request
    /// @param _adjustPositionParams The adjusment params for the position
    /// @param _swapParams The swap data of the Trader, enables the Trader to add collateral with a non-collateral token
    /// @param _executionFees The execution fees
    /// @param _routeTypeKey The RouteType key
    /// @param _isIncrease The boolean indicating if the request is an increase or decrease request
    /// @return _requestKey The request key
    function requestPosition(IBaseRoute.AdjustPositionParams memory _adjustPositionParams, IBaseRoute.SwapParams memory _swapParams, IBaseRoute.ExecutionFees memory _executionFees, bytes32 _routeTypeKey, bool _isIncrease) external payable returns (bytes32 _requestKey);

    /// @notice The ```cancelRequest``` function is used to cancel a non-market request
    /// @param _routeTypeKey The RouteType key
    /// @param _requestKey The request key of the request
    function cancelRequest(bytes32 _routeTypeKey, bytes32 _requestKey) external payable;

    /// @notice The ```registerRouteAndRequestPosition``` function is called by a Trader to register a new Route Account and create an Increase Position Request
    /// @param _adjustPositionParams The adjusment params for the position
    /// @param _swapParams The swap data of the Trader, enables the Trader to add collateral with a non-collateral token
    /// @param _executionFees The execution fees
    /// @param _routeTypeKey The route type key
    /// @return _routeKey The Route key
    /// @return _requestKey The request key
    function registerRouteAndRequestPosition(IBaseRoute.AdjustPositionParams memory _adjustPositionParams, IBaseRoute.SwapParams memory _swapParams, IBaseRoute.ExecutionFees memory _executionFees, bytes32 _routeTypeKey) external payable returns (bytes32 _routeKey, bytes32 _requestKey);

    // Puppet

    /// @notice The ```subscribe``` function is called by a Puppet to update his subscription to a Route. Can also be called by the MultiSubscriber which is allowed to specify a non `msg.sender` Puppet
    /// @param _allowance The allowance percentage. 0 to unsubscribe
    /// @param _expiry The subscription expiry timestamp
    /// @param _puppet The subscribing Puppet
    /// @param _trader The address of the Trader
    /// @param _routeTypeKey The RouteType key
    function subscribe(uint256 _allowance, uint256 _expiry, address _puppet, address _trader, bytes32 _routeTypeKey) external;

    /// @notice The ```batchSubscribe``` function is called by a Puppet to update his subscription to a list of Routes. Can also be called by the MultiSubscriber which is allowed to specify a non `msg.sender` Puppet
    /// @param _puppet The subscribing Puppet. Will be `msg.sender` if not called by the MultiSubscriber
    /// @param _allowances The allowance percentage array. 0 to unsubscribe
    /// @param _expiries The subscription expiry timestamp array
    /// @param _traders The address array of Traders
    /// @param _routeTypeKeys The RouteType key array
    function batchSubscribe(address _puppet, uint256[] memory _allowances, uint256[] memory _expiries, address[] memory _traders, bytes32[] memory _routeTypeKeys) external;

    /// @notice The ```deposit``` function is called by a Puppet to deposit funds into his deposit account
    /// @param _amount The amount to deposit
    /// @param _token The address of the Token
    /// @param _receiver The address of the recepient
    function deposit(uint256 _amount, address _token, address _receiver) external payable;

    /// @notice The ```depositAndBatchSubscribe``` function is called by a Puppet to deposit funds into his deposit account and update his subscription to a list of Route Accounts
    /// @param _amount The amount to deposit
    /// @param _token The address of the Token
    /// @param _puppet The subscribing Puppet. Will be `msg.sender` if not called by the MultiSubscriber
    /// @param _allowances The allowance percentage array. 0 to unsubscribe
    /// @param _expiries The subscription expiry timestamp array
    /// @param _traders The address array of Traders
    /// @param _routeTypeKeys The RouteType key array
    function depositAndBatchSubscribe(uint256 _amount, address _token, address _puppet, uint256[] memory _allowances, uint256[] memory _expiries, address[] memory _traders, bytes32[] memory _routeTypeKeys) external payable;

    /// @notice The ```withdraw``` function is called by a Puppet to withdraw funds from his deposit account
    /// @param _amount The amount to withdraw
    /// @param _token The address of the Token
    /// @param _receiver The address of the receiver of withdrawn funds
    /// @param _isETH Whether to withdraw ETH or not. Available only for WETH deposits
    /// @return _amountOut The amount withdrawn, after fees
    function withdraw(uint256 _amount, address _token, address _receiver, bool _isETH) external returns (uint256 _amountOut);

    /// @notice The ```setThrottleLimit``` function is called by a Puppet to set his throttle limit for a given RouteType
    /// @param _throttleLimit The throttle limit
    /// @param _routeType The RouteType key
    function setThrottleLimit(uint256 _throttleLimit, bytes32 _routeType) external;

    // Route

    /// @notice The ```debitAccounts``` function is called by a Route Account to debit multiple Puppets accounts
    /// @param _amounts The uint256 array of amounts to debit
    /// @param _puppets The address array of the Puppets to debit
    /// @param _token The address of the Token
    function debitAccounts(uint256[] memory _amounts, address[] memory _puppets, address _token) external;

    /// @notice The ```creditAccounts``` function is called by a Route Account to credit multiple Puppets accounts
    /// @param _amounts The uint256 array of amounts to credit
    /// @param _puppets The address array of the Puppets to credit
    /// @param _token The address of the Token
    function creditAccounts(uint256[] memory _amounts, address[] memory _puppets, address _token) external;

    /// @notice The ```updateLastPositionOpenedTimestamp``` function is called by a Route to update the last position opened timestamp of a Puppet
    /// @param _puppets The address array of the Puppets
    function updateLastPositionOpenedTimestamp(address[] memory _puppets) external;

    /// @notice The ```transferTokens``` function is called by a Route to send funds to a _receiver
    /// @param _amount The amount to send
    /// @param _token The address of the Token
    function transferTokens(uint256 _amount, address _token) external;

    /// @notice The ```emitExecutionCallback``` function is called by a Route Account to emit an event on a callback
    /// @param performanceFeePaid The performance fee paid to Trader
    /// @param _requestKey The request key
    /// @param _isExecuted The boolean indicating if the request is executed
    /// @param _isIncrease The boolean indicating if the request is an increase or decrease request
    function emitExecutionCallback(uint256 performanceFeePaid, bytes32 _requestKey, bool _isExecuted, bool _isIncrease) external;

    /// @notice The ```emitSharesIncrease``` function is called by a Route Account to emit an event on a successful add collateral request
    /// @param _puppetsShares The array of Puppets shares, corresponding to the Route Account's subscribed Puppets, as stored in the Route Account Position struct
    /// @param _traderShares The Trader's shares, as stored in the Route Account Position struct
    /// @param _totalSupply The total supply of the Route Account's shares
    /// @param _requestKey The request key
    function emitSharesIncrease(uint256[] memory _puppetsShares, uint256 _traderShares, uint256 _totalSupply, bytes32 _requestKey) external;

    // Authority

    // called by keeper

    /// @notice The ```decreaseSize``` function is called by a Keeper to adjust the Route Account leverage to match the target leverage
    /// @param _adjustPositionParams The adjusment params for the position
    /// @param _executionFee The total execution fee, paid by the Keeper in ETH
    /// @param _routeKey The Route key
    /// @return _requestKey The request key
    function decreaseSize(IBaseRoute.AdjustPositionParams memory _adjustPositionParams, uint256 _executionFee, bytes32 _routeKey) external returns (bytes32 _requestKey);

    // called by owner

    /// @notice The ```updateDexAddresses``` function is called by the Authority to update the underlying DEX's addresses
    /// @param _data The bytes data of the new DEX addresses
    function updateDexAddresses(bytes memory _data) external;

    /// @notice The ```initialize``` function is called by the Authority to initialize the contract
    /// @notice Function is callable only once and execution is paused until then
    /// @param _minExecutionFee The minimum execution fee
    /// @param _wnt The address of the WNT
    /// @param _platformFeeRecipient The address of the platform fees recipient
    /// @param _routeFactory The address of the RouteFactory
    /// @param _gauge The address of the Score Gauge
    /// @param _data The bytes of any additional data
    function initialize(uint256 _minExecutionFee, address _wnt, address _platformFeeRecipient, address _routeFactory, address _gauge, bytes memory _data) external;

    /// @notice The ```depositExecutionFees``` function is called by anyone to deposit execution fees which are used by the Keeper to adjust the position in case it doesn't meet the target leverage
    function depositExecutionFees() external payable;

    /// @notice The ```withdrawExecutionFees``` function is called by the Authority to withdraw Keeper execution fees
    /// @param _amount The amount to withdraw
    /// @param _receiver The address of the receiver
    function withdrawExecutionFees(uint256 _amount, address _receiver) external;

    /// @notice The ```withdrawPlatformFees``` function is called by anyone to withdraw platform fees
    /// @param _token The address of the Asset
    function withdrawPlatformFees(address _token) external;

    /// @notice The ```setRouteType``` function is called by the Authority to set a new RouteType
    /// @notice system doesn't support tokens that apply a fee/burn/rebase on transfer 
    /// @param _collateral The address of the Collateral Token
    /// @param _index The address of the Index Token
    /// @param _isLong The boolean value of the position
    /// @param _data Any additional data
    function setRouteType(address _collateral, address _index, bool _isLong, bytes memory _data) external;

    /// @notice The ```updateRouteFactory``` function is called by the Authority to set the RouteFactory address
    /// @param _routeFactory The address of the new RouteFactory
    function updateRouteFactory(address _routeFactory) external;

    /// @notice The ```updateMultiSubscriber``` function is called by the Authority to set the MultiSubscriber address
    /// @param _multiSubscriber The address of the new MultiSubscriber
    function updateMultiSubscriber(address _multiSubscriber) external;

    /// @notice The ```updateScoreGauge``` function is called by the Authority to set the Score Gauge address
    /// @param _gauge The address of the new Score Gauge
    function updateScoreGauge(address _gauge) external;

    /// @notice The ```updateReferralCode``` function is called by the Authority to set the referral code
    /// @param _refCode The new referral code
    function updateReferralCode(bytes32 _refCode) external;

    /// @notice The ```updatePlatformFeesRecipient``` function is called by the Authority to set the platform fees recipient
    /// @param _recipient The new platform fees recipient
    function updatePlatformFeesRecipient(address _recipient) external;

    /// @notice The ```setPause``` function is called by the Authority to update the pause switch
    /// @param _pause The new pause state
    function updatePauseStatus(bool _pause) external;

    /// @notice The ```updateMinExecutionFee``` function is called by the Authority to set the minimum execution fee
    /// @param _minExecutionFee The new minimum execution fee
    function updateMinExecutionFee(uint256 _minExecutionFee) external;

    /// @notice The ```updatePuppetKeeperMinExecutionFee``` function is called by the Authority to set the minimum execution fee for DecreaseSize Keeper
    /// @param _puppetKeeperMinExecutionFee The new minimum execution fee
    function updatePuppetKeeperMinExecutionFee(uint256 _puppetKeeperMinExecutionFee) external;

    /// @notice The ```updateMaxPuppets``` function is called by the Authority to set the maximum number of Puppets
    /// @param _maxPuppets The new maximum number of Puppets
    function updateMaxPuppets(uint256 _maxPuppets) external;

    /// @notice The ```updateFees``` function is called by the Authority to update the platform fees
    /// @param _managmentFee The new management fee
    /// @param _withdrawalFee The new withdrawal fee
    /// @param _performanceFee The new performance fee
    function updateFees(uint256 _managmentFee, uint256 _withdrawalFee, uint256 _performanceFee) external;

    /// @notice The ```forceCallback``` function is called by an emergency Authority address to force a callback, in case it failed
    /// @param _route The address of the Route
    /// @param _requestKey The request key
    /// @param _isExecuted The boolean indicating if the request was executed
    /// @param _isIncrease The boolean indicating if the request was an increase or decrease request
    function forceCallback(address _route, bytes32 _requestKey, bool _isExecuted, bool _isIncrease) external;

    /// @notice The ```rescueToken``` function is called by the Authority to rescue tokens from a Route
    /// @dev Route should never hold any funds, but this function is here just in case
    /// @param _amount The amount to rescue
    /// @param _token The address of the Token
    /// @param _receiver The address of the receiver
    /// @param _route The address of the Route
    function rescueToken(uint256 _amount, address _token, address _receiver, address _route) external;

    // ============================================================================================
    // Events
    // ============================================================================================

    event RegisterRoute(address indexed trader, address indexed route);
    event RequestPosition(address[] puppets, address indexed trader, address indexed route, bool isIncrease, bytes32 requestKey, bytes32 routeTypeKey, bytes32 positionKey);
    event CancelRequest(address indexed route, bytes32 requestKey);

    event Subscribe(uint256 allowance, uint256 expiry, address indexed trader, address indexed puppet, address indexed route, bytes32 routeTypeKey);
    event Deposit(uint256 amount, address asset, address caller, address indexed receiver);
    event Withdraw(uint256 amountOut, address asset, address indexed receiver, address indexed puppet);
    event SetThrottleLimit(address indexed puppet, bytes32 routeType, uint256 throttleLimit);

    event UpdateOpenTimestamp(address[] puppets, bytes32 routeType);
    event TransferTokens(uint256 amount, address asset, address indexed caller);
    event ExecutePosition(uint256 performanceFeePaid, address indexed route, bytes32 requestKey, bool isExecuted, bool isIncrease);
    event SharesIncrease(uint256[] puppetsShares, uint256 traderShares, uint256 totalSupply, address route, bytes32 requestKey);
    event DecreaseSize(address indexed route, bytes32 requestKey, bytes32 routeKey, bytes32 positionKey);

    event Initialize(address platformFeeRecipient, address routeFactory, address gauge);
    event DepositExecutionFees(uint256 amount);
    event WithdrawExecutionFees(uint256 amount, address receiver);
    event WithdrawPlatformFees(uint256 amount, address asset);

    event SetRouteType(bytes32 routeTypeKey, address collateral, address index, bool isLong, bytes data);
    event UpdateRouteFactory(address routeFactory);
    event UpdateMultiSubscriber(address multiSubscriber);
    event UpdateScoreGauge(address scoreGauge);
    event UpdateReferralCode(bytes32 referralCode);
    event UpdateFeesRecipient(address recipient);
    event UpdatePauseStatus(bool paused);
    event UpdateMinExecutionFee(uint256 minExecutionFee);
    event UpdatePuppetKeeperMinExecutionFee(uint256 puppetKeeperMinExecutionFee);
    event UpdateMaxPuppets(uint256 maxPuppets);
    event UpdateFees(uint256 managmentFee, uint256 withdrawalFee, uint256 performanceFee);
    event ForceCallback(address route, bytes32 requestKey, bool isExecuted, bool isIncrease);
    event RescueToken(uint256 amount, address token, address indexed receiver, address indexed route);

    event DebitPuppet(uint256 amount, address asset, address indexed puppet, address indexed caller);
    event CreditPlatform(uint256 amount, address asset, address puppet, address caller, bool isWithdraw);
    event CreditPuppet(uint256 amount, address asset, address indexed puppet, address indexed caller);

    // ============================================================================================
    // Errors
    // ============================================================================================

    error MismatchedInputArrays();
    error RouteNotRegistered();
    error InvalidAmount();
    error InvalidAsset();
    error ZeroAddress();
    error ZeroBytes32();
    error ZeroAmount();
    error FunctionCallPastDeadline();
    error NotWhitelisted();
    error FeeExceedsMax();
    error AlreadyInitialized();
    error InvalidExecutionFee();
    error InvalidPath();
    error Paused();
    error NotRoute();
}