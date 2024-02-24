// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../../Base.t.sol";

contract VotingEscrowTests is Base {

    function setUp() public override {
        Base.setUp();

        skip(86400); // skip INFLATION_DELAY (1 day)
        _ampl.updateMiningParameters(); // start 1st epoch
        skip(86400 * 365); // skip the entire epoch (year)
        vm.startPrank(address(_minter));
        _ampl.mint(users.alice, 100000 * 1e18);
        _ampl.mint(users.bob, 100000 * 1e18);
        _ampl.mint(users.yossi, 100000 * 1e18);
        vm.stopPrank();
    }

    // ============================================================================================
    // Test Functions
    // ============================================================================================

    function testParamsOnDeployment() public {
        // sanity deploy params tests
        assertEq(_votingEscrow.decimals(), 18, "testParamsOnDeployment: E0");
        assertEq(_votingEscrow.name(), "Vote-escrowed Amplify", "testParamsOnDeployment: E1");
        assertEq(_votingEscrow.symbol(), "veAMPL", "testParamsOnDeployment: E2");
        assertEq(address(_votingEscrow.token()), address(_ampl), "testParamsOnDeployment: E3");

        // sanity view functions tests
        assertEq(_votingEscrow.getLastUserSlope(users.alice), 0, "testParamsOnDeployment: E5");
        assertEq(_votingEscrow.lockedEnd(users.alice), 0, "testParamsOnDeployment: E7");
        assertEq(_votingEscrow.balanceOf(users.alice, block.timestamp), 0, "testParamsOnDeployment: E8");
        assertEq(_votingEscrow.totalSupply(block.timestamp), 0, "testParamsOnDeployment: E11");
        assertEq(_votingEscrow.totalSupplyAt(block.number), 0, "testParamsOnDeployment: E12");

        _votingEscrow.checkpoint();

        assertEq(_votingEscrow.getLastUserSlope(users.alice), 0, "testParamsOnDeployment: E13");
        assertEq(_votingEscrow.lockedEnd(users.alice), 0, "testParamsOnDeployment: E15");
        assertEq(_votingEscrow.balanceOf(users.alice, block.timestamp), 0, "testParamsOnDeployment: E16");
        assertEq(_votingEscrow.totalSupply(block.timestamp), 0, "testParamsOnDeployment: E19");
        assertEq(_votingEscrow.totalSupplyAt(block.number), 0, "testParamsOnDeployment: E20");
    }

    function testMutated() public {
        uint256 _aliceAmountLocked = _ampl.balanceOf(users.alice) / 3;
        uint256 _bobAmountLocked = _ampl.balanceOf(users.bob) / 3;
        uint256 _totalSupplyBefore;
        uint256 _votingEscrowBalanceBefore;
        uint256 _lockedAmountBefore;

        // --- CREATE LOCK ---

        // alice
        _checkCreateLockWrongFlows(users.alice);
        vm.startPrank(users.alice);
        _totalSupplyBefore = _votingEscrow.totalSupply(block.timestamp);
        _votingEscrowBalanceBefore = _ampl.balanceOf(address(_votingEscrow));
        _lockedAmountBefore = _votingEscrow.lockedAmount(users.alice);
        _ampl.approve(address(_votingEscrow), _aliceAmountLocked);
        _votingEscrow.modifyLock(_aliceAmountLocked, block.timestamp + _votingEscrow.maxTime() + _votingEscrow.maxTime(), users.alice);
        vm.stopPrank();
        _checkUserVotingDataAfterCreateLock(users.alice, _aliceAmountLocked, _totalSupplyBefore, _votingEscrowBalanceBefore, _lockedAmountBefore);

        // bob
        _checkCreateLockWrongFlows(users.bob);
        vm.startPrank(users.bob);
        _totalSupplyBefore = _votingEscrow.totalSupply(block.timestamp);
        _votingEscrowBalanceBefore = _ampl.balanceOf(address(_votingEscrow));
        _lockedAmountBefore = _votingEscrow.lockedAmount(users.bob);
        _ampl.approve(address(_votingEscrow), _bobAmountLocked);
        _votingEscrow.modifyLock(_bobAmountLocked, block.timestamp + _votingEscrow.maxTime() + _votingEscrow.maxTime(), users.bob);
        vm.stopPrank();
        _checkUserVotingDataAfterCreateLock(users.bob, _bobAmountLocked, _totalSupplyBefore, _votingEscrowBalanceBefore, _lockedAmountBefore);

        // --- DEPOSIT FOR ---

        // alice
        vm.startPrank(users.alice);
        _ampl.approve(address(_votingEscrow), _bobAmountLocked);
        vm.stopPrank();
        vm.startPrank(users.alice);
        _totalSupplyBefore = _votingEscrow.totalSupply(block.timestamp);
        _votingEscrowBalanceBefore = _ampl.balanceOf(address(_votingEscrow));
        _lockedAmountBefore = _votingEscrow.lockedAmount(users.bob);
        uint256 _aliceBalanceBefore = _votingEscrow.balanceOf(users.alice, block.timestamp);
        uint256 _bobBalanceBefore = _votingEscrow.balanceOf(users.bob, block.timestamp);
        _votingEscrow.modifyLock(_aliceAmountLocked, 0, users.bob);
        vm.stopPrank();
        _checkUserBalancesAfterDepositFor(users.alice, users.bob, _aliceBalanceBefore, _bobBalanceBefore, _aliceAmountLocked, _totalSupplyBefore, _votingEscrowBalanceBefore, _lockedAmountBefore);

        // bob
        vm.startPrank(users.bob);
        _ampl.approve(address(_votingEscrow), _aliceAmountLocked);
        vm.stopPrank();
        vm.startPrank(users.bob);
        _totalSupplyBefore = _votingEscrow.totalSupply(block.timestamp);
        _votingEscrowBalanceBefore = _ampl.balanceOf(address(_votingEscrow));
        _lockedAmountBefore = _votingEscrow.lockedAmount(users.alice);
        _aliceBalanceBefore = _votingEscrow.balanceOf(users.alice, block.timestamp);
        _bobBalanceBefore = _votingEscrow.balanceOf(users.bob, block.timestamp);
        _votingEscrow.modifyLock(_bobAmountLocked, 0, users.alice);
        vm.stopPrank();
        _checkUserBalancesAfterDepositFor(users.bob, users.alice, _bobBalanceBefore, _aliceBalanceBefore, _bobAmountLocked, _totalSupplyBefore, _votingEscrowBalanceBefore, _lockedAmountBefore);

        // --- DECREASE UNLOCK TIME ---

        vm.startPrank(users.alice);
        uint256 _aliceBalanceBeforeUnlock = _votingEscrow.balanceOf(users.alice, block.timestamp);
        uint256 _totalSupplyBeforeUnlock = _votingEscrow.totalSupply(block.timestamp);
        _votingEscrow.modifyLock(0, block.timestamp + _votingEscrow.maxTime() + 8 days, users.alice);
        assertEq(_votingEscrow.balanceOf(users.alice, block.timestamp), _aliceBalanceBeforeUnlock, "testMutated: E0");
        assertEq(_votingEscrow.totalSupply(block.timestamp), _totalSupplyBeforeUnlock, "testMutated: E1");
        vm.stopPrank();

        vm.startPrank(users.bob);
        uint256 _bobBalanceBeforeUnlock = _votingEscrow.balanceOf(users.bob, block.timestamp);
        _votingEscrow.modifyLock(0, block.timestamp + _votingEscrow.maxTime() + 8 days, users.bob);
        assertEq(_votingEscrow.balanceOf(users.bob, block.timestamp), _bobBalanceBeforeUnlock, "testMutated: E2");
        assertEq(_votingEscrow.totalSupply(block.timestamp), _totalSupplyBeforeUnlock, "testMutated: E1");
        vm.stopPrank();

        skip(8 days); // skip the extra 8 days


        // --- INCREASE UNLOCK TIME ---

        _checkLockTimesBeforeSkip();
        _aliceBalanceBefore = _votingEscrow.balanceOf(users.alice, block.timestamp);
        _bobBalanceBefore = _votingEscrow.balanceOf(users.bob, block.timestamp);
        _totalSupplyBefore = _votingEscrow.totalSupply(block.timestamp);
        skip(_votingEscrow.maxTime() / 2); // skip half of the lock time
        _checkLockTimesAfterSkipHalf(_aliceBalanceBefore, _bobBalanceBefore, _totalSupplyBefore);

        vm.startPrank(users.alice);
        _aliceBalanceBeforeUnlock = _votingEscrow.balanceOf(users.alice, block.timestamp);
        _totalSupplyBeforeUnlock = _votingEscrow.totalSupply(block.timestamp);
        _votingEscrow.modifyLock(0, block.timestamp + _votingEscrow.maxTime(), users.alice);
        vm.stopPrank();

        vm.startPrank(users.bob);
        _bobBalanceBeforeUnlock = _votingEscrow.balanceOf(users.bob, block.timestamp);
        _votingEscrow.modifyLock(0, block.timestamp + _votingEscrow.maxTime(), users.bob);
        vm.stopPrank();

        _checkUserLockTimesAfterIncreaseUnlockTime(_aliceBalanceBeforeUnlock, _aliceBalanceBefore, _totalSupplyBeforeUnlock, _totalSupplyBefore, users.alice);
        _checkUserLockTimesAfterIncreaseUnlockTime(_bobBalanceBeforeUnlock, _bobBalanceBefore, _totalSupplyBeforeUnlock, _totalSupplyBefore, users.bob);

        // --- INCREASE AMOUNT ---

        vm.startPrank(users.alice);
        _aliceBalanceBefore = _votingEscrow.balanceOf(users.alice, block.timestamp);
        _totalSupplyBefore = _votingEscrow.totalSupply(block.timestamp);
        _votingEscrowBalanceBefore = _ampl.balanceOf(address(_votingEscrow));
        _lockedAmountBefore = _votingEscrow.lockedAmount(users.alice);
        _ampl.approve(address(_votingEscrow), _aliceAmountLocked);
        _votingEscrow.modifyLock(_aliceAmountLocked, 0, users.alice);
        vm.stopPrank();
        _checkUserBalancesAfterIncreaseAmount(users.alice, _aliceBalanceBefore, _totalSupplyBefore, _aliceAmountLocked, _votingEscrowBalanceBefore, _lockedAmountBefore);

        vm.startPrank(users.bob);
        _bobBalanceBefore = _votingEscrow.balanceOf(users.bob, block.timestamp);
        _totalSupplyBefore = _votingEscrow.totalSupply(block.timestamp);
        _votingEscrowBalanceBefore = _ampl.balanceOf(address(_votingEscrow));
        _lockedAmountBefore = _votingEscrow.lockedAmount(users.bob);
        _ampl.approve(address(_votingEscrow), _bobAmountLocked);
        _votingEscrow.modifyLock(_bobAmountLocked, 0, users.bob);
        vm.stopPrank();
        _checkUserBalancesAfterIncreaseAmount(users.bob, _bobBalanceBefore, _totalSupplyBefore, _bobAmountLocked, _votingEscrowBalanceBefore, _lockedAmountBefore);

        // --- WITHDRAW ---

        _checkWithdrawWrongFlows(users.alice);

        _totalSupplyBefore = _votingEscrow.totalSupply(block.timestamp);

        skip(_votingEscrow.maxTime()); // entire lock time

        vm.startPrank(users.alice);
        _aliceBalanceBefore = _ampl.balanceOf(users.alice);
        _votingEscrow.withdraw();
        vm.stopPrank();
        _checkUserBalancesAfterWithdraw(users.alice, _totalSupplyBefore, _aliceBalanceBefore);

        vm.startPrank(users.bob);
        _bobBalanceBefore = _ampl.balanceOf(users.bob);
        _votingEscrow.withdraw();
        vm.stopPrank();
        _checkUserBalancesAfterWithdraw(users.bob, _totalSupplyBefore, _bobBalanceBefore);
        assertEq(_ampl.balanceOf(address(_votingEscrow)), 0, "testMutated: E0");
    }

    // =======================================================
    // Internal functions
    // =======================================================

    function _checkCreateLockWrongFlows(address _user) internal {
        uint256 _puppetBalance = _ampl.balanceOf(_user);
        uint256 _maxTime = _votingEscrow.maxTime();
        require(_puppetBalance > 0, "no PUPPET balance");

        vm.expectRevert("you can only create a lock for yourself");
        _votingEscrow.modifyLock(0, block.timestamp + _maxTime, _user);

        vm.startPrank(_user);
        
        vm.expectRevert(); // ```"Arithmetic over/underflow"``` (NO ALLOWANCE)
        _votingEscrow.modifyLock(_puppetBalance, block.timestamp + _maxTime, _user);

        _ampl.approve(address(_votingEscrow), _puppetBalance);

        vm.expectRevert("unlock time must be in the future");
        _votingEscrow.modifyLock(_puppetBalance, block.timestamp - 1, _user);

        vm.expectRevert("lock can't exceed 10 years");
        _votingEscrow.modifyLock(_puppetBalance, block.timestamp + (_maxTime * 3), _user);

        _ampl.approve(address(_votingEscrow), 0);

        vm.stopPrank();
    }

    function _checkUserVotingDataAfterCreateLock(address _user, uint256 _amountLocked, uint256 _totalSupplyBefore, uint256 _votingEscrowBalanceBefore, uint256 _lockedAmountBefore) internal {
        if (_amountLocked == 0) revert("_checkUserVotingDataAfterCreateLock: E1");

        vm.startPrank(_user);

        assertTrue(_votingEscrow.getLastUserSlope(_user) == 0, "_checkUserVotingDataAfterCreateLock: E0"); // no slope, the lock is longer than the max duration
        assertApproxEqAbs(_votingEscrow.lockedEnd(_user), block.timestamp + (_votingEscrow.maxTime() * 2), 1e10, "_checkUserVotingDataAfterCreateLock: E2");
        assertApproxEqAbs(_votingEscrow.balanceOf(_user, block.timestamp), _amountLocked, 1e23, "_checkUserVotingDataAfterCreateLock: E3");
        assertApproxEqAbs(_votingEscrow.totalSupply(block.timestamp), _totalSupplyBefore + _amountLocked, 1e23, "_checkUserVotingDataAfterCreateLock: E6");
        assertApproxEqAbs(_votingEscrow.totalSupplyAt(block.number), _totalSupplyBefore + _amountLocked, 1e23, "_checkUserVotingDataAfterCreateLock: E7");
        assertEq(_votingEscrowBalanceBefore, _ampl.balanceOf(address(_votingEscrow)) - _amountLocked, "_checkUserVotingDataAfterCreateLock: E8");
        assertTrue(_ampl.balanceOf(address(_votingEscrow)) > 0, "_checkUserVotingDataAfterCreateLock: E9");
        assertEq(_votingEscrowBalanceBefore + _amountLocked, _ampl.balanceOf(address(_votingEscrow)), "_checkUserVotingDataAfterCreateLock: E10");
        assertEq(_votingEscrow.lockedAmount(_user), _lockedAmountBefore + _amountLocked, "_checkUserVotingDataAfterCreateLock: E11");
    }

    function _checkUserBalancesAfterDepositFor(address _user, address _receiver, uint256 _userBalanceBefore, uint256 _receiverBalanceBefore, uint256 _amount, uint256 _totalSupplyBefore, uint256 _votingEscrowBalanceBefore, uint256 _lockedAmountBefore) internal {
        if (_userBalanceBefore == 0) revert("_checkUserBalancesAfterDepositFor: E0");
        if (_receiverBalanceBefore == 0) revert("_checkUserBalancesAfterDepositFor: E1");
        if (_amount == 0) revert("_checkUserBalancesAfterDepositFor: E2");
        if (_totalSupplyBefore == 0) revert("_checkUserBalancesAfterDepositFor: E3");
        if (_votingEscrowBalanceBefore == 0) revert("_checkUserBalancesAfterDepositFor: E4");
        if (_lockedAmountBefore == 0) revert("_checkUserBalancesAfterDepositFor: E5");

        assertEq(_votingEscrow.balanceOf(_user, block.timestamp), _userBalanceBefore, "_checkUserBalancesAfterDepositFor: E0");
        assertApproxEqAbs(_votingEscrow.balanceOf(_receiver, block.timestamp), _receiverBalanceBefore + _amount, 1e23, "_checkUserBalancesAfterDepositFor: E1");
        assertApproxEqAbs(_votingEscrow.totalSupply(block.timestamp), _totalSupplyBefore + _amount, 1e23, "_checkUserBalancesAfterDepositFor: E6");
        assertApproxEqAbs(_votingEscrow.totalSupplyAt(block.number), _totalSupplyBefore + _amount, 1e23, "_checkUserBalancesAfterDepositFor: E7");
        assertEq(_ampl.balanceOf(address(_votingEscrow)), _votingEscrowBalanceBefore + _amount, "_checkUserBalancesAfterDepositFor: E8");
        assertEq(_votingEscrow.lockedAmount(_receiver), _lockedAmountBefore + _amount, "_checkUserBalancesAfterDepositFor: E9");
    }

    function _checkLockTimesBeforeSkip() internal {
        assertApproxEqAbs(_votingEscrow.lockedEnd(users.alice), block.timestamp + _votingEscrow.maxTime(), 1e6, "_checkLockTimesBeforeSkip: E0");
        assertApproxEqAbs(_votingEscrow.lockedEnd(users.bob), block.timestamp + _votingEscrow.maxTime(), 1e6, "_checkLockTimesBeforeSkip: E1");
    }

    function _checkLockTimesAfterSkipHalf(uint256 _aliceBalanceBefore, uint256 _bobBalanceBefore, uint256 _totalSupplyBefore) internal {
        require (_aliceBalanceBefore > 0, "no alice balance");
        require (_bobBalanceBefore > 0, "no bob balance");
        require (_totalSupplyBefore > 0, "no total supply");
        assertApproxEqAbs(_votingEscrow.balanceOf(users.alice, block.timestamp), _aliceBalanceBefore / 2, 1e21, "_checkLockTimesAfterSkipHalf: E0");
        assertApproxEqAbs(_votingEscrow.balanceOf(users.bob, block.timestamp), _bobBalanceBefore / 2, 1e21, "_checkLockTimesAfterSkipHalf: E1");
        assertEq(_votingEscrow.balanceOf(users.alice, block.timestamp - _votingEscrow.maxTime() / 2), _aliceBalanceBefore, "_checkLockTimesAfterSkipHalf: E2");
        assertEq(_votingEscrow.balanceOf(users.bob, block.timestamp - _votingEscrow.maxTime() / 2), _bobBalanceBefore, "_checkLockTimesAfterSkipHalf: E3");
        assertApproxEqAbs(_votingEscrow.totalSupply(block.timestamp), _totalSupplyBefore / 2, 1e21, "_checkLockTimesAfterSkipHalf: E4");
        assertEq(_votingEscrow.totalSupply(block.timestamp - _votingEscrow.maxTime() / 2), _totalSupplyBefore, "_checkLockTimesAfterSkipHalf: E5");
    }

    function _checkUserLockTimesAfterIncreaseUnlockTime(uint256 _userBalanceBeforeUnlock, uint256 _userBalanceBefore, uint256 _totalSupplyBeforeUnlock, uint256 _totalSupplyBefore, address _user) internal {
        if (_userBalanceBeforeUnlock == 0) revert("_checkUserLockTimesAfterIncreaseUnlockTime: E0");
        if (_userBalanceBefore == 0) revert("_checkUserLockTimesAfterIncreaseUnlockTime: E1");
        if (_totalSupplyBeforeUnlock == 0) revert("_checkUserLockTimesAfterIncreaseUnlockTime: E2");
        if (_totalSupplyBefore == 0) revert("_checkUserLockTimesAfterIncreaseUnlockTime: E3");

        assertApproxEqAbs(_votingEscrow.lockedEnd(_user), block.timestamp + _votingEscrow.maxTime(), 1e6, "_checkUserLockTimesAfterIncreaseUnlockTime: E0");
        assertApproxEqAbs(_votingEscrow.balanceOf(_user, block.timestamp), _userBalanceBeforeUnlock * 2, 1e21, "_checkUserLockTimesAfterIncreaseUnlockTime: E1");
        assertTrue(_votingEscrow.totalSupply(block.timestamp) > _totalSupplyBeforeUnlock, "_checkUserLockTimesAfterIncreaseUnlockTime: E4");
        assertApproxEqAbs(_votingEscrow.totalSupply(block.timestamp), _totalSupplyBefore, 1e21, "_checkUserLockTimesAfterIncreaseUnlockTime: E5");
        assertApproxEqAbs(_userBalanceBefore, _votingEscrow.balanceOf(_user, block.timestamp), 1e21, "_checkUserLockTimesAfterIncreaseUnlockTime: E6");
    }

    function _checkUserBalancesAfterIncreaseAmount(address _user, uint256 _balanceBefore, uint256 _totalSupplyBefore, uint256 _amountLocked, uint256 _votingEscrowBalanceBefore, uint256 _lockedAmountBefore) internal {
        if (_balanceBefore == 0) revert("_checkUserBalancesAfterIncreaseAmount: E0");
        if (_totalSupplyBefore == 0) revert("_checkUserBalancesAfterIncreaseAmount: E1");
        if (_amountLocked == 0) revert("_checkUserBalancesAfterIncreaseAmount: E2");
        if (_votingEscrowBalanceBefore == 0) revert("_checkUserBalancesAfterIncreaseAmount: E3");
        if (_lockedAmountBefore == 0) revert("_checkUserBalancesAfterIncreaseAmount: E4");

        assertApproxEqAbs(_votingEscrow.balanceOf(_user, block.timestamp), _balanceBefore + _amountLocked, 1e21, "_checkUserBalancesAfterIncreaseAmount: E0");
        assertApproxEqAbs(_votingEscrow.totalSupply(block.timestamp), _totalSupplyBefore + _amountLocked, 1e21, "_checkUserBalancesAfterIncreaseAmount: E1");
        assertEq(_ampl.balanceOf(address(_votingEscrow)), _votingEscrowBalanceBefore + _amountLocked, "_checkUserBalancesAfterIncreaseAmount: E2");
        assertEq(_votingEscrow.lockedAmount(_user), _lockedAmountBefore + _amountLocked, "_checkUserBalancesAfterIncreaseAmount: E3");
    }

    function _checkWithdrawWrongFlows(address _user) internal {
        vm.startPrank(_user);
        vm.expectRevert("lock expired"); // reverts with ```The lock didn't expire```
        _votingEscrow.withdraw();
        vm.stopPrank();
    }

    function _checkUserBalancesAfterWithdraw(address _user, uint256 _totalSupplyBefore, uint256 _puppetBalanceBefore) internal {
        assertEq(_votingEscrow.balanceOf(_user, block.timestamp), 0, "_checkUserBalancesAfterWithdraw: E0");
        assertTrue(_votingEscrow.totalSupply(block.timestamp) < _totalSupplyBefore, "_checkUserBalancesAfterWithdraw: E1");
        assertTrue(_ampl.balanceOf(_user) > _puppetBalanceBefore, "_checkUserBalancesAfterWithdraw: E2");
    }
}