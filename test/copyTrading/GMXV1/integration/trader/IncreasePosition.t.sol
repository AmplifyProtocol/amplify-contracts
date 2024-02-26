// // SPDX-License-Identifier: AGPL-3.0-only
// pragma solidity 0.8.23;

// import "../../BaseGMXV1.t.sol";

// contract GMXV1IncreasePositionIntegration is BaseGMXV1 {

//     function setUp() public override {
//         BaseGMXV1.setUp();
//     }

//     // ============================================================================================
//     // Test Functions
//     // ============================================================================================

//     function testIncreaseLongPosition() external {
//         bytes32 _routeKey = _registerRoute.registerRoute(context, context.users.trader, _weth, _weth, true, _emptyBytes);

//         context.expectations.isSuccessfulExecution = true;

//         for (uint256 i = 0; i < 5; i++) {
//             _positionHandler.increasePosition(context, _requestPosition, IBaseRoute.OrderType.MarketIncrease, context.users.trader, _weth, _weth, true);
//             _positionHandler.executeRequest(context, _callbackAsserts, context.users.trader, true, _routeKey);
//         }

//         _positionHandler.increasePosition(context, _requestPosition, IBaseRoute.OrderType.MarketIncrease, context.users.trader, _weth, _weth, true);

//         _positionHandler.executeRequest(context, _callbackAsserts, context.users.trader, true, _routeKey);
//     }

//     function testIncreaseShortPosition() external {
//         bytes32 _routeKey = _registerRoute.registerRoute(context, context.users.trader, context.usdc, _weth, false, _emptyBytes);

//         context.expectations.isSuccessfulExecution = true;

//         for (uint256 i = 0; i < 3; i++) {
//             _positionHandler.increasePosition(context, _requestPosition, IBaseRoute.OrderType.MarketIncrease, context.users.trader, context.usdc, _weth, false);
//             _positionHandler.executeRequest(context, _callbackAsserts, context.users.trader, true, _routeKey);
//         }

//         _positionHandler.increasePosition(context, _requestPosition, IBaseRoute.OrderType.MarketIncrease, context.users.trader, context.usdc, _weth, false);

//         _positionHandler.executeRequest(context, _callbackAsserts, context.users.trader, true, _routeKey);
//     }

//     function testFaultyCallback() external {
//         bytes32 _routeKey = _registerRoute.registerRoute(context, context.users.trader, _weth, _weth, true, _emptyBytes);

//         _requestPosition.requestPositionFaulty(context, _routeKey);

//         context.expectations.isSuccessfulExecution = false;
//         context.expectations.isPuppetsSubscribed = false;
//         _positionHandler.executeRequest(context, _callbackAsserts, context.users.trader, true, _routeKey);
//     }
// }