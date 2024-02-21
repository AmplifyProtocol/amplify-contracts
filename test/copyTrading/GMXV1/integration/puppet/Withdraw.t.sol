// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../../BaseGMXV1.t.sol";

contract GMXV1Withdraw is BaseGMXV1 {

    function setUp() public override {
        BaseGMXV1.setUp();
    }

    function testWithdrawNoFeesFlow() external {
        _withdraw.withdrawFlowTest(context, _deposit);
    }
}