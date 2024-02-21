// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../../BaseGMXV2.t.sol";

contract GMXV2ThrottleLimitIntegration is BaseGMXV2 {

    function setUp() public override {
        BaseGMXV2.setUp();
    }

    function testBatchSubscribeFlow() external {
        _throttleLimit.throttleLimitTest(context);
    }
}