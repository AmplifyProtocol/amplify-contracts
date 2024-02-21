// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../../BaseGMXV2.t.sol";

contract GMXV2PuppetDepositFuzz is BaseGMXV2 {

    function setUp() public override {
        BaseGMXV2.setUp();
    }

    function testFuzz_Deposit_Amount(uint256 _amount, uint256 _value) external {
        _fuzz_PuppetDeposit.deposit_fuzzAmount(context, _amount, _value);
    }

    function testFuzz_Deposit_Token(address _token) external {
        _fuzz_PuppetDeposit.deposit_fuzzToken(context, _token);
    }

    function testFuzz_Deposit_Receiver(address _receiver) external {
        _fuzz_PuppetDeposit.deposit_fuzzReceiver(context, _receiver);
    }
}