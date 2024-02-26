// // SPDX-License-Identifier: AGPL-3.0-only
// pragma solidity 0.8.23;

// import "../../BaseGMXV1.t.sol";

// contract GMXV1DepositIntegration is BaseGMXV1 {

//     bytes32 _routeKeyGMXV1DepositIntegration;

//     function setUp() public override {
//         BaseGMXV1.setUp();

//         _routeKeyGMXV1DepositIntegration = _registerRoute.registerRoute(
//             context,
//             context.users.trader,
//             _weth,
//             _weth,
//             true,
//             _emptyBytes
//         );
//     }

//     function testDepositWNTFlow() external {
//         _deposit.depositWNTFlowTest(context, false);
//     }

//     function testDepositNativeTokenFlow() external {
//         _deposit.depositWNTFlowTest(context, true);
//     }

//     function testDepositWNTAndBatchSubscribe() external {
//         _deposit.puppetsDepsitWNTAndBatchSubscribeFlowTest(context, true, _routeKeyGMXV1DepositIntegration);
//     }

//     function testDepositNativeTokenAndBatchSubscribe() external {
//         _deposit.puppetsDepsitWNTAndBatchSubscribeFlowTest(context, false, _routeKeyGMXV1DepositIntegration);
//     }
// }