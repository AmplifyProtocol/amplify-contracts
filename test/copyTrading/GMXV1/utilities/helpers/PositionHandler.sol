// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {GMXKeys} from "../../../../../src/integrations/GMXV1/libraries/GMXKeys.sol";

import {IGMXPositionRouter} from "../../../../../src/integrations/GMXV1/interfaces/IGMXPositionRouter.sol";
import {IVault} from "../../../../../src/integrations/GMXV1/interfaces/IVault.sol";

import {CallbackAsserts} from "../../../shared/global/CallbackAsserts.sol";

import {RequestPosition} from "../../../shared/trader/RequestPosition.sol";

import "../../../shared/BaseHelper.t.sol";

contract PositionHandler is BaseHelper {

    // ============================================================================================
    // Helper Functions
    // ============================================================================================

    function increasePosition(
        Context memory _context,
        RequestPosition _requestPosition,
        IBaseRoute.OrderType _orderType,
        address _trader,
        address _collateralToken,
        address _indexToken,
        bool _isLong
    ) external returns (bytes32 _requestKey) {
        uint256 _sizeDelta;
        uint256 _amountInTrader;
        if (_isLong) {
            require(_collateralToken == _indexToken, "IncreasePositionUnitConcrete: collateral token is not index token"); // because of `_amountInTrader`

            uint256 _availableSize = IGMXPositionRouter(IDataStore(_context.dataStore).getAddress(GMXKeys.POSITION_ROUTER)).maxGlobalLongSizes(_indexToken) - IVault(IDataStore(_context.dataStore).getAddress(GMXKeys.VAULT)).guaranteedUsd(_indexToken);
            uint256 _availableSizeInIndexToken = _availableSize * 1e30 / IBaseOrchestrator(_context.orchestrator).getPrice(_indexToken);

            // should result in max 10x leverage (if no Puppets funds)
            _sizeDelta = _availableSize / 10;
            _amountInTrader = _availableSizeInIndexToken / 100 / 1e12; // index token has 18 decimals

            if (_context.expectations.isExpectingAdjustment) {
                // making sure we decrease the position's leverage
                _sizeDelta = _availableSize / 10;
                _amountInTrader = _availableSizeInIndexToken / 20 / 1e12;
            }
        } else {
            require(_collateralToken == _context.usdc, "IncreasePositionUnitConcrete: collateral token not USDC");

            uint256 _availableSize = IGMXPositionRouter(IDataStore(_context.dataStore).getAddress(GMXKeys.POSITION_ROUTER)).maxGlobalShortSizes(_indexToken) - IVault(IDataStore(_context.dataStore).getAddress(GMXKeys.VAULT)).globalShortSizes(_indexToken);

            // should result in max 10x leverage (if no Puppets funds)
            _sizeDelta = _availableSize / 10;
            _amountInTrader = _availableSize / 100 / 1e24; // USDC has 6 decimals
        }

        IBaseRoute.AdjustPositionParams memory _adjustPositionParams = IBaseRoute.AdjustPositionParams({
            orderType: _orderType,
            collateralDelta: 0,
            sizeDelta: _sizeDelta,
            acceptablePrice: _isLong ? type(uint256).max : type(uint256).min,
            triggerPrice: 0,
            puppets: _context.expectations.subscribedPuppets
        });

        IBaseRoute.SwapParams memory _swapParams;
        {
            address[] memory _path = new address[](1);
            _path[0] = _collateralToken;
            _swapParams = IBaseRoute.SwapParams({
                path: _path,
                amount: _amountInTrader,
                minOut: 0
            });
        }

        {
            bytes32 _routeTypeKey = _isLong ? _context.longETHRouteTypeKey : _context.shortETHRouteTypeKey;
            _requestKey = _requestPosition.requestPositionERC20(
                _context,
                _adjustPositionParams,
                _swapParams,
                _trader,
                true,
                _routeTypeKey
            );
        }
    }

    function decreasePosition(
        Context memory _context,
        RequestPosition _requestPosition,
        IBaseRoute.OrderType _orderType,
        bool _isClose,
        bytes32 _routeKey
    ) external returns (bytes32 _requestKey) {
        address _route = IDataStore(_context.dataStore).getAddress(Keys.routeAddressKey(_routeKey));
        address _collateralToken = IDataStore(_context.dataStore).getAddress(Keys.routeCollateralTokenKey(_route));
        address _indexToken = IDataStore(_context.dataStore).getAddress(Keys.routeIndexTokenKey(_route));
        address _trader = IDataStore(_context.dataStore).getAddress(Keys.routeTraderKey(_route));
        bool _isLong = IDataStore(_context.dataStore).getBool(Keys.routeIsLongKey(_route));
        IBaseRoute.AdjustPositionParams memory _adjustPositionParams;
        {
            (uint256 _positionSize, uint256 _positionCollateral,,,,,,) = IVault(IDataStore(_context.dataStore).getAddress(GMXKeys.VAULT)).getPosition(IDataStore(_context.dataStore).getAddress(Keys.routeAddressKey(_routeKey)), _collateralToken, _indexToken, _isLong);
            require(_positionSize > 0 && _positionCollateral > 0, "decreasePosition: E1");

            _adjustPositionParams = IBaseRoute.AdjustPositionParams({
                orderType: _orderType,
                collateralDelta: _isClose ? _positionCollateral : _positionCollateral / 2,
                sizeDelta: _isClose ? _positionSize : _positionSize / 2,
                acceptablePrice: _isLong ? type(uint256).min : type(uint256).max,
                triggerPrice: 0,
                puppets: new address[](0)
            });
        }

        IBaseRoute.SwapParams memory _swapParams;
        {
            address[] memory _path = new address[](1);
            _path[0] = _collateralToken;
            _swapParams = IBaseRoute.SwapParams({
                path: _path,
                amount: 0,
                minOut: 0
            });
        }

        {
            bytes32 _routeTypeKey = _isLong ? _context.longETHRouteTypeKey : _context.shortETHRouteTypeKey;
            _requestKey = _requestPosition.requestPositionERC20(
                _context,
                _adjustPositionParams,
                _swapParams,
                _trader,
                false,
                _routeTypeKey
            );
        }
    }

    function executeRequest(
        Context memory _context,
        CallbackAsserts _callbackAsserts,
        address _trader,
        bool _isIncrease,
        bytes32 _routeKey
    ) external {
        assertTrue(IBaseOrchestrator(_context.orchestrator).isWaitingForCallback(_routeKey), "executeRequest: E0");

        address _route = IDataStore(_context.dataStore).getAddress(Keys.routeAddressKey(_routeKey));
        IGMXPositionRouter _gmxPositionRouter = IGMXPositionRouter(IDataStore(_context.dataStore).getAddress(GMXKeys.POSITION_ROUTER));

        CallbackAsserts.BeforeData memory _beforeData;
        uint256 _positionIndex = IDataStore(_context.dataStore).getUint(Keys.positionIndexKey(_route));
        {
            address _orchestrator = address(_context.orchestrator);
            address _collateralToken = IDataStore(_context.dataStore).getAddress(Keys.routeCollateralTokenKey(_route));
            _beforeData = CallbackAsserts.BeforeData({
                aliceDepositAccountBalanceBefore: CommonHelper.puppetAccountBalance(_context.dataStore, _context.users.alice, _collateralToken),
                orchestratorEthBalanceBefore: _orchestrator.balance,
                executionFeeBalanceBefore: _context.dataStore.getUint(Keys.EXECUTION_FEE_BALANCE),
                volumeGeneratedBefore: IDataStore(_context.dataStore).getUint(Keys.cumulativeVolumeGeneratedKey(_positionIndex, _route)),
                traderSharesBefore: IDataStore(_context.dataStore).getUint(Keys.positionTraderSharesKey(_positionIndex, _route)),
                traderLastAmountIn: IDataStore(_context.dataStore).getUint(Keys.positionLastTraderAmountInKey(_positionIndex, _route)),
                traderETHBalanceBefore: _trader.balance,
                traderCollateralTokenBalanceBefore: IERC20(_collateralToken).balanceOf(_trader),
                orchestratorCollateralTokenBalanceBefore: IERC20(_collateralToken).balanceOf(_orchestrator),
                trader: _trader,
                isIncrease: _isIncrease,
                routeKey: _routeKey
            });
        }

        vm.startPrank(_gmxV1PositionRouterKeeper);
        if (_isIncrease) {
            _gmxPositionRouter.executeIncreasePositions(type(uint256).max, payable(_route));
        } else {
            if (_context.expectations.isExpectingPerformanceFee) assertEq(_context.dataStore.getUint(Keys.performanceFeePaidKey(_positionIndex, _route)), 0, "executeRequest: E2");
            _gmxPositionRouter.executeDecreasePositions(type(uint256).max, payable(_route));
            if (_context.expectations.isExpectingPerformanceFee) assertTrue(_context.dataStore.getUint(Keys.performanceFeePaidKey(_positionIndex, _route)) > 0, "executeRequest: E3");
        }
        vm.stopPrank();

        if (_context.expectations.isSuccessfulExecution) {
            _callbackAsserts.postSuccessfulExecution(_context, _beforeData);
        } else {
            _callbackAsserts.postFailedExecution(_context, _beforeData);
        }

        if (_context.expectations.isExpectingAdjustment && _isIncrease) {
            assertTrue(DecreaseSizeResolver(_context.decreaseSizeResolver).requiredAdjustmentSize(_route) > 0, "executeRequest: E4");
            assertTrue(IBaseOrchestrator(_context.orchestrator).isWaitingForCallback(_routeKey), "executeRequest: E5");

            (uint256 _sizeBefore, uint256 _collateralBefore) = IBaseOrchestrator(_context.orchestrator).positionAmounts(_route);
            uint256 _leverageBefore = _sizeBefore * _BASIS_POINTS_DIVISOR / _collateralBefore;
            uint256 _targetLeverage = _context.dataStore.getUint(Keys.targetLeverageKey(_route));
            assertTrue(_leverageBefore > _targetLeverage, "executeRequest: E6");

            vm.prank(_gmxV1PositionRouterKeeper);
            _gmxPositionRouter.executeDecreasePositions(type(uint256).max, payable(_route));

            assertEq(DecreaseSizeResolver(_context.decreaseSizeResolver).requiredAdjustmentSize(_route), 0, "executeRequest: E7");
            assertTrue(!IBaseOrchestrator(_context.orchestrator).isWaitingForCallback(_routeKey), "executeRequest: E8");
            assertTrue(!IDataStore(_context.dataStore).getBool(Keys.isWaitingForKeeperAdjustmentKey(_route)), "executeRequest: E9");

            (uint256 _sizeAfter, uint256 _collateralAfter) = IBaseOrchestrator(_context.orchestrator).positionAmounts(_route);
            uint256 _leverageAfter = _sizeAfter * _BASIS_POINTS_DIVISOR / _collateralAfter;
            assertApproxEqAbs(_leverageAfter, _targetLeverage, 2000, "executeRequest: E10");
            assertApproxEqAbs(_collateralAfter, _collateralBefore, 1e35, "executeRequest: E11");
            assertTrue(_sizeAfter < _sizeBefore, "executeRequest: E12");
            assertTrue(_leverageAfter < _leverageBefore, "executeRequest: E13");
        }
    }
}