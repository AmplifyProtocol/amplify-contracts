// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../../BaseGMXV2.t.sol";

contract GMXV2FeesIntegration is BaseGMXV2 {

    bytes32 _routeKeyFeesUnitConcrete;

    function setUp() public override {
        BaseGMXV2.setUp();

        _routeKeyFeesUnitConcrete = _registerRoute.registerRoute(context, context.users.trader, _weth, _weth, true, _ethLongMarketData);
    }

    function testWithdrawalFee() external {
        _fees.withdrawalFeeTest(context, _deposit, _withdraw);
    }

    function testManagmentFee() external {
        context.expectations.isUsingMocks = true;
        _fees.managmentFeeTest(context, _deposit, _subscribe, _requestPosition, address(_positionHandler), _routeKeyFeesUnitConcrete);
    }

    function testPerformanceFee() external {
        context.expectations.isSuccessfulExecution = true;
        context.expectations.isArtificialExecution = true;
        context.expectations.isUsingMocks = true;

        _fees.performanceFeeTest(context, _deposit, _subscribe, _requestPosition, _callbackAsserts, address(_positionHandler), _routeKeyFeesUnitConcrete);
    }
}