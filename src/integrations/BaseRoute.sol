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
// ========================= BaseRoute ==========================
// ==============================================================
// Amplify Protocol: https://github.com/AmplifyProtocol

// ==============================================================

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {
    Address,
    CommonHelper,
    Keys,
    RouteReader,
    RouteSetter,
    SharesHelper,
    IBaseOrchestrator,
    IBaseRoute,
    IDataStore
} from "./libraries/RouteSetter.sol";

import {IScoreGauge} from "../tokenomics/interfaces/IScoreGauge.sol";

import {IWETH} from "../utilities/interfaces/IWETH.sol";

/// @title BaseRoute
/// @author johnnyonline
/// @notice BaseRoute is a container account for a specific trading route, callable by the Orchestrator and owned by a Trader
abstract contract BaseRoute is IBaseRoute, ReentrancyGuard {

    using SafeERC20 for IERC20;

    using Address for address payable;

    IDataStore public immutable dataStore;

    // ============================================================================================
    // Constructor
    // ============================================================================================

    /// @notice The ```constructor``` function is called on deployment
    /// @param _dataStore The dataStore contract instance
    constructor(IDataStore _dataStore) {
        dataStore = _dataStore;
    }

    // ============================================================================================
    // Modifiers
    // ============================================================================================

    /// @notice Ensures the caller is the orchestrator
    modifier onlyOrchestrator() {
        if (msg.sender != RouteReader.orchestrator(dataStore)) revert NotOrchestrator();
        _;
    }

    /// @notice Ensures the caller is the callback caller
    modifier onlyCallbackCaller() {
        if (msg.sender != _callBackCaller()) revert NotCallbackCaller();
        _;
    }

    // ============================================================================================
    // Orchestrator Functions
    // ============================================================================================

    // called by trader

    /// @inheritdoc IBaseRoute
    function requestPosition(
        AdjustPositionParams memory _adjustPositionParams,
        SwapParams memory _swapParams,
        ExecutionFees memory _executionFees,
        bool _isIncrease
    ) external payable onlyOrchestrator nonReentrant returns (bytes32 _requestKey) {

        IDataStore _dataStore = dataStore;
        if (RouteReader.isWaitingForCallback(_dataStore, address(this))) revert WaitingForCallback();
        if (RouteReader.isWaitingForKeeperAdjustment(_dataStore, address(this))) revert WaitingForKeeperAdjustment();

        _repayBalance(true, true, bytes32(0));

        if (_isIncrease) {
            (
                uint256 _puppetsAmountIn,
                uint256 _traderAmountIn,
                uint256 _traderShares,
                uint256 _totalSupply
            ) = _getAssets(_swapParams, _executionFees.dexKeeper + _executionFees.puppetKeeper, _adjustPositionParams.puppets);

            RouteSetter.setTargetLeverage(
                _dataStore,
                _executionFees.puppetKeeper,
                _adjustPositionParams.sizeDelta,
                _traderAmountIn,
                _traderShares,
                _totalSupply
            );

            _adjustPositionParams.collateralDelta = _puppetsAmountIn + _traderAmountIn;
        }

        _requestKey = _requestPosition(_adjustPositionParams, _executionFees.dexKeeper, _isIncrease);
    }

    /// @inheritdoc IBaseRoute
    function cancelRequest(bytes32 _requestKey) external payable onlyOrchestrator {
        _cancelRequest(_requestKey);

        emit CancelRequest(_requestKey);
    }

    // called by keeper

    /// @inheritdoc IBaseRoute
    function decreaseSize(
        AdjustPositionParams memory _adjustPositionParams,
        uint256 _executionFee
    ) external payable onlyOrchestrator nonReentrant returns (bytes32 _requestKey) {
        _requestKey = _requestPosition(_adjustPositionParams, _executionFee, false);

        RouteSetter.storeKeeperRequest(dataStore, _requestKey);

        emit DecreaseSize(_requestKey, _adjustPositionParams.sizeDelta, _adjustPositionParams.acceptablePrice);
    }

    // called by owner

    /// @inheritdoc IBaseRoute
    function forceCallback(bytes32 _requestKey, bool _isExecuted, bool _isIncrease) external onlyOrchestrator nonReentrant {
        _callback(_requestKey, _isExecuted, _isIncrease);

        emit ForceCallback(_requestKey, _isExecuted, _isIncrease);
    }

    /// @inheritdoc IBaseRoute
    function rescueToken(uint256 _amount, address _token, address _receiver) external onlyOrchestrator nonReentrant {
        _token == address(0) ? payable(_receiver).sendValue(_amount) : IERC20(_token).safeTransfer(_receiver, _amount);

        emit RescueToken(_amount, _token, _receiver);
    }

    // ============================================================================================
    // Callback Function
    // ============================================================================================

    /// @notice The ```_callback``` function is triggered upon request execution
    /// @param _requestKey The request key
    /// @param _isExecuted Whether the request was executed
    /// @param _isIncrease Whether the request was an increase request
    function _callback(bytes32 _requestKey, bool _isExecuted, bool _isIncrease) internal onlyCallbackCaller nonReentrant {

        IDataStore _dataStore = dataStore;
        RouteSetter.onCallback(_dataStore, _isExecuted, _isIncrease, _requestKey);

        uint256 _performanceFeePaid = _repayBalance(_isExecuted, _isIncrease, _requestKey);

        _resetRoute();

        IBaseOrchestrator(RouteReader.orchestrator(_dataStore)).emitExecutionCallback(
            _performanceFeePaid,
            _requestKey,
            _isExecuted,
            _isIncrease
        );

        emit Callback(_requestKey, _isExecuted, _isIncrease);
    }

    // ============================================================================================
    // Internal Mutated Functions
    // ============================================================================================

    /// @notice The ```_getTraderAssets``` function is used to get the assets of the Trader
    /// @param _swapParams The swap data of the Trader, enables the Trader to add collateral with a non-collateral token
    /// @param _executionFee The execution fee paid by the Trader, in ETH
    /// @return _traderAmountIn The total amount of collateral token the Trader is requesting to add to the position
    function _getTraderAssets(SwapParams memory _swapParams, uint256 _executionFee) virtual internal returns (uint256 _traderAmountIn);

    /// @notice makes a increase request call to the underlying DEX
    /// @param _adjustPositionParams The adjusment params for the position
    /// @param _executionFee The execution fee
    /// @return _requestKey The request key of the request
    function _makeRequestIncreasePositionCall(
        AdjustPositionParams memory _adjustPositionParams,
        uint256 _executionFee
    ) virtual internal returns (bytes32 _requestKey);

    /// @notice makes a decrease request call to the underlying DEX
    /// @param _adjustPositionParams The adjusment params for the position
    /// @param _executionFee The execution fee
    /// @return _requestKey The request key of the request
    function _makeRequestDecreasePositionCall(
        AdjustPositionParams memory _adjustPositionParams,
        uint256 _executionFee
    ) virtual internal returns (bytes32 _requestKey);

    /// @notice The ```_cancelRequest``` function is used to cancel a non-market request
    /// @param _requestKey The request key of the request
    function _cancelRequest(bytes32 _requestKey) virtual internal;

    /// @notice The ```_repayBalance``` function is used to repay the Route's balance and adjust the Route's flags
    /// @param _isExecuted A boolean indicating whether the request was executed
    /// @param _isIncrease A boolean indicating whether the request is an increase request
    /// @param _requestKey The request key of the request
    /// @return _performanceFeePaid The amount of performance fee paid to the Trader
    function _repayBalance(bool _isExecuted, bool _isIncrease, bytes32 _requestKey) internal returns (uint256 _performanceFeePaid) {

        IDataStore _dataStore = dataStore;
        address _collateralToken = CommonHelper.collateralToken(_dataStore, address(this));
        uint256 _totalAssets = IERC20(_collateralToken).balanceOf(address(this));
        if (_totalAssets > 0 && RouteReader.isAvailableShares(_dataStore)) {
            uint256[] memory _puppetsAssets;
            uint256 _puppetsTotalAssets;
            uint256 _traderAssets;
            (
                _puppetsAssets,
                _puppetsTotalAssets,
                _traderAssets,
                _performanceFeePaid
            ) = RouteSetter.repayBalanceData(_dataStore, _totalAssets, _isExecuted, _isIncrease);

            address _orchestrator = RouteReader.orchestrator(_dataStore);
            IBaseOrchestrator(_orchestrator).creditAccounts(_puppetsAssets, RouteReader.puppetsInPosition(_dataStore), _collateralToken);

            IERC20(_collateralToken).safeTransfer(_orchestrator, _puppetsTotalAssets);
            IERC20(_collateralToken).safeTransfer(CommonHelper.trader(_dataStore, address(this)), _traderAssets);
        }

        if (_requestKey != bytes32(0)) {
            RouteSetter.setAdjustmentFlags(_dataStore, _isExecuted, RouteReader.isKeeperRequestKey(_dataStore, _requestKey));
        }

        /// @dev send unused execution fees to the Trader
        if (address(this).balance > msg.value) {
            uint256 _amount = address(this).balance - msg.value;
            address _wnt = CommonHelper.wnt(_dataStore);
            payable(_wnt).functionCallWithValue(abi.encodeWithSignature("deposit()"), _amount);
            IERC20(_wnt).safeTransfer(CommonHelper.trader(_dataStore, address(this)), _amount);
            emit RepayWNT(_amount);
        }

        emit Repay(_totalAssets, _requestKey);
    }

    /// @notice The ```_resetRoute``` function is used to reset the Route and update user scores when the position has been closed
    function _resetRoute() internal {
        IDataStore _dataStore = dataStore;
        if (!_isOpenInterest() && CommonHelper.isPositionOpen(_dataStore, address(this))) {
            address _gauge = CommonHelper.scoreGauge(_dataStore);
            if (_gauge != address(0)) IScoreGauge(_gauge).updateUsersScore(address(this));
            RouteSetter.resetRoute(_dataStore);
            emit ResetRoute();
        }
    }

    // ============================================================================================
    // Private Mutated Functions
    // ============================================================================================

    /// @notice The ```_getAssets``` function is used to get the assets of the Trader and Puppets and update the request accounting
    /// @param _swapParams The swap data of the Trader, enables the Trader to add collateral with a non-collateral token
    /// @param _executionFee The execution fee paid by the Trader, in ETH
    /// @param _puppets The array of Puppts
    /// @return _puppetsAmountIn The amount of collateral the Puppets will add to the position
    /// @return _traderAmountIn The amount of collateral the Trader will add to the position
    /// @return _traderShares The amount of shares the Trader will receive
    /// @return _totalSupply The total amount of shares for the request
    function _getAssets(
        SwapParams memory _swapParams,
        uint256 _executionFee,
        address[] memory _puppets
    ) private returns (uint256 _puppetsAmountIn, uint256 _traderAmountIn, uint256 _traderShares, uint256 _totalSupply) {
        if (_swapParams.amount > 0) {
            _traderAmountIn = _getTraderAssets(_swapParams, _executionFee);
            _traderShares = SharesHelper.convertToShares(0, 0, _traderAmountIn);

            IDataStore _dataStore = dataStore;
            (_puppetsAmountIn, _totalSupply) = RouteSetter.storeNewAddCollateralRequest(
                _dataStore,
                _traderAmountIn,
                _traderShares,
                _puppets
            );

            IBaseOrchestrator(RouteReader.orchestrator(_dataStore)).transferTokens(
                _puppetsAmountIn,
                _swapParams.path[_swapParams.path.length - 1]
            );
        }
    }

    /// @notice The ```_requestPosition``` function is used to create a position request
    /// @param _adjustPositionParams The adjusment params for the position
    /// @param _executionFee The total execution fee, paid by the Trader in ETH
    /// @param _isIncrease A boolean indicating whether the request is an increase or decrease request
    /// @return _requestKey The request key of the request
    function _requestPosition(
        AdjustPositionParams memory _adjustPositionParams,
        uint256 _executionFee,
        bool _isIncrease
    ) private returns (bytes32 _requestKey) {
        _requestKey = _isIncrease
        ? _makeRequestIncreasePositionCall(_adjustPositionParams, _executionFee)
        : _makeRequestDecreasePositionCall(_adjustPositionParams, _executionFee);

        RouteSetter.storePositionRequest(dataStore, _adjustPositionParams.sizeDelta, _requestKey);

        emit RequestPosition(
            _requestKey,
            _adjustPositionParams.collateralDelta,
            _adjustPositionParams.sizeDelta,
            _adjustPositionParams.acceptablePrice,
            _isIncrease
        );
    }

    // ============================================================================================
    // Internal View Functions
    // ============================================================================================

    /// @notice The ```_isOpenInterest``` function is used to indicate whether the Route has open interest, according to the underlying DEX
    /// @return bool A boolean indicating whether the Route has open interest
    function _isOpenInterest() virtual internal view returns (bool) {}

    /// @notice The ```_callBackCaller``` function is used to get the callback caller address
    /// @return address The callback caller address
    function _callBackCaller() virtual internal view returns (address) {}

    // ============================================================================================
    // Receive Function
    // ============================================================================================

    receive() external payable {}
}