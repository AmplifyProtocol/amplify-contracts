// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../../BaseGMXV2.t.sol";

contract GMXV2DepositIntegration is BaseGMXV2 {

    bytes32 _routeKeyGMXV2DepositIntegration;

    function setUp() public override {
        BaseGMXV2.setUp();

        _routeKeyGMXV2DepositIntegration = _registerRoute.registerRoute(
            context,
            context.users.trader,
            _weth,
            _weth,
            true,
            _ethLongMarketData
        );
    }

    function testDepositWNTFlow() external {
        _deposit.depositWNTFlowTest(context, false);
    }

    function testDepositNativeTokenFlow() external {
        _deposit.depositWNTFlowTest(context, true);
    }

    function testDepositWNTAndBatchSubscribe() external {
        _deposit.puppetsDepsitWNTAndBatchSubscribeFlowTest(context, true, _routeKeyGMXV2DepositIntegration);
    }

    function testDepositNativeTokenAndBatchSubscribe() external {
        _deposit.puppetsDepsitWNTAndBatchSubscribeFlowTest(context, false, _routeKeyGMXV2DepositIntegration);
    }
}