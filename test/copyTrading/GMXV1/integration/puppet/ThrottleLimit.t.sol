// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../../BaseGMXV1.t.sol";

contract GMXV1ThrottleLimit is BaseGMXV1 {

    function setUp() public override {
        BaseGMXV1.setUp();
    }

    function testBatchSubscribeFlow() external {
        _throttleLimit.throttleLimitTest(context);
    }
}