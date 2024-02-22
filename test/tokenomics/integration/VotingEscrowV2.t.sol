// // SPDX-License-Identifier: AGPL-3.0-only
// pragma solidity 0.8.19;

// import "../../Base.t.sol";

// contract VotingEscrowV2Tests is Base {

//     function setUp() public override {
//         Base.setUp();

//         // mint some PUPPET to alice and bob
//         skip(86400); // skip INFLATION_DELAY (1 day)
//         _puppetERC20.updateMiningParameters(); // start 1st epoch
//         skip(86400 * 365); // skip the entire epoch (year)
//         vm.startPrank(address(_minter));
//         _puppetERC20.mint(users.alice, 100000 * 1e18);
//         _puppetERC20.mint(users.bob, 100000 * 1e18);
//         _puppetERC20.mint(users.yossi, 100000 * 1e18);
//         vm.stopPrank();
//     }

//     // ============================================================================================
//     // Test Functions
//     // ============================================================================================

//     function testParamsOnDeployment() public {
//         // sanity deploy params tests
//         assertEq(_votingEscrowV2.decimals(), 18, "testParamsOnDeployment: E0");
//         assertEq(_votingEscrowV2.name(), "Vote-escrowed PUPPET", "testParamsOnDeployment: E1");
//         assertEq(_votingEscrowV2.symbol(), "vePUPPET", "testParamsOnDeployment: E2");
//         assertEq(address(_votingEscrowV2.token()), address(_puppetERC20), "testParamsOnDeployment: E3");

//         // sanity view functions tests
//         assertEq(_votingEscrowV2.getLastUserSlope(users.alice), 0, "testParamsOnDeployment: E5");
//         assertEq(_votingEscrowV2.lockedEnd(users.alice), 0, "testParamsOnDeployment: E7");
//         assertEq(_votingEscrowV2.balanceOf(users.alice, block.timestamp), 0, "testParamsOnDeployment: E8");
//         assertEq(_votingEscrowV2.totalSupply(block.timestamp), 0, "testParamsOnDeployment: E11");
//         assertEq(_votingEscrowV2.totalSupplyAt(block.number), 0, "testParamsOnDeployment: E12");

//         _votingEscrowV2.checkpoint();

//         assertEq(_votingEscrowV2.getLastUserSlope(users.alice), 0, "testParamsOnDeployment: E13");
//         assertEq(_votingEscrowV2.lockedEnd(users.alice), 0, "testParamsOnDeployment: E15");
//         assertEq(_votingEscrowV2.balanceOf(users.alice, block.timestamp), 0, "testParamsOnDeployment: E16");
//         assertEq(_votingEscrowV2.totalSupply(block.timestamp), 0, "testParamsOnDeployment: E19");
//         assertEq(_votingEscrowV2.totalSupplyAt(block.number), 0, "testParamsOnDeployment: E20");
//     }

//     function testMutated() public {
//         uint256 _aliceAmountLocked = _puppetERC20.balanceOf(users.alice) / 3;
//         uint256 _bobAmountLocked = _puppetERC20.balanceOf(users.bob) / 3;
//         uint256 _totalSupplyBefore;
//         uint256 _votingEscrowBalanceBefore;
//         uint256 _lockedAmountBefore;

//         // --- CREATE LOCK ---

//         // alice
//         _checkCreateLockWrongFlows(users.alice);
//         vm.startPrank(users.alice);
//         _totalSupplyBefore = _votingEscrowV2.totalSupply(block.timestamp);
//         _votingEscrowBalanceBefore = _puppetERC20.balanceOf(address(_votingEscrowV2));
//         _lockedAmountBefore = _votingEscrowV2.lockedAmount(users.alice);
//         _puppetERC20.approve(address(_votingEscrowV2), _aliceAmountLocked);
//         _votingEscrowV2.modifyLock(_aliceAmountLocked, block.timestamp + _votingEscrowV2.maxTime() + _votingEscrowV2.maxTime(), users.alice);
//         vm.stopPrank();
//         _checkUserVotingDataAfterCreateLock(users.alice, _aliceAmountLocked, _totalSupplyBefore, _votingEscrowBalanceBefore, _lockedAmountBefore);

//         // bob
//         _checkCreateLockWrongFlows(users.bob);
//         vm.startPrank(users.bob);
//         _totalSupplyBefore = _votingEscrowV2.totalSupply(block.timestamp);
//         _votingEscrowBalanceBefore = _puppetERC20.balanceOf(address(_votingEscrowV2));
//         _lockedAmountBefore = _votingEscrowV2.lockedAmount(users.bob);
//         _puppetERC20.approve(address(_votingEscrowV2), _bobAmountLocked);
//         _votingEscrowV2.modifyLock(_bobAmountLocked, block.timestamp + _votingEscrowV2.maxTime() + _votingEscrowV2.maxTime(), users.bob);
//         vm.stopPrank();
//         _checkUserVotingDataAfterCreateLock(users.bob, _bobAmountLocked, _totalSupplyBefore, _votingEscrowBalanceBefore, _lockedAmountBefore);

//         // --- DEPOSIT FOR ---

//         // alice
//         vm.startPrank(users.alice);
//         _puppetERC20.approve(address(_votingEscrowV2), _bobAmountLocked);
//         vm.stopPrank();
//         vm.startPrank(users.alice);
//         _totalSupplyBefore = _votingEscrowV2.totalSupply(block.timestamp);
//         _votingEscrowBalanceBefore = _puppetERC20.balanceOf(address(_votingEscrowV2));
//         _lockedAmountBefore = _votingEscrowV2.lockedAmount(users.bob);
//         uint256 _aliceBalanceBefore = _votingEscrowV2.balanceOf(users.alice, block.timestamp);
//         uint256 _bobBalanceBefore = _votingEscrowV2.balanceOf(users.bob, block.timestamp);
//         _votingEscrowV2.modifyLock(_aliceAmountLocked, 0, users.bob);
//         vm.stopPrank();
//         _checkUserBalancesAfterDepositFor(users.alice, users.bob, _aliceBalanceBefore, _bobBalanceBefore, _aliceAmountLocked, _totalSupplyBefore, _votingEscrowBalanceBefore, _lockedAmountBefore);

//         // bob
//         vm.startPrank(users.bob);
//         _puppetERC20.approve(address(_votingEscrowV2), _aliceAmountLocked);
//         vm.stopPrank();
//         vm.startPrank(users.bob);
//         _totalSupplyBefore = _votingEscrowV2.totalSupply(block.timestamp);
//         _votingEscrowBalanceBefore = _puppetERC20.balanceOf(address(_votingEscrowV2));
//         _lockedAmountBefore = _votingEscrowV2.lockedAmount(users.alice);
//         _aliceBalanceBefore = _votingEscrowV2.balanceOf(users.alice, block.timestamp);
//         _bobBalanceBefore = _votingEscrowV2.balanceOf(users.bob, block.timestamp);
//         _votingEscrowV2.modifyLock(_bobAmountLocked, 0, users.alice);
//         vm.stopPrank();
//         _checkUserBalancesAfterDepositFor(users.bob, users.alice, _bobBalanceBefore, _aliceBalanceBefore, _bobAmountLocked, _totalSupplyBefore, _votingEscrowBalanceBefore, _lockedAmountBefore);

//         // --- DECREASE UNLOCK TIME ---

//         vm.startPrank(users.alice);
//         uint256 _aliceBalanceBeforeUnlock = _votingEscrowV2.balanceOf(users.alice, block.timestamp);
//         uint256 _totalSupplyBeforeUnlock = _votingEscrowV2.totalSupply(block.timestamp);
//         _votingEscrowV2.modifyLock(0, block.timestamp + _votingEscrowV2.maxTime() + 8 days, users.alice);
//         assertEq(_votingEscrowV2.balanceOf(users.alice, block.timestamp), _aliceBalanceBeforeUnlock, "testMutated: E0");
//         assertEq(_votingEscrowV2.totalSupply(block.timestamp), _totalSupplyBeforeUnlock, "testMutated: E1");
//         vm.stopPrank();

//         vm.startPrank(users.bob);
//         uint256 _bobBalanceBeforeUnlock = _votingEscrowV2.balanceOf(users.bob, block.timestamp);
//         _votingEscrowV2.modifyLock(0, block.timestamp + _votingEscrowV2.maxTime() + 8 days, users.bob);
//         assertEq(_votingEscrowV2.balanceOf(users.bob, block.timestamp), _bobBalanceBeforeUnlock, "testMutated: E2");
//         assertEq(_votingEscrowV2.totalSupply(block.timestamp), _totalSupplyBeforeUnlock, "testMutated: E1");
//         vm.stopPrank();

//         skip(8 days); // skip the extra 8 days


//         // --- INCREASE UNLOCK TIME ---

//         _checkLockTimesBeforeSkip();
//         _aliceBalanceBefore = _votingEscrowV2.balanceOf(users.alice, block.timestamp);
//         _bobBalanceBefore = _votingEscrowV2.balanceOf(users.bob, block.timestamp);
//         _totalSupplyBefore = _votingEscrowV2.totalSupply(block.timestamp);
//         skip(_votingEscrowV2.maxTime() / 2); // skip half of the lock time
//         _checkLockTimesAfterSkipHalf(_aliceBalanceBefore, _bobBalanceBefore, _totalSupplyBefore);

//         vm.startPrank(users.alice);
//         _aliceBalanceBeforeUnlock = _votingEscrowV2.balanceOf(users.alice, block.timestamp);
//         _totalSupplyBeforeUnlock = _votingEscrowV2.totalSupply(block.timestamp);
//         _votingEscrowV2.modifyLock(0, block.timestamp + _votingEscrowV2.maxTime(), users.alice);
//         vm.stopPrank();

//         vm.startPrank(users.bob);
//         _bobBalanceBeforeUnlock = _votingEscrowV2.balanceOf(users.bob, block.timestamp);
//         _votingEscrowV2.modifyLock(0, block.timestamp + _votingEscrowV2.maxTime(), users.bob);
//         vm.stopPrank();

//         _checkUserLockTimesAfterIncreaseUnlockTime(_aliceBalanceBeforeUnlock, _aliceBalanceBefore, _totalSupplyBeforeUnlock, _totalSupplyBefore, users.alice);
//         _checkUserLockTimesAfterIncreaseUnlockTime(_bobBalanceBeforeUnlock, _bobBalanceBefore, _totalSupplyBeforeUnlock, _totalSupplyBefore, users.bob);

//         // --- INCREASE AMOUNT ---

//         vm.startPrank(users.alice);
//         _aliceBalanceBefore = _votingEscrowV2.balanceOf(users.alice, block.timestamp);
//         _totalSupplyBefore = _votingEscrowV2.totalSupply(block.timestamp);
//         _votingEscrowBalanceBefore = _puppetERC20.balanceOf(address(_votingEscrowV2));
//         _lockedAmountBefore = _votingEscrowV2.lockedAmount(users.alice);
//         _puppetERC20.approve(address(_votingEscrowV2), _aliceAmountLocked);
//         _votingEscrowV2.modifyLock(_aliceAmountLocked, 0, users.alice);
//         vm.stopPrank();
//         _checkUserBalancesAfterIncreaseAmount(users.alice, _aliceBalanceBefore, _totalSupplyBefore, _aliceAmountLocked, _votingEscrowBalanceBefore, _lockedAmountBefore);

//         vm.startPrank(users.bob);
//         _bobBalanceBefore = _votingEscrowV2.balanceOf(users.bob, block.timestamp);
//         _totalSupplyBefore = _votingEscrowV2.totalSupply(block.timestamp);
//         _votingEscrowBalanceBefore = _puppetERC20.balanceOf(address(_votingEscrowV2));
//         _lockedAmountBefore = _votingEscrowV2.lockedAmount(users.bob);
//         _puppetERC20.approve(address(_votingEscrowV2), _bobAmountLocked);
//         _votingEscrowV2.modifyLock(_bobAmountLocked, 0, users.bob);
//         vm.stopPrank();
//         _checkUserBalancesAfterIncreaseAmount(users.bob, _bobBalanceBefore, _totalSupplyBefore, _bobAmountLocked, _votingEscrowBalanceBefore, _lockedAmountBefore);

//         // --- WITHDRAW ---

//         _checkWithdrawWrongFlows(users.alice);

//         _totalSupplyBefore = _votingEscrowV2.totalSupply(block.timestamp);

//         skip(_votingEscrowV2.maxTime()); // entire lock time

//         vm.startPrank(users.alice);
//         _aliceBalanceBefore = _puppetERC20.balanceOf(users.alice);
//         _votingEscrowV2.withdraw();
//         vm.stopPrank();
//         _checkUserBalancesAfterWithdraw(users.alice, _totalSupplyBefore, _aliceBalanceBefore);

//         vm.startPrank(users.bob);
//         _bobBalanceBefore = _puppetERC20.balanceOf(users.bob);
//         _votingEscrowV2.withdraw();
//         vm.stopPrank();
//         _checkUserBalancesAfterWithdraw(users.bob, _totalSupplyBefore, _bobBalanceBefore);
//         assertEq(_puppetERC20.balanceOf(address(_votingEscrowV2)), 0, "testMutated: E0");
//     }

//     // =======================================================
//     // Internal functions
//     // =======================================================

//     function _checkCreateLockWrongFlows(address _user) internal {
//         uint256 _puppetBalance = _puppetERC20.balanceOf(_user);
//         uint256 _maxTime = _votingEscrowV2.maxTime();
//         require(_puppetBalance > 0, "no PUPPET balance");

//         vm.expectRevert("you can only create a lock for yourself");
//         _votingEscrowV2.modifyLock(0, block.timestamp + _maxTime, _user);

//         vm.startPrank(_user);
        
//         vm.expectRevert(); // ```"Arithmetic over/underflow"``` (NO ALLOWANCE)
//         _votingEscrowV2.modifyLock(_puppetBalance, block.timestamp + _maxTime, _user);

//         _puppetERC20.approve(address(_votingEscrowV2), _puppetBalance);

//         vm.expectRevert("unlock time must be in the future");
//         _votingEscrowV2.modifyLock(_puppetBalance, block.timestamp - 1, _user);

//         vm.expectRevert("lock can't exceed 10 years");
//         _votingEscrowV2.modifyLock(_puppetBalance, block.timestamp + (_maxTime * 3), _user);

//         _puppetERC20.approve(address(_votingEscrowV2), 0);

//         vm.stopPrank();
//     }

//     function _checkUserVotingDataAfterCreateLock(address _user, uint256 _amountLocked, uint256 _totalSupplyBefore, uint256 _votingEscrowBalanceBefore, uint256 _lockedAmountBefore) internal {
//         if (_amountLocked == 0) revert("_checkUserVotingDataAfterCreateLock: E1");

//         vm.startPrank(_user);

//         assertTrue(_votingEscrowV2.getLastUserSlope(_user) == 0, "_checkUserVotingDataAfterCreateLock: E0"); // no slope, the lock is longer than the max duration
//         assertApproxEqAbs(_votingEscrowV2.lockedEnd(_user), block.timestamp + (_votingEscrowV2.maxTime() * 2), 1e10, "_checkUserVotingDataAfterCreateLock: E2");
//         assertApproxEqAbs(_votingEscrowV2.balanceOf(_user, block.timestamp), _amountLocked, 1e23, "_checkUserVotingDataAfterCreateLock: E3");
//         assertApproxEqAbs(_votingEscrowV2.totalSupply(block.timestamp), _totalSupplyBefore + _amountLocked, 1e23, "_checkUserVotingDataAfterCreateLock: E6");
//         assertApproxEqAbs(_votingEscrowV2.totalSupplyAt(block.number), _totalSupplyBefore + _amountLocked, 1e23, "_checkUserVotingDataAfterCreateLock: E7");
//         assertEq(_votingEscrowBalanceBefore, _puppetERC20.balanceOf(address(_votingEscrowV2)) - _amountLocked, "_checkUserVotingDataAfterCreateLock: E8");
//         assertTrue(_puppetERC20.balanceOf(address(_votingEscrowV2)) > 0, "_checkUserVotingDataAfterCreateLock: E9");
//         assertEq(_votingEscrowBalanceBefore + _amountLocked, _puppetERC20.balanceOf(address(_votingEscrowV2)), "_checkUserVotingDataAfterCreateLock: E10");
//         assertEq(_votingEscrowV2.lockedAmount(_user), _lockedAmountBefore + _amountLocked, "_checkUserVotingDataAfterCreateLock: E11");
//     }

//     function _checkUserBalancesAfterDepositFor(address _user, address _receiver, uint256 _userBalanceBefore, uint256 _receiverBalanceBefore, uint256 _amount, uint256 _totalSupplyBefore, uint256 _votingEscrowBalanceBefore, uint256 _lockedAmountBefore) internal {
//         if (_userBalanceBefore == 0) revert("_checkUserBalancesAfterDepositFor: E0");
//         if (_receiverBalanceBefore == 0) revert("_checkUserBalancesAfterDepositFor: E1");
//         if (_amount == 0) revert("_checkUserBalancesAfterDepositFor: E2");
//         if (_totalSupplyBefore == 0) revert("_checkUserBalancesAfterDepositFor: E3");
//         if (_votingEscrowBalanceBefore == 0) revert("_checkUserBalancesAfterDepositFor: E4");
//         if (_lockedAmountBefore == 0) revert("_checkUserBalancesAfterDepositFor: E5");

//         assertEq(_votingEscrowV2.balanceOf(_user, block.timestamp), _userBalanceBefore, "_checkUserBalancesAfterDepositFor: E0");
//         assertApproxEqAbs(_votingEscrowV2.balanceOf(_receiver, block.timestamp), _receiverBalanceBefore + _amount, 1e23, "_checkUserBalancesAfterDepositFor: E1");
//         assertApproxEqAbs(_votingEscrowV2.totalSupply(block.timestamp), _totalSupplyBefore + _amount, 1e23, "_checkUserBalancesAfterDepositFor: E6");
//         assertApproxEqAbs(_votingEscrowV2.totalSupplyAt(block.number), _totalSupplyBefore + _amount, 1e23, "_checkUserBalancesAfterDepositFor: E7");
//         assertEq(_puppetERC20.balanceOf(address(_votingEscrowV2)), _votingEscrowBalanceBefore + _amount, "_checkUserBalancesAfterDepositFor: E8");
//         assertEq(_votingEscrowV2.lockedAmount(_receiver), _lockedAmountBefore + _amount, "_checkUserBalancesAfterDepositFor: E9");
//     }

//     function _checkLockTimesBeforeSkip() internal {
//         assertApproxEqAbs(_votingEscrowV2.lockedEnd(users.alice), block.timestamp + _votingEscrowV2.maxTime(), 1e6, "_checkLockTimesBeforeSkip: E0");
//         assertApproxEqAbs(_votingEscrowV2.lockedEnd(users.bob), block.timestamp + _votingEscrowV2.maxTime(), 1e6, "_checkLockTimesBeforeSkip: E1");
//     }

//     function _checkLockTimesAfterSkipHalf(uint256 _aliceBalanceBefore, uint256 _bobBalanceBefore, uint256 _totalSupplyBefore) internal {
//         require (_aliceBalanceBefore > 0, "no alice balance");
//         require (_bobBalanceBefore > 0, "no bob balance");
//         require (_totalSupplyBefore > 0, "no total supply");
//         assertApproxEqAbs(_votingEscrowV2.balanceOf(users.alice, block.timestamp), _aliceBalanceBefore / 2, 1e21, "_checkLockTimesAfterSkipHalf: E0");
//         assertApproxEqAbs(_votingEscrowV2.balanceOf(users.bob, block.timestamp), _bobBalanceBefore / 2, 1e21, "_checkLockTimesAfterSkipHalf: E1");
//         assertEq(_votingEscrowV2.balanceOf(users.alice, block.timestamp - _votingEscrowV2.maxTime() / 2), _aliceBalanceBefore, "_checkLockTimesAfterSkipHalf: E2");
//         assertEq(_votingEscrowV2.balanceOf(users.bob, block.timestamp - _votingEscrowV2.maxTime() / 2), _bobBalanceBefore, "_checkLockTimesAfterSkipHalf: E3");
//         assertApproxEqAbs(_votingEscrowV2.totalSupply(block.timestamp), _totalSupplyBefore / 2, 1e21, "_checkLockTimesAfterSkipHalf: E4");
//         assertEq(_votingEscrowV2.totalSupply(block.timestamp - _votingEscrowV2.maxTime() / 2), _totalSupplyBefore, "_checkLockTimesAfterSkipHalf: E5");
//     }

//     function _checkUserLockTimesAfterIncreaseUnlockTime(uint256 _userBalanceBeforeUnlock, uint256 _userBalanceBefore, uint256 _totalSupplyBeforeUnlock, uint256 _totalSupplyBefore, address _user) internal {
//         if (_userBalanceBeforeUnlock == 0) revert("_checkUserLockTimesAfterIncreaseUnlockTime: E0");
//         if (_userBalanceBefore == 0) revert("_checkUserLockTimesAfterIncreaseUnlockTime: E1");
//         if (_totalSupplyBeforeUnlock == 0) revert("_checkUserLockTimesAfterIncreaseUnlockTime: E2");
//         if (_totalSupplyBefore == 0) revert("_checkUserLockTimesAfterIncreaseUnlockTime: E3");

//         assertApproxEqAbs(_votingEscrowV2.lockedEnd(_user), block.timestamp + _votingEscrowV2.maxTime(), 1e6, "_checkUserLockTimesAfterIncreaseUnlockTime: E0");
//         assertApproxEqAbs(_votingEscrowV2.balanceOf(_user, block.timestamp), _userBalanceBeforeUnlock * 2, 1e21, "_checkUserLockTimesAfterIncreaseUnlockTime: E1");
//         assertTrue(_votingEscrowV2.totalSupply(block.timestamp) > _totalSupplyBeforeUnlock, "_checkUserLockTimesAfterIncreaseUnlockTime: E4");
//         assertApproxEqAbs(_votingEscrowV2.totalSupply(block.timestamp), _totalSupplyBefore, 1e21, "_checkUserLockTimesAfterIncreaseUnlockTime: E5");
//         assertApproxEqAbs(_userBalanceBefore, _votingEscrowV2.balanceOf(_user, block.timestamp), 1e21, "_checkUserLockTimesAfterIncreaseUnlockTime: E6");
//     }

//     function _checkUserBalancesAfterIncreaseAmount(address _user, uint256 _balanceBefore, uint256 _totalSupplyBefore, uint256 _amountLocked, uint256 _votingEscrowBalanceBefore, uint256 _lockedAmountBefore) internal {
//         if (_balanceBefore == 0) revert("_checkUserBalancesAfterIncreaseAmount: E0");
//         if (_totalSupplyBefore == 0) revert("_checkUserBalancesAfterIncreaseAmount: E1");
//         if (_amountLocked == 0) revert("_checkUserBalancesAfterIncreaseAmount: E2");
//         if (_votingEscrowBalanceBefore == 0) revert("_checkUserBalancesAfterIncreaseAmount: E3");
//         if (_lockedAmountBefore == 0) revert("_checkUserBalancesAfterIncreaseAmount: E4");

//         assertApproxEqAbs(_votingEscrowV2.balanceOf(_user, block.timestamp), _balanceBefore + _amountLocked, 1e21, "_checkUserBalancesAfterIncreaseAmount: E0");
//         assertApproxEqAbs(_votingEscrowV2.totalSupply(block.timestamp), _totalSupplyBefore + _amountLocked, 1e21, "_checkUserBalancesAfterIncreaseAmount: E1");
//         assertEq(_puppetERC20.balanceOf(address(_votingEscrowV2)), _votingEscrowBalanceBefore + _amountLocked, "_checkUserBalancesAfterIncreaseAmount: E2");
//         assertEq(_votingEscrowV2.lockedAmount(_user), _lockedAmountBefore + _amountLocked, "_checkUserBalancesAfterIncreaseAmount: E3");
//     }

//     function _checkWithdrawWrongFlows(address _user) internal {
//         vm.startPrank(_user);
//         vm.expectRevert("lock expired"); // reverts with ```The lock didn't expire```
//         _votingEscrowV2.withdraw();
//         vm.stopPrank();
//     }

//     function _checkUserBalancesAfterWithdraw(address _user, uint256 _totalSupplyBefore, uint256 _puppetBalanceBefore) internal {
//         assertEq(_votingEscrowV2.balanceOf(_user, block.timestamp), 0, "_checkUserBalancesAfterWithdraw: E0");
//         assertTrue(_votingEscrowV2.totalSupply(block.timestamp) < _totalSupplyBefore, "_checkUserBalancesAfterWithdraw: E1");
//         assertTrue(_puppetERC20.balanceOf(_user) > _puppetBalanceBefore, "_checkUserBalancesAfterWithdraw: E2");
//     }
// }