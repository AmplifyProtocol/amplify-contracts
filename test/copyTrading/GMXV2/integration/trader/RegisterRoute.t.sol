// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../../BaseGMXV2.t.sol";

contract GMXV2RegisterRouteIntegration is BaseGMXV2 {
    
    function setUp() public override {
        BaseGMXV2.setUp();
    }

    function testRegisterRoute() external {
        _registerRoute.registerRoute(context, context.users.trader, _weth, _weth, true, _ethLongMarketData);
    }
}