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
// ========================== Route =============================
// ==============================================================
// Amplify Protocol: https://github.com/AmplifyProtocol

// ==============================================================

import {IOrderCallbackReceiver} from "./interfaces/IOrderCallbackReceiver.sol";
import {IGMXEventUtils} from "./interfaces/IGMXEventUtils.sol";
import {IGMXOrder} from "./interfaces/IGMXOrder.sol";

import {GMXV2RouteHelper} from "./libraries/GMXV2RouteHelper.sol";
import {OrderUtils} from "./libraries/OrderUtils.sol";

import {
    Address,
    BaseRoute,
    CommonHelper,
    Keys,
    RouteReader,
    SafeERC20,
    IBaseOrchestrator,
    IDataStore,
    IERC20
} from "../../integrations/BaseRoute.sol";

/// @title Route
/// @author johnnyonline
/// @notice This contract extends the ```BaseRoute``` and is modified to fit GMX V2
contract Route is IOrderCallbackReceiver, BaseRoute {

    using Address for address payable;

    using SafeERC20 for IERC20;

    // ============================================================================================
    // Constructor
    // ============================================================================================

    /// @notice The ```constructor``` function is called on deployment
    /// @param _dataStore The dataStore contract address
    constructor(IDataStore _dataStore) BaseRoute(_dataStore) {}

    // ============================================================================================
    // External Mutated Functions
    // ============================================================================================

    function claimFundingFees(address[] memory _markets, address[] memory _tokens) external onlyOrchestrator {
        GMXV2RouteHelper.gmxExchangeRouter(dataStore).claimFundingFees(
            _markets,
            _tokens,
            CommonHelper.trader(dataStore, address(this))
        );
    }

    // ============================================================================================
    // Callback Functions
    // ============================================================================================

    /// @inheritdoc IOrderCallbackReceiver
    function afterOrderExecution(
        bytes32 _requestKey,
        IGMXOrder.Props memory _order,
        IGMXEventUtils.EventLogData memory
    ) external {
        if (OrderUtils.isLiquidationOrder(_order.numbers.orderType)) {
            _repayBalance(true, true, bytes32(0));
            _resetRoute();
            IBaseOrchestrator(RouteReader.orchestrator(dataStore)).emitExecutionCallback(0, bytes32(0), true, false);
            return;
        }
        _callback(_requestKey, true, OrderUtils.isIncrease(_order.numbers.orderType));
    }

    /// @inheritdoc IOrderCallbackReceiver
    function afterOrderCancellation(
        bytes32 _requestKey,
        IGMXOrder.Props memory _order,
        IGMXEventUtils.EventLogData memory
    ) external {
        _callback(_requestKey, false, OrderUtils.isIncrease(_order.numbers.orderType));
    }

    /// @inheritdoc IOrderCallbackReceiver
    /// @dev If an order is frozen, a Trader must call the ```cancelRequest``` function to cancel the order
    function afterOrderFrozen(
        bytes32 _requestKey,
        IGMXOrder.Props memory _order,
        IGMXEventUtils.EventLogData memory
    ) external {}

    // ============================================================================================
    // Internal Mutated Functions
    // ============================================================================================

    /// @inheritdoc BaseRoute
    function _getTraderAssets(SwapParams memory _swapParams, uint256 _executionFee) internal override returns (uint256 _traderAmountIn) {

        IDataStore _dataStore = dataStore;
        if (
            _swapParams.path.length != 1 || _swapParams.path[0] != CommonHelper.collateralToken(_dataStore, address(this))
        ) revert InvalidPath();

        if (msg.value - _executionFee > 0) {
            if (msg.value - _executionFee != _swapParams.amount) revert InvalidExecutionFee();
            address _wnt = CommonHelper.wnt(_dataStore);
            if (_swapParams.path[0] != _wnt) revert InvalidPath();

            payable(_wnt).functionCallWithValue(abi.encodeWithSignature("deposit()"), _swapParams.amount);
        } else {
            if (msg.value != _executionFee) revert InvalidExecutionFee();

            IBaseOrchestrator(CommonHelper.orchestrator(_dataStore)).transferTokens(_swapParams.amount, _swapParams.path[0]);
        }

        return _swapParams.amount;
    }

    /// @inheritdoc BaseRoute
    function _makeRequestIncreasePositionCall(
        AdjustPositionParams memory _adjustPositionParams,
        uint256 _executionFee
    ) internal override returns (bytes32 _requestKey) {
        return _makeRequestPositionCall(_adjustPositionParams, _executionFee, true);
    }

    /// @inheritdoc BaseRoute
    function _makeRequestDecreasePositionCall(
        AdjustPositionParams memory _adjustPositionParams,
        uint256 _executionFee
    ) internal override returns (bytes32 _requestKey) {
        return _makeRequestPositionCall(_adjustPositionParams, _executionFee, false);
    }

    /// @inheritdoc BaseRoute
    function _cancelRequest(bytes32 _requestKey) override internal {
        _sendTokensToRouter(0, msg.value);
        GMXV2RouteHelper.gmxExchangeRouter(dataStore).cancelOrder(_requestKey);
    }

    // ============================================================================================
    // Private Mutated Functions
    // ============================================================================================

    function _makeRequestPositionCall(
        AdjustPositionParams memory _adjustPositionParams,
        uint256 _executionFee,
        bool _isIncrease
    ) private returns (bytes32 _requestKey) {
        IDataStore _dataStore = dataStore;
        OrderUtils.CreateOrderParams memory _params = GMXV2RouteHelper.getCreateOrderParams(
            _dataStore,
            _adjustPositionParams,
            _executionFee,
            _isIncrease
        );

        uint256 _amountIn = 0;
        if (_isIncrease) _amountIn = _adjustPositionParams.collateralDelta;
        _sendTokensToRouter(_amountIn, _executionFee);

        return GMXV2RouteHelper.gmxExchangeRouter(_dataStore).createOrder(_params);
    }

    function _sendTokensToRouter(uint256 _amountIn, uint256 _executionFee) private {
        IDataStore _dataStore = dataStore;
        address _wnt = CommonHelper.wnt(_dataStore);
        payable(_wnt).functionCallWithValue(abi.encodeWithSignature("deposit()"), _executionFee);

        address _collateralToken = CommonHelper.collateralToken(_dataStore, address(this));
        if (_collateralToken == _wnt) {
            IERC20(_collateralToken).forceApprove(GMXV2RouteHelper.gmxRouter(_dataStore), _amountIn + _executionFee);
            GMXV2RouteHelper.gmxExchangeRouter(_dataStore).sendTokens(
                _collateralToken,
                GMXV2RouteHelper.gmxOrderVault(_dataStore),
                _amountIn + _executionFee
            );
        } else {
            // send WETH for execution fee
            IERC20(_wnt).forceApprove(GMXV2RouteHelper.gmxRouter(_dataStore), _executionFee);
            GMXV2RouteHelper.gmxExchangeRouter(_dataStore).sendTokens(
                _wnt,
                GMXV2RouteHelper.gmxOrderVault(_dataStore),
                _executionFee
            );

            if (_amountIn > 0) {
                // send collateral tokens
                IERC20(_collateralToken).forceApprove(GMXV2RouteHelper.gmxRouter(_dataStore), _amountIn);
                GMXV2RouteHelper.gmxExchangeRouter(_dataStore).sendTokens(
                    _collateralToken,
                    GMXV2RouteHelper.gmxOrderVault(_dataStore),
                    _amountIn
                );
            }
        }
    }

    // ============================================================================================
    // Internal View Functions
    // ============================================================================================

    /// @inheritdoc BaseRoute
    function _isOpenInterest() override internal view returns (bool) {
        return GMXV2RouteHelper.isOpenInterest(dataStore);
    }

    /// @inheritdoc BaseRoute
    function _callBackCaller() override internal view returns (address) {
        return GMXV2RouteHelper.gmxCallBackCaller(dataStore);
    }

    // ============================================================================================
    // Errors
    // ============================================================================================

    error InvalidPath();
}