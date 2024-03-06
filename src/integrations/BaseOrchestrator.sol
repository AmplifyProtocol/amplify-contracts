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
// ====================== BaseOrchestrator ======================
// ==============================================================
// Amplify Protocol: https://github.com/AmplifyProtocol

// ==============================================================

import {Auth, Authority} from "@solmate/auth/Auth.sol";

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {
    CommonHelper,
    Keys,
    OrchestratorHelper,
    IBaseOrchestrator,
    IBaseRoute,
    IDataStore
} from "./libraries/OrchestratorHelper.sol";

import {IWETH} from "../utilities/interfaces/IWETH.sol";

import {GlobalReentrancyGuard} from "./utilities/GlobalReentrancyGuard.sol";

/// @title BaseOrchestrator
/// @author johnnyonline
/// @notice This contract holds all funds and facilitates all end user interactions with the Copy-Trading system
abstract contract BaseOrchestrator is IBaseOrchestrator, Auth, GlobalReentrancyGuard {

    using SafeERC20 for IERC20;
    using Address for address payable;

    uint256 public constant MAX_FEE = 1000; // 10% max fee

    bool private _initialized;

    // ============================================================================================
    // Constructor
    // ============================================================================================

    /// @notice The ```constructor``` function is called on deployment
    /// @param _authority The Authority contract instance
    /// @param _dataStore The dataStore contract address
    constructor(
        Authority _authority,
        IDataStore _dataStore
    ) Auth(address(0), _authority) GlobalReentrancyGuard(_dataStore) {}

    // ============================================================================================
    // Modifiers
    // ============================================================================================

    /// @notice Ensures the caller is a Route
    modifier onlyRoute() {
        if (!CommonHelper.isRouteRegistered(dataStore, msg.sender)) revert NotRoute();
        _;
    }

    /// @notice Ensures the contract is not Paused
    modifier notPaused() {
        if (CommonHelper.isPaused(dataStore)) revert Paused();
        _;
    }

    // ============================================================================================
    // View Functions
    // ============================================================================================

    /// @inheritdoc IBaseOrchestrator
    function positionKey(address _route) virtual public view returns (bytes32);

    /// @inheritdoc IBaseOrchestrator
    function positionAmounts(address _route) virtual external view returns (uint256, uint256);

    /// @inheritdoc IBaseOrchestrator
    function getPrice(address _token) virtual external view returns (uint256);

    /// @inheritdoc IBaseOrchestrator
    function isWaitingForCallback(bytes32 _routeKey) virtual external view returns (bool);

    // ============================================================================================
    // Trader Function
    // ============================================================================================

    /// @inheritdoc IBaseOrchestrator
    function registerRoute(bytes32 _routeTypeKey) public globalNonReentrant notPaused returns (bytes32) {
        (
            address _route,
            bytes32 _routeKey
        ) = OrchestratorHelper.registerRoute(dataStore, msg.sender, _routeTypeKey);

        emit RegisterRoute(msg.sender, _route);

        return _routeKey;
    }

    /// @inheritdoc IBaseOrchestrator
    function requestPosition(
        IBaseRoute.AdjustPositionParams memory _adjustPositionParams,
        IBaseRoute.SwapParams memory _swapParams,
        IBaseRoute.ExecutionFees memory _executionFees,
        bytes32 _routeTypeKey,
        bool _isIncrease
    ) public payable globalNonReentrant notPaused returns (bytes32 _requestKey) {

        IDataStore _dataStore = dataStore;
        OrchestratorHelper.validateExecutionFees(_dataStore, _swapParams, _executionFees);

        address _route = OrchestratorHelper.validateRouteKey(
            _dataStore,
            CommonHelper.routeKey(_dataStore, msg.sender, _routeTypeKey)
        );

        OrchestratorHelper.validatePuppets(_dataStore, _route, _adjustPositionParams.puppets);

        if (_isIncrease && msg.value == _executionFees.dexKeeper + _executionFees.puppetKeeper) {
            IERC20(_swapParams.path[0]).safeTransferFrom(msg.sender, address(this), _swapParams.amount);
        }

        _requestKey = IBaseRoute(_route).requestPosition{ value: msg.value }(
            _adjustPositionParams,
            _swapParams,
            _executionFees,
            _isIncrease
        );

        emit RequestPosition(
            _adjustPositionParams.puppets,
            msg.sender,
            _route,
            _isIncrease,
            _requestKey,
            _routeTypeKey,
            positionKey(_route)
        );
    }

    /// @inheritdoc IBaseOrchestrator
    function cancelRequest(bytes32 _routeTypeKey, bytes32 _requestKey) external payable globalNonReentrant notPaused {

        IDataStore _dataStore = dataStore;
        if (msg.value == 0 || msg.value < CommonHelper.minExecutionFee(_dataStore)) revert InvalidExecutionFee();

        address _route = OrchestratorHelper.validateRouteKey(
            _dataStore,
            CommonHelper.routeKey(_dataStore, msg.sender, _routeTypeKey)
        );

        IBaseRoute(_route).cancelRequest{ value: msg.value }(_requestKey);

        emit CancelRequest(_route, _requestKey);
    }

    /// @inheritdoc IBaseOrchestrator
    function registerRouteAndRequestPosition(
        IBaseRoute.AdjustPositionParams memory _adjustPositionParams,
        IBaseRoute.SwapParams memory _swapParams,
        IBaseRoute.ExecutionFees memory _executionFees,
        bytes32 _routeTypeKey
    ) external payable returns (bytes32 _routeKey, bytes32 _requestKey) {
        _routeKey = registerRoute(_routeTypeKey);

        _requestKey = requestPosition(_adjustPositionParams, _swapParams, _executionFees, _routeTypeKey, true);
    }

    // ============================================================================================
    // Puppet Functions
    // ============================================================================================

    /// @inheritdoc IBaseOrchestrator
    function subscribe(
        uint256 _allowance,
        uint256 _expiry,
        address _puppet,
        address _trader,
        bytes32 _routeTypeKey
    ) public globalNonReentrant notPaused {
        address _route = OrchestratorHelper.updateSubscription(
            dataStore,
            _expiry,
            _allowance,
            msg.sender,
            _trader,
            _puppet,
            _routeTypeKey
        );

        emit Subscribe(_allowance, _expiry, _trader, _puppet, _route, _routeTypeKey);
    }

    /// @inheritdoc IBaseOrchestrator
    function batchSubscribe(
        address _puppet,
        uint256[] memory _allowances,
        uint256[] memory _expiries,
        address[] memory _traders,
        bytes32[] memory _routeTypeKeys
    ) public {
        if (_traders.length != _allowances.length) revert MismatchedInputArrays();
        if (_traders.length != _expiries.length) revert MismatchedInputArrays();
        if (_traders.length != _routeTypeKeys.length) revert MismatchedInputArrays();

        for (uint256 i = 0; i < _traders.length; i++) {
            subscribe(_allowances[i], _expiries[i], _puppet, _traders[i], _routeTypeKeys[i]);
        }
    }

    /// @inheritdoc IBaseOrchestrator
    function deposit(uint256 _amount, address _token, address _receiver) public payable globalNonReentrant notPaused {

        IDataStore _dataStore = dataStore;
        OrchestratorHelper.validatePuppetInput(_dataStore, _amount, _receiver, _token);

        if (msg.value > 0) {
            if (_amount != msg.value) revert InvalidAmount();
            if (_token != CommonHelper.wnt(_dataStore)) revert InvalidAsset();
        }

        _creditAccount(_amount, _token, _receiver);

        if (msg.value > 0) {
            payable(_token).functionCallWithValue(abi.encodeWithSignature("deposit()"), _amount);
        } else {
            IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        }

        emit Deposit(_amount, _token, msg.sender, _receiver);
    }

    /// @inheritdoc IBaseOrchestrator
    function depositAndBatchSubscribe(
        uint256 _amount,
        address _token,
        address _puppet,
        uint256[] memory _allowances,
        uint256[] memory _expiries,
        address[] memory _traders,
        bytes32[] memory _routeTypeKeys
    ) external payable {
        deposit(_amount, _token, _puppet);

        batchSubscribe(_puppet, _allowances, _expiries, _traders, _routeTypeKeys);
    }

    /// @inheritdoc IBaseOrchestrator
    function withdraw(
        uint256 _amount,
        address _token,
        address _receiver,
        bool _isETH
    ) external globalNonReentrant returns (uint256 _amountOut) {

        IDataStore _dataStore = dataStore;
        OrchestratorHelper.validatePuppetInput(_dataStore, _amount, _receiver, _token);

        if (_isETH && _token != CommonHelper.wnt(_dataStore)) revert InvalidAsset();
 
        _amountOut = _debitAccount(_amount, _token, msg.sender, true);

        if (_isETH) {
            IWETH(_token).withdraw(_amountOut);
            payable(_receiver).sendValue(_amountOut);
        } else {
            IERC20(_token).safeTransfer(_receiver, _amountOut);
        }

        emit Withdraw(_amountOut, _token, _receiver, msg.sender);
    }

    /// @inheritdoc IBaseOrchestrator
    function setThrottleLimit(uint256 _throttleLimit, bytes32 _routeType) external globalNonReentrant notPaused {
        dataStore.setUint(Keys.puppetThrottleLimitKey(msg.sender, _routeType), _throttleLimit);

        emit SetThrottleLimit(msg.sender, _routeType, _throttleLimit);
    }

    // ============================================================================================
    // Route Functions
    // ============================================================================================

    /// @inheritdoc IBaseOrchestrator
    function debitAccounts(uint256[] memory _amounts, address[] memory _puppets, address _token) external onlyRoute {
        if (_amounts.length != _puppets.length) revert MismatchedInputArrays();

        for (uint256 i = 0; i < _puppets.length; i++) {
            _debitAccount(_amounts[i], _token, _puppets[i], false);
        }
    } 

    /// @inheritdoc IBaseOrchestrator
    function creditAccounts(uint256[] memory _amounts, address[] memory _puppets, address _token) external onlyRoute {
        if (_amounts.length != _puppets.length) revert MismatchedInputArrays();

        for (uint256 i = 0; i < _puppets.length; i++) {
            _creditAccount(_amounts[i], _token, _puppets[i]);
        }
    }

    /// @inheritdoc IBaseOrchestrator
    function updateLastPositionOpenedTimestamp(address[] memory _puppets) external onlyRoute {
        bytes32 _routeType = OrchestratorHelper.updateLastPositionOpenedTimestamp(
            dataStore,
            msg.sender,
            _puppets
        );

        emit UpdateOpenTimestamp(_puppets, _routeType);
    }

    /// @inheritdoc IBaseOrchestrator
    function transferTokens(uint256 _amount, address _token) external onlyRoute {
        IERC20(_token).safeTransfer(msg.sender, _amount);

        emit TransferTokens(_amount, _token, msg.sender);
    }

    /// @inheritdoc IBaseOrchestrator
    function emitExecutionCallback(
        uint256 _performanceFeePaid,
        bytes32 _requestKey,
        bool _isExecuted,
        bool _isIncrease
    ) external onlyRoute {
        emit ExecutePosition(_performanceFeePaid, msg.sender, _requestKey, _isExecuted, _isIncrease);
    }

    /// @inheritdoc IBaseOrchestrator
    function emitSharesIncrease(
        uint256[] memory _puppetsShares,
        uint256 _traderShares,
        uint256 _totalSupply,
        bytes32 _requestKey
    ) external onlyRoute {
        emit SharesIncrease(_puppetsShares, _traderShares, _totalSupply, msg.sender, _requestKey);
    }

    // ============================================================================================
    // Authority Functions
    // ============================================================================================

    // called by keeper

    /// @inheritdoc IBaseOrchestrator
    function decreaseSize(
        IBaseRoute.AdjustPositionParams memory _adjustPositionParams,
        uint256 _executionFee,
        bytes32 _routeKey
    ) external requiresAuth globalNonReentrant returns (bytes32 _requestKey) {
        address _route = OrchestratorHelper.validateRouteKey(dataStore, _routeKey);

        OrchestratorHelper.updateExecutionFeeBalance(dataStore, _executionFee, false);

        _requestKey = IBaseRoute(_route).decreaseSize{ value: _executionFee }(_adjustPositionParams, _executionFee);

        emit DecreaseSize(_route, _requestKey, _routeKey, positionKey(_route));
    }

    // called by owner

    /// @inheritdoc IBaseOrchestrator
    function updateDexAddresses(bytes memory _data) virtual external requiresAuth {}

    /// @inheritdoc IBaseOrchestrator
    function initialize(
        uint256 _minExecutionFee,
        address _wnt,
        address _platformFeeRecipient,
        address _routeFactory,
        address _gauge,
        address _referralManager,
        bytes memory _data
    ) external requiresAuth {
        if (_initialized) revert AlreadyInitialized();
        if (_platformFeeRecipient == address(0)) revert ZeroAddress();
        if (_routeFactory == address(0)) revert ZeroAddress();

        _initialized = true;

        OrchestratorHelper.setInitializeData( // @todo - fix this so that we get interfaces and not address (to make sure init is correct)
            dataStore,
            _minExecutionFee,
            _wnt,
            _platformFeeRecipient,
            _routeFactory,
            _gauge,
            _referralManager
        );

        _initialize(_data);

        emit Initialize(_platformFeeRecipient, _routeFactory, _gauge); // @todo fix this event
    }

    /// @inheritdoc IBaseOrchestrator
    function depositExecutionFees() external payable {
        if (msg.value == 0) revert InvalidAmount();

        OrchestratorHelper.updateExecutionFeeBalance(dataStore, msg.value, true);

        emit DepositExecutionFees(msg.value);
    }

    /// @inheritdoc IBaseOrchestrator
    function withdrawExecutionFees(uint256 _amount, address _receiver) external requiresAuth {
        if (_amount == 0) revert ZeroAmount();
        if (_receiver == address(0)) revert ZeroAddress();

        OrchestratorHelper.updateExecutionFeeBalance(dataStore, _amount, false);

        payable(_receiver).sendValue(_amount);

        emit WithdrawExecutionFees(_amount, _receiver);
    }

    /// @inheritdoc IBaseOrchestrator
    function withdrawPlatformFees(address _token) external globalNonReentrant {
        (uint256 _balance, address _platformFeeRecipient) = OrchestratorHelper.withdrawPlatformFees(dataStore, _token);
        IERC20(_token).safeTransfer(_platformFeeRecipient, _balance);

        emit WithdrawPlatformFees(_balance, _token);
    }

    /// @inheritdoc IBaseOrchestrator
    function setRouteType(
        address _collateralToken,
        address _indexToken,
        bool _isLong,
        bytes memory _data
    ) external requiresAuth {
        if (_collateralToken == address(0)) revert ZeroAddress();
        if (_indexToken == address(0)) revert ZeroAddress();

        bytes32 _routeTypeKey = Keys.routeTypeKey(_collateralToken, _indexToken, _isLong, _data);
        OrchestratorHelper.setRouteType(dataStore, _routeTypeKey, _collateralToken, _indexToken, _isLong, _data);

        emit SetRouteType(_routeTypeKey, _collateralToken, _indexToken, _isLong, _data);
    }

    /// @inheritdoc IBaseOrchestrator
    function updateRouteFactory(address _routeFactory) external requiresAuth {
        if (_routeFactory == address(0)) revert ZeroAddress();

        dataStore.setAddress(Keys.ROUTE_FACTORY, _routeFactory);

        emit UpdateRouteFactory(_routeFactory);
    }

    /// @inheritdoc IBaseOrchestrator
    function updateMultiSubscriber(address _multiSubscriber) external requiresAuth {
        if (_multiSubscriber == address(0)) revert ZeroAddress();

        dataStore.setAddress(Keys.MULTI_SUBSCRIBER, _multiSubscriber);

        emit UpdateMultiSubscriber(_multiSubscriber);
    }

    /// @inheritdoc IBaseOrchestrator
    function updateScoreGauge(address _gauge) external requiresAuth {
        if (_gauge == address(0)) revert ZeroAddress();

        dataStore.setAddress(Keys.SCORE_GAUGE, _gauge);

        emit UpdateScoreGauge(_gauge);
    }

    /// @inheritdoc IBaseOrchestrator
    function updateReferralCode(bytes32 _referralCode) external requiresAuth {
        if (_referralCode == bytes32(0)) revert ZeroBytes32();

        dataStore.setBytes32(Keys.REFERRAL_CODE, _referralCode);

        emit UpdateReferralCode(_referralCode);
    }

    /// @inheritdoc IBaseOrchestrator
    function updatePlatformFeesRecipient(address _recipient) external requiresAuth {
        if (_recipient == address(0)) revert ZeroAddress();

        dataStore.setAddress(Keys.PLATFORM_FEES_RECIPIENT, _recipient);

        emit UpdateFeesRecipient(_recipient);
    }

    /// @inheritdoc IBaseOrchestrator
    function updatePauseStatus(bool _paused) external requiresAuth {
        dataStore.setBool(Keys.PAUSED, _paused);

        emit UpdatePauseStatus(_paused);
    }

    /// @inheritdoc IBaseOrchestrator
    function updateMinExecutionFee(uint256 _minExecutionFee) external requiresAuth {
        if (_minExecutionFee == 0) revert ZeroAmount();

        dataStore.setUint(Keys.MIN_EXECUTION_FEE, _minExecutionFee);

        emit UpdateMinExecutionFee(_minExecutionFee);
    }

    /// @inheritdoc IBaseOrchestrator
    function updatePuppetKeeperMinExecutionFee(uint256 _puppetKeeperMinExecutionFee) external requiresAuth {
        if (_puppetKeeperMinExecutionFee == 0) revert ZeroAmount();

        dataStore.setUint(Keys.PUPPET_KEEPER_MIN_EXECUTION_FEE, _puppetKeeperMinExecutionFee);

        emit UpdatePuppetKeeperMinExecutionFee(_puppetKeeperMinExecutionFee);
    }

    /// @inheritdoc IBaseOrchestrator
    function updateMaxPuppets(uint256 _maxPuppets) external requiresAuth {
        if (_maxPuppets == 0) revert ZeroAmount();

        dataStore.setUint(Keys.MAX_PUPPETS, _maxPuppets);

        emit UpdateMaxPuppets(_maxPuppets);
    }

    /// @inheritdoc IBaseOrchestrator
    function updateFees(uint256 _managementFee, uint256 _withdrawalFee, uint256 _performanceFee) external requiresAuth {
        if (_managementFee > MAX_FEE || _withdrawalFee > MAX_FEE || _performanceFee > MAX_FEE) revert FeeExceedsMax();

        IDataStore _dataStore = dataStore;
        _dataStore.setUint(Keys.MANAGEMENT_FEE, _managementFee);
        _dataStore.setUint(Keys.WITHDRAWAL_FEE, _withdrawalFee);
        _dataStore.setUint(Keys.PERFORMANCE_FEE, _performanceFee);

        emit UpdateFees(_managementFee, _withdrawalFee, _performanceFee);
    }

    /// @inheritdoc IBaseOrchestrator
    function forceCallback(address _route, bytes32 _requestKey, bool _isExecuted, bool _isIncrease) external requiresAuth {
        if (_route == address(0)) revert ZeroAddress();

        IBaseRoute(_route).forceCallback(_requestKey, _isExecuted, _isIncrease);

        emit ForceCallback(_route, _requestKey, _isExecuted, _isIncrease);
    }

    /// @inheritdoc IBaseOrchestrator
    function rescueToken(uint256 _amount, address _token, address _receiver, address _route) external requiresAuth {
        if (_amount == 0 || _token == address(0) || _receiver == address(0) || _route == address(0)) revert ZeroAddress();

        IBaseRoute(_route).rescueToken(_amount, _token, _receiver);

        emit RescueToken(_amount, _token, _receiver, _route);
    }

    // ============================================================================================
    // Internal Mutated Functions
    // ============================================================================================

    function _initialize(bytes memory _data) internal virtual;

    // ============================================================================================
    // Private Mutated Functions
    // ============================================================================================

    /// @notice The ```_debitAccount``` function debits a Puppet's account
    /// @param _amount The amount to debit
    /// @param _token The token address
    /// @param _puppet The Puppet address
    /// @param _isWithdraw The boolean indicating if the debit is a withdraw or for investing in a position
    /// @return _amountOut The amount out, after fees
    function _debitAccount(
        uint256 _amount,
        address _token,
        address _puppet,
        bool _isWithdraw
    ) private returns (uint256 _amountOut) {
        uint256 _feeAmount = OrchestratorHelper.debitPuppetAccount(dataStore, _amount, _token, _puppet, _isWithdraw);

        _amountOut = _amount - _feeAmount;

        emit DebitPuppet(_amount + _feeAmount, _token, _puppet, msg.sender);
        emit CreditPlatform(_feeAmount, _token, _puppet, msg.sender, _isWithdraw);
    }

    /// @notice The ```_creditAccount``` function credits a Puppet's account
    /// @param _amount The amount to credit
    /// @param _token The token address
    /// @param _puppet The Puppet address
    function _creditAccount(uint256 _amount, address _token, address _puppet) private {
        dataStore.incrementUint(Keys.puppetDepositAccountKey(_puppet, _token), _amount);

        emit CreditPuppet(_amount, _token, _puppet, msg.sender);
    }

    // ============================================================================================
    // Receive Function
    // ============================================================================================

    receive() external payable {}
}