// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../../BaseGMXV2.t.sol";

contract GMXV2DecreasePositionIntegration is BaseGMXV2 {

    function setUp() public override {
        BaseGMXV2.setUp();
    }

    // ============================================================================================
    // Test Functions
    // ============================================================================================

    function testDecreaseLongPosition() external {
        bytes32 _routeKey = _registerRoute.registerRoute(context, context.users.trader, _weth, _weth, true, _ethLongMarketData);

        context.expectations.isSuccessfulExecution = true;
        context.expectations.isArtificialExecution = true;
        context.expectations.isUsingMocks = true;

        context.expectations.requestKeyToExecute = _positionHandler.increasePosition(context, _requestPosition, IBaseRoute.OrderType.MarketIncrease, context.users.trader, _weth, _weth, true);
        _positionHandler.executeRequest(context, _callbackAsserts, context.users.trader, true, _routeKey);

        context.expectations.requestKeyToExecute = _positionHandler.decreasePosition(context, _requestPosition, IBaseRoute.OrderType.MarketDecrease, false, _routeKey);
        _positionHandler.executeRequest(context, _callbackAsserts, context.users.trader, false, _routeKey);

        context.expectations.isPositionClosed = true;
        context.expectations.requestKeyToExecute = _positionHandler.decreasePosition(context, _requestPosition, IBaseRoute.OrderType.MarketDecrease, true, _routeKey);
        _positionHandler.executeRequest(context, _callbackAsserts, context.users.trader, false, _routeKey);

        context.expectations.isPositionClosed = false;
        context.expectations.requestKeyToExecute = _positionHandler.increasePosition(context, _requestPosition, IBaseRoute.OrderType.MarketIncrease, context.users.trader, _weth, _weth, true);
        _positionHandler.executeRequest(context, _callbackAsserts, context.users.trader, true, _routeKey);

        for (uint256 i = 0; i < 5; i++) {
            context.expectations.requestKeyToExecute = _positionHandler.decreasePosition(context, _requestPosition, IBaseRoute.OrderType.MarketDecrease, false, _routeKey);
            _positionHandler.executeRequest(context, _callbackAsserts, context.users.trader, false, _routeKey);
        }

        context.expectations.isPositionClosed = true;
        context.expectations.requestKeyToExecute = _positionHandler.decreasePosition(context, _requestPosition, IBaseRoute.OrderType.MarketDecrease, true, _routeKey);
        _positionHandler.executeRequest(context, _callbackAsserts, context.users.trader, false, _routeKey);
    }

    function testDecreaseShortPosition() external {
        bytes32 _routeKey = _registerRoute.registerRoute(context, context.users.trader, context.usdc, _weth, false, _ethShortMarketData);

        context.expectations.isSuccessfulExecution = true;
        context.expectations.isArtificialExecution = true;
        context.expectations.isUsingMocks = true;

        context.expectations.requestKeyToExecute = _positionHandler.increasePosition(context, _requestPosition, IBaseRoute.OrderType.MarketIncrease, context.users.trader, context.usdc, _weth, false);
        _positionHandler.executeRequest(context, _callbackAsserts, context.users.trader, true, _routeKey);

        context.expectations.requestKeyToExecute = _positionHandler.decreasePosition(context, _requestPosition, IBaseRoute.OrderType.MarketDecrease, false, _routeKey);
        _positionHandler.executeRequest(context, _callbackAsserts, context.users.trader, false, _routeKey);

        context.expectations.isPositionClosed = true;
        context.expectations.requestKeyToExecute = _positionHandler.decreasePosition(context, _requestPosition, IBaseRoute.OrderType.MarketDecrease, true, _routeKey);
        _positionHandler.executeRequest(context, _callbackAsserts, context.users.trader, false, _routeKey);
    }

    function testNonZeroRouteCollateralBalanceBeforeAdjustment() external {
        bytes32 _routeKey = _registerRoute.registerRoute(context, context.users.trader, _weth, _weth, true, _ethLongMarketData);

        context.expectations.isArtificialExecution = true;
        context.expectations.isUsingMocks = true;
        context.expectations.isSuccessfulExecution = true;

        context.expectations.isExpectingNonZeroBalance = true;

        address _route = _dataStore.getAddress(Keys.routeAddressKey(_routeKey));
        address _collateral = _dataStore.getAddress(Keys.routeCollateralTokenKey(_route));
        _dealERC20(_collateral, _route, 1 ether);

        context.expectations.requestKeyToExecute = _positionHandler.increasePosition(context, _requestPosition, IBaseRoute.OrderType.MarketIncrease, context.users.trader, _weth, _weth, true);
        _positionHandler.executeRequest(context, _callbackAsserts, context.users.trader, true, _routeKey);

        _dealERC20(_collateral, _route, 1 ether);

        context.expectations.isPositionClosed = true;
        context.expectations.requestKeyToExecute = _positionHandler.decreasePosition(context, _requestPosition, IBaseRoute.OrderType.MarketDecrease, true, _routeKey);
        _positionHandler.executeRequest(context, _callbackAsserts, context.users.trader, false, _routeKey);
    }
}