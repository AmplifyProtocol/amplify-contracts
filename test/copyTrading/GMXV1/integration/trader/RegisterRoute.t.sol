// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../../BaseGMXV1.t.sol";

contract GMXV1RegisterRouteIntegration is BaseGMXV1 {
    
    function setUp() public override {
        BaseGMXV1.setUp();
    }

    function testRegisterRoute() external {
        _registerRoute.registerRoute(context, context.users.trader, _weth, _weth, true, _emptyBytes);
    }
}