// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../../BaseGMXV2.t.sol";

contract GMXV2SubscribeIntegration is BaseGMXV2 {

    function setUp() public override {
        BaseGMXV2.setUp();
    }

    function testCancelOrderWithSubscribedPuppetsNoMock() external {
        bytes32 _routeKey = _registerRoute.registerRoute(context, context.users.trader, _weth, _weth, true, _ethLongMarketData);
        address _route = _dataStore.getAddress(Keys.routeAddressKey(_routeKey));
        bytes32 _routeTypeKey = _dataStore.getBytes32(Keys.routeRouteTypeKey(_route));

        uint256 _expiry = block.timestamp + 24 hours;
        uint256 _allowance = _BASIS_POINTS_DIVISOR / 20; // 5%
        _subscribe.subscribe(context, context.users.alice, true, _allowance, _expiry, context.users.trader, _routeTypeKey);
        _subscribe.subscribe(context, context.users.bob, true, _allowance, _expiry, context.users.trader, _routeTypeKey);
        _subscribe.subscribe(context, context.users.yossi, true, _allowance, _expiry, context.users.trader, _routeTypeKey);

        _deposit.depositEntireWNTBalance(context, context.users.alice, true);
        _deposit.depositEntireWNTBalance(context, context.users.bob, true);
        _deposit.depositEntireWNTBalance(context, context.users.yossi, true);

        _updateGMXAddress();

        context.expectations.isPuppetsSubscribed = true;
        context.expectations.subscribedPuppets = new address[](3);
        context.expectations.subscribedPuppets[0] = context.users.alice;
        context.expectations.subscribedPuppets[1] = context.users.bob;
        context.expectations.subscribedPuppets[2] = context.users.yossi;

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

    function testBatchSubscribeFlow() external {
        bytes32[] memory _routeKeys = new bytes32[](2);
        _routeKeys[0] = _registerRoute.registerRoute(context, context.users.trader, _weth, _weth, true, _ethLongMarketData);
        _routeKeys[1] = _registerRoute.registerRoute(context, context.users.trader, context.usdc, _weth, false, _ethShortMarketData);
        _subscribe.batchSubscribeFlowTest(context, _routeKeys);
    }

    function testSubscribeAndIncreasePosition() external {
        bytes32 _routeKey = _registerRoute.registerRoute(context, context.users.trader, _weth, _weth, true, _ethLongMarketData);
        address _route = _dataStore.getAddress(Keys.routeAddressKey(_routeKey));
        bytes32 _routeTypeKey = _dataStore.getBytes32(Keys.routeRouteTypeKey(_route));

        uint256 _expiry = block.timestamp + 24 hours;
        uint256 _allowance = _BASIS_POINTS_DIVISOR / 20; // 5%
        _subscribe.subscribe(context, context.users.alice, true, _allowance, _expiry, context.users.trader, _routeTypeKey);
        _subscribe.subscribe(context, context.users.bob, true, _allowance, _expiry, context.users.trader, _routeTypeKey);
        _subscribe.subscribe(context, context.users.yossi, true, _allowance, _expiry, context.users.trader, _routeTypeKey);

        _deposit.depositEntireWNTBalance(context, context.users.alice, true);
        _deposit.depositEntireWNTBalance(context, context.users.bob, true);
        _deposit.depositEntireWNTBalance(context, context.users.yossi, true);

        context.expectations.isArtificialExecution = true;
        context.expectations.isUsingMocks = true;
        context.expectations.isPuppetsSubscribed = true;
        context.expectations.isSuccessfulExecution = true;
        context.expectations.isExpectingAdjustment = false;
        context.expectations.subscribedPuppets = new address[](3);
        context.expectations.subscribedPuppets[0] = context.users.alice;
        context.expectations.subscribedPuppets[1] = context.users.bob;
        context.expectations.subscribedPuppets[2] = context.users.yossi;

        context.expectations.requestKeyToExecute = _positionHandler.increasePosition(context, _requestPosition, IBaseRoute.OrderType.MarketIncrease, context.users.trader, _weth, _weth, true);
        _positionHandler.executeRequest(context, _callbackAsserts, context.users.trader, true, _routeKey);

        context.expectations.requestKeyToExecute = _positionHandler.decreasePosition(context, _requestPosition, IBaseRoute.OrderType.MarketDecrease, false, _routeKey);
        _positionHandler.executeRequest(context, _callbackAsserts, context.users.trader, false, _routeKey);

        context.expectations.isPositionClosed = true;
        context.expectations.requestKeyToExecute = _positionHandler.decreasePosition(context, _requestPosition, IBaseRoute.OrderType.MarketDecrease, true, _routeKey);
        _positionHandler.executeRequest(context, _callbackAsserts, context.users.trader, false, _routeKey);
    }

    function testSubscribeAndIncreasePositionExpectingExpiry() external {
        bytes32 _routeKey = _registerRoute.registerRoute(context, context.users.trader, _weth, _weth, true, _ethLongMarketData);
        {
            uint256 _expiry = block.timestamp + 24 hours;
            uint256 _allowance = _BASIS_POINTS_DIVISOR / 20; // 5%
            bytes32 _routeTypeKey = _dataStore.getBytes32(Keys.routeRouteTypeKey(_dataStore.getAddress(Keys.routeAddressKey(_routeKey))));
            _subscribe.subscribe(context, context.users.alice, true, _allowance, _expiry, context.users.trader, _routeTypeKey);
            _subscribe.subscribe(context, context.users.bob, true, _allowance, _expiry, context.users.trader, _routeTypeKey);
            _subscribe.subscribe(context, context.users.yossi, true, _allowance, _expiry, context.users.trader, _routeTypeKey);
        }

        _deposit.depositEntireWNTBalance(context, context.users.alice, true);
        _deposit.depositEntireWNTBalance(context, context.users.bob, true);
        _deposit.depositEntireWNTBalance(context, context.users.yossi, true);

        context.expectations.isArtificialExecution = true;
        context.expectations.isUsingMocks = true;
        context.expectations.isSuccessfulExecution = true;
        context.expectations.subscribedPuppets = new address[](3);
        context.expectations.subscribedPuppets[0] = context.users.alice;
        context.expectations.subscribedPuppets[1] = context.users.bob;
        context.expectations.subscribedPuppets[2] = context.users.yossi;

        context.expectations.isPuppetsSubscribed = true;
        context.expectations.isExpectingAdjustment = false;
        context.expectations.requestKeyToExecute = _positionHandler.increasePosition(context, _requestPosition, IBaseRoute.OrderType.MarketIncrease, context.users.trader, _weth, _weth, true);
        _positionHandler.executeRequest(context, _callbackAsserts, context.users.trader, true, _routeKey);

        context.expectations.subscribedPuppets = new address[](0);

        context.expectations.isExpectingAdjustment = true;
        context.expectations.isPuppetsSubscribed = false;
        context.expectations.isPuppetsExpiryExpected = true;
        IPositionHandler _wrappedPositionHandler = IPositionHandler(address(_positionHandler));
        _subscribe.expireSubscriptionsAndExecute(context, _wrappedPositionHandler, _requestPosition, _callbackAsserts, context.users.trader, _routeKey);

        context.expectations.isPositionClosed = true;
        context.expectations.isExpectingAdjustment = false;
        context.expectations.isPuppetsExpiryExpected = true;
        context.expectations.requestKeyToExecute = _positionHandler.decreasePosition(context, _requestPosition, IBaseRoute.OrderType.MarketDecrease, true, _routeKey);
        _positionHandler.executeRequest(context, _callbackAsserts, context.users.trader, false, _routeKey);
    }

    function testSubscribeAndIncreasePositionFaulty() external {
        bytes32 _routeKey = _registerRoute.registerRoute(context, context.users.trader, _weth, _weth, true, _ethLongMarketData);

        {
            uint256 _expiry = block.timestamp + 24 hours;
            uint256 _allowance = _BASIS_POINTS_DIVISOR / 20; // 5%
            bytes32 _routeTypeKey = _dataStore.getBytes32(Keys.routeRouteTypeKey(_dataStore.getAddress(Keys.routeAddressKey(_routeKey))));
            _subscribe.subscribe(context, context.users.alice, true, _allowance, _expiry, context.users.trader, _routeTypeKey);
            _subscribe.subscribe(context, context.users.bob, true, _allowance, _expiry, context.users.trader, _routeTypeKey);
            _subscribe.subscribe(context, context.users.yossi, true, _allowance, _expiry, context.users.trader, _routeTypeKey);
        }

        _deposit.depositEntireWNTBalance(context, context.users.alice, true);
        _deposit.depositEntireWNTBalance(context, context.users.bob, true);
        _deposit.depositEntireWNTBalance(context, context.users.yossi, true);

        context.expectations.isArtificialExecution = true;
        context.expectations.isUsingMocks = true;
        context.expectations.subscribedPuppets = new address[](3);
        context.expectations.subscribedPuppets[0] = context.users.alice;
        context.expectations.subscribedPuppets[1] = context.users.bob;
        context.expectations.subscribedPuppets[2] = context.users.yossi;

        context.expectations.isPuppetsSubscribed = true;
        context.expectations.requestKeyToExecute = _requestPosition.requestPositionFaulty(context, _routeKey);

        context.expectations.isSuccessfulExecution = false;
        _positionHandler.executeRequest(context, _callbackAsserts, context.users.trader, true, _routeKey);
    }

    function testNonZeroRouteCollateralBalanceBeforeAdjustment() external {
        bytes32 _routeKey = _registerRoute.registerRoute(context, context.users.trader, _weth, _weth, true, _ethLongMarketData);
        {
            uint256 _expiry = block.timestamp + 24 hours;
            uint256 _allowance = _BASIS_POINTS_DIVISOR / 20; // 5%
            bytes32 _routeTypeKey = _dataStore.getBytes32(Keys.routeRouteTypeKey(_dataStore.getAddress(Keys.routeAddressKey(_routeKey))));
            _subscribe.subscribe(context, context.users.alice, true, _allowance, _expiry, context.users.trader, _routeTypeKey);
            _subscribe.subscribe(context, context.users.bob, true, _allowance, _expiry, context.users.trader, _routeTypeKey);
            _subscribe.subscribe(context, context.users.yossi, true, _allowance, _expiry, context.users.trader, _routeTypeKey);
        }

        _deposit.depositEntireWNTBalance(context, context.users.alice, true);
        _deposit.depositEntireWNTBalance(context, context.users.bob, true);
        _deposit.depositEntireWNTBalance(context, context.users.yossi, true);

        context.expectations.isArtificialExecution = true;
        context.expectations.isUsingMocks = true;
        context.expectations.isSuccessfulExecution = true;
        context.expectations.isPuppetsSubscribed = true;
        context.expectations.isExpectingAdjustment = false;
        context.expectations.isExpectingNonZeroBalance = true;
        context.expectations.subscribedPuppets = new address[](3);
        context.expectations.subscribedPuppets[0] = context.users.alice;
        context.expectations.subscribedPuppets[1] = context.users.bob;
        context.expectations.subscribedPuppets[2] = context.users.yossi;

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