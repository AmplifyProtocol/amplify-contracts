// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../../BaseGMXV2.t.sol";

contract GMXV2IncreasePositionIntegration is BaseGMXV2 {

    function setUp() public override {
        BaseGMXV2.setUp();
    }

    // ============================================================================================
    // Test Functions
    // ============================================================================================

    function testCancelOrderNoMock() external {
        bytes32 _routeKey = _registerRoute.registerRoute(context, context.users.trader, _weth, _weth, true, _ethLongMarketData);

        _updateGMXAddress();

        bytes32 _requestKey = _positionHandler.increasePosition(
            context,
            _requestPosition,
            IBaseRoute.OrderType.LimitIncrease,
            context.users.trader,
            _weth,
            _weth,
            true
        );

        _requestPosition.cancelOrder(context, _callbackAsserts, true, _requestKey, _routeKey);

        context.expectations.isOrderCancelled = true;
        _positionHandler.simulateExecuteRequest(context, _routeKey, _requestKey);
    }

    function testIncreaseLongPositionLimitOrderNoMock() external {
        bytes32 _routeKey = _registerRoute.registerRoute(context, context.users.trader, _weth, _weth, true, _ethLongMarketData);

        _updateGMXAddress();

        bytes32 _requestKey = _positionHandler.increasePosition(
            context,
            _requestPosition,
            IBaseRoute.OrderType.LimitIncrease,
            context.users.trader,
            _weth,
            _weth,
            true
        );

        _positionHandler.simulateExecuteRequest(context, _routeKey, _requestKey);
    }

    function testIncreaseLongPositionNoMock() external {
        bytes32 _routeKey = _registerRoute.registerRoute(context, context.users.trader, _weth, _weth, true, _ethLongMarketData);

        _updateGMXAddress();

        bytes32 _requestKey = _positionHandler.increasePosition(
            context,
            _requestPosition,
            IBaseRoute.OrderType.MarketIncrease,
            context.users.trader,
            _weth,
            _weth,
            true
        );

        _positionHandler.simulateExecuteRequest(context, _routeKey, _requestKey);
    }

    function testIncreaseShortPositionLimitOrderNoMock() external {
        bytes32 _routeKey = _registerRoute.registerRoute(context, context.users.trader, context.usdc, _weth, false, _ethShortMarketData);

        _updateGMXAddress();

        bytes32 _requestKey = _positionHandler.increasePosition(
            context,
            _requestPosition,
            IBaseRoute.OrderType.LimitIncrease,
            context.users.trader,
            context.usdc,
            _weth,
            false
        );

        _positionHandler.simulateExecuteRequest(context, _routeKey, _requestKey);
    }

    function testIncreaseShortPositionNoMock() external {
        bytes32 _routeKey = _registerRoute.registerRoute(context, context.users.trader, context.usdc, _weth, false, _ethShortMarketData);

        _updateGMXAddress();

        bytes32 _requestKey = _positionHandler.increasePosition(
            context,
            _requestPosition,
            IBaseRoute.OrderType.MarketIncrease,
            context.users.trader,
            context.usdc,
            _weth,
            false
        );

        _positionHandler.simulateExecuteRequest(context, _routeKey, _requestKey);
    }

    function testIncreaseLongPosition() external {
        bytes32 _routeKey = _registerRoute.registerRoute(context, context.users.trader, _weth, _weth, true, _ethLongMarketData);

        context.expectations.isSuccessfulExecution = true;
        context.expectations.isArtificialExecution = true;
        context.expectations.isUsingMocks = true;

        for (uint256 i = 0; i < 5; i++) {
            context.expectations.requestKeyToExecute = _positionHandler.increasePosition(context, _requestPosition, IBaseRoute.OrderType.MarketIncrease, context.users.trader, _weth, _weth, true);
            _positionHandler.executeRequest(context, _callbackAsserts, context.users.trader, true, _routeKey);
        }
    }

    function testIncreaseShortPosition() external {
        bytes32 _routeKey = _registerRoute.registerRoute(context, context.users.trader, context.usdc, _weth, false, _ethShortMarketData);

        context.expectations.isSuccessfulExecution = true;
        context.expectations.isArtificialExecution = true;
        context.expectations.isUsingMocks = true;

        for (uint256 i = 0; i < 5; i++) {
            context.expectations.requestKeyToExecute = _positionHandler.increasePosition(context, _requestPosition, IBaseRoute.OrderType.MarketIncrease, context.users.trader, context.usdc, _weth, false);
            _positionHandler.executeRequest(context, _callbackAsserts, context.users.trader, true, _routeKey);
        }
    }

    function testFaultyCallback() external {
        bytes32 _routeKey = _registerRoute.registerRoute(context, context.users.trader, _weth, _weth, true, _ethLongMarketData);

        context.expectations.isUsingMocks = true;
        context.expectations.isSuccessfulExecution = false;
        context.expectations.isPuppetsSubscribed = false;
        context.expectations.isArtificialExecution = true;

        context.expectations.requestKeyToExecute = _requestPosition.requestPositionFaulty(context, _routeKey);

        _positionHandler.executeRequest(context, _callbackAsserts, context.users.trader, true, _routeKey);
    }
}