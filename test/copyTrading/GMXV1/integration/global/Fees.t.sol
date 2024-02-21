// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../../BaseGMXV1.t.sol";

contract GMXV1FeesIntegration is BaseGMXV1 {

    bytes32 _routeKeyFeesUnitConcrete;

    function setUp() public override {
        BaseGMXV1.setUp();

        _routeKeyFeesUnitConcrete = _registerRoute.registerRoute(context, context.users.trader, _weth, _weth, true, _emptyBytes);
    }

    function testWithdrawalFee() external {
        _fees.withdrawalFeeTest(context, _deposit, _withdraw);
    }

    function testManagmentFee() external {
        _fees.managmentFeeTest(
            context,
            _deposit,
            _subscribe,
            _requestPosition,
            address(_positionHandler),
            _routeKeyFeesUnitConcrete
        );
    }

    function testPerformanceFee() external {
        _fees.performanceFeeTest(
            context,
            _deposit,
            _subscribe,
            _requestPosition,
            _callbackAsserts,
            address(_positionHandler),
            _routeKeyFeesUnitConcrete
        );
    }
}