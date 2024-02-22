// // SPDX-License-Identifier: AGPL-3.0-only
// pragma solidity 0.8.19;

// import {ICRVVotingEscrow} from "../../interfaces/ICRVVotingEscrow.sol";
// import {ISmartWalletWhitelist} from "../../interfaces/ISmartWalletWhitelist.sol";

// import "../../Base.t.sol";

// contract VotingEscrowTests is Base {

//     ICRVVotingEscrow internal _crvVotingEscrow = ICRVVotingEscrow(0x5f3b5DfEb7B28CDbD7FAba78963EE202a494e2A2);

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

//         // whitelist alice and bob as contracts, because of Foundry limitation (msg.sender != tx.origin)
//         vm.startPrank(users.owner);
//         bytes4 addToWhitelistSig = _votingEscrow.addToWhitelist.selector;
//         _setRoleCapability(_dictator, 0, address(_votingEscrow), addToWhitelistSig, true);
//         _setUserRole(_dictator, users.owner, 0, true);

//         _votingEscrow.addToWhitelist(users.alice);
//         _votingEscrow.addToWhitelist(users.bob);
//         _votingEscrow.addToWhitelist(users.yossi);
//         vm.stopPrank();
//     }

//     // ============================================================================================
//     // Test Functions
//     // ============================================================================================

//     function testParamsOnDeployment() public {
//         // sanity deploy params tests
//         assertEq(_votingEscrow.decimals(), 18, "testParamsOnDeployment: E0");
//         assertEq(_votingEscrow.name(), "Vote-escrowed PUPPET", "testParamsOnDeployment: E1");
//         assertEq(_votingEscrow.symbol(), "vePUPPET", "testParamsOnDeployment: E2");
//         assertEq(_votingEscrow.version(), "1.0.0", "testParamsOnDeployment: E3");
//         assertEq(_votingEscrow.token(), address(_puppetERC20), "testParamsOnDeployment: E4");

//         // sanity view functions tests
//         assertEq(_votingEscrow.getLastUserSlope(users.alice), 0, "testParamsOnDeployment: E5");
//         assertEq(_votingEscrow.userPointHistoryTs(users.alice, 0), 0, "testParamsOnDeployment: E6");
//         assertEq(_votingEscrow.lockedEnd(users.alice), 0, "testParamsOnDeployment: E7");
//         assertEq(_votingEscrow.balanceOf(users.alice), 0, "testParamsOnDeployment: E8");
//         assertEq(_votingEscrow.balanceOfAtT(users.alice, block.timestamp), 0, "testParamsOnDeployment: E9");
//         assertEq(_votingEscrow.balanceOfAt(users.alice, block.number), 0, "testParamsOnDeployment: E10");
//         assertEq(_votingEscrow.totalSupply(), 0, "testParamsOnDeployment: E11");
//         assertEq(_votingEscrow.totalSupplyAt(block.number), 0, "testParamsOnDeployment: E12");

//         _votingEscrow.checkpoint();

//         assertEq(_votingEscrow.getLastUserSlope(users.alice), 0, "testParamsOnDeployment: E13");
//         assertEq(_votingEscrow.userPointHistoryTs(users.alice, 0), 0, "testParamsOnDeployment: E14");
//         assertEq(_votingEscrow.lockedEnd(users.alice), 0, "testParamsOnDeployment: E15");
//         assertEq(_votingEscrow.balanceOf(users.alice), 0, "testParamsOnDeployment: E16");
//         assertEq(_votingEscrow.balanceOfAtT(users.alice, block.timestamp), 0, "testParamsOnDeployment: E17");
//         assertEq(_votingEscrow.balanceOfAt(users.alice, block.number), 0, "testParamsOnDeployment: E18");
//         assertEq(_votingEscrow.totalSupply(), 0, "testParamsOnDeployment: E19");
//         assertEq(_votingEscrow.totalSupplyAt(block.number), 0, "testParamsOnDeployment: E20");
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
//         _totalSupplyBefore = _votingEscrow.totalSupply();
//         _votingEscrowBalanceBefore = _puppetERC20.balanceOf(address(_votingEscrow));
//         _lockedAmountBefore = _votingEscrow.lockedAmount(users.alice);
//         _puppetERC20.approve(address(_votingEscrow), _aliceAmountLocked);
//         _votingEscrow.createLock(users.alice, _aliceAmountLocked, block.timestamp + _votingEscrow.MAXTIME());
//         vm.stopPrank();
//         _checkUserVotingDataAfterCreateLock(users.alice, _aliceAmountLocked, _totalSupplyBefore, _votingEscrowBalanceBefore, _lockedAmountBefore);

//         // bob
//         _checkCreateLockWrongFlows(users.bob);
//         vm.startPrank(users.bob);
//         _totalSupplyBefore = _votingEscrow.totalSupply();
//         _votingEscrowBalanceBefore = _puppetERC20.balanceOf(address(_votingEscrow));
//         _lockedAmountBefore = _votingEscrow.lockedAmount(users.bob);
//         _puppetERC20.approve(address(_votingEscrow), _bobAmountLocked);
//         _votingEscrow.createLock(users.bob, _bobAmountLocked, block.timestamp + _votingEscrow.MAXTIME());
//         vm.stopPrank();
//         _checkUserVotingDataAfterCreateLock(users.bob, _bobAmountLocked, _totalSupplyBefore, _votingEscrowBalanceBefore, _lockedAmountBefore);

//         // --- DEPOSIT FOR ---

//         // alice
//         _checkDepositForWrongFlows(_aliceAmountLocked, users.alice, users.bob);
//         vm.startPrank(users.alice);
//         _puppetERC20.approve(address(_votingEscrow), _bobAmountLocked);
//         vm.stopPrank();
//         vm.startPrank(users.alice);
//         _totalSupplyBefore = _votingEscrow.totalSupply();
//         _votingEscrowBalanceBefore = _puppetERC20.balanceOf(address(_votingEscrow));
//         _lockedAmountBefore = _votingEscrow.lockedAmount(users.bob);
//         uint256 _aliceBalanceBefore = _votingEscrow.balanceOf(users.alice);
//         uint256 _bobBalanceBefore = _votingEscrow.balanceOf(users.bob);
//         _votingEscrow.depositFor(users.bob, _aliceAmountLocked);
//         vm.stopPrank();
//         _checkUserBalancesAfterDepositFor(users.alice, users.bob, _aliceBalanceBefore, _bobBalanceBefore, _aliceAmountLocked, _totalSupplyBefore, _votingEscrowBalanceBefore, _lockedAmountBefore);

//         // bob
//         _checkDepositForWrongFlows(_bobAmountLocked, users.bob, users.alice);
//         vm.startPrank(users.bob);
//         _puppetERC20.approve(address(_votingEscrow), _aliceAmountLocked);
//         vm.stopPrank();
//         vm.startPrank(users.bob);
//         _totalSupplyBefore = _votingEscrow.totalSupply();
//         _votingEscrowBalanceBefore = _puppetERC20.balanceOf(address(_votingEscrow));
//         _lockedAmountBefore = _votingEscrow.lockedAmount(users.alice);
//         _aliceBalanceBefore = _votingEscrow.balanceOf(users.alice);
//         _bobBalanceBefore = _votingEscrow.balanceOf(users.bob);
//         _votingEscrow.depositFor(users.alice, _bobAmountLocked);
//         vm.stopPrank();
//         _checkUserBalancesAfterDepositFor(users.bob, users.alice, _bobBalanceBefore, _aliceBalanceBefore, _bobAmountLocked, _totalSupplyBefore, _votingEscrowBalanceBefore, _lockedAmountBefore);

//         // --- INCREASE UNLOCK TIME ---

//         _checkLockTimesBeforeSkip();
//         _aliceBalanceBefore = _votingEscrow.balanceOf(users.alice);
//         _bobBalanceBefore = _votingEscrow.balanceOf(users.bob);
//         _totalSupplyBefore = _votingEscrow.totalSupply();
//         skip(_votingEscrow.MAXTIME() / 2); // skip half of the lock time
//         _checkLockTimesAfterSkipHalf(_aliceBalanceBefore, _bobBalanceBefore, _totalSupplyBefore);

//         _checkIncreaseUnlockTimeWrongFlows(users.alice);
//         vm.startPrank(users.alice);
//         uint256 _aliceBalanceBeforeUnlock = _votingEscrow.balanceOf(users.alice);
//         uint256 _totalSupplyBeforeUnlock = _votingEscrow.totalSupply();
//         _votingEscrow.increaseUnlockTime(block.timestamp + _votingEscrow.MAXTIME());
//         vm.stopPrank();

//         vm.startPrank(users.bob);
//         uint256 _bobBalanceBeforeUnlock = _votingEscrow.balanceOf(users.bob);
//         _votingEscrow.increaseUnlockTime(block.timestamp + _votingEscrow.MAXTIME());
//         vm.stopPrank();

//         _checkUserLockTimesAfterIncreaseUnlockTime(_aliceBalanceBeforeUnlock, _aliceBalanceBefore, _totalSupplyBeforeUnlock, _totalSupplyBefore, users.alice);
//         _checkUserLockTimesAfterIncreaseUnlockTime(_bobBalanceBeforeUnlock, _bobBalanceBefore, _totalSupplyBeforeUnlock, _totalSupplyBefore, users.bob);

//         // --- INCREASE AMOUNT ---

//         _checkIncreaseAmountWrongFlows(users.alice);
//         vm.startPrank(users.alice);
//         _aliceBalanceBefore = _votingEscrow.balanceOf(users.alice);
//         _totalSupplyBefore = _votingEscrow.totalSupply();
//         _votingEscrowBalanceBefore = _puppetERC20.balanceOf(address(_votingEscrow));
//         _lockedAmountBefore = _votingEscrow.lockedAmount(users.alice);
//         _puppetERC20.approve(address(_votingEscrow), _aliceAmountLocked);
//         _votingEscrow.increaseAmount(_aliceAmountLocked);
//         vm.stopPrank();
//         _checkUserBalancesAfterIncreaseAmount(users.alice, _aliceBalanceBefore, _totalSupplyBefore, _aliceAmountLocked, _votingEscrowBalanceBefore, _lockedAmountBefore);

//         _checkIncreaseAmountWrongFlows(users.bob);
//         vm.startPrank(users.bob);
//         _bobBalanceBefore = _votingEscrow.balanceOf(users.bob);
//         _totalSupplyBefore = _votingEscrow.totalSupply();
//         _votingEscrowBalanceBefore = _puppetERC20.balanceOf(address(_votingEscrow));
//         _lockedAmountBefore = _votingEscrow.lockedAmount(users.bob);
//         _puppetERC20.approve(address(_votingEscrow), _bobAmountLocked);
//         _votingEscrow.increaseAmount(_bobAmountLocked);
//         vm.stopPrank();
//         _checkUserBalancesAfterIncreaseAmount(users.bob, _bobBalanceBefore, _totalSupplyBefore, _bobAmountLocked, _votingEscrowBalanceBefore, _lockedAmountBefore);

//         // --- WITHDRAW ---

//         _checkWithdrawWrongFlows(users.alice);

//         _totalSupplyBefore = _votingEscrow.totalSupply();

//         skip(_votingEscrow.MAXTIME()); // entire lock time

//         vm.startPrank(users.alice);
//         _aliceBalanceBefore = _puppetERC20.balanceOf(users.alice);
//         _votingEscrow.withdraw();
//         vm.stopPrank();
//         _checkUserBalancesAfterWithdraw(users.alice, _totalSupplyBefore, _aliceBalanceBefore);

//         vm.startPrank(users.bob);
//         _bobBalanceBefore = _puppetERC20.balanceOf(users.bob);
//         _votingEscrow.withdraw();
//         vm.stopPrank();
//         _checkUserBalancesAfterWithdraw(users.bob, _totalSupplyBefore, _bobBalanceBefore);
//         assertEq(_puppetERC20.balanceOf(address(_votingEscrow)), 0, "testMutated: E0");
//     }

//     function _testMutatedOnCRV() internal {
//         address _crv = 0xD533a949740bb3306d119CC777fa900bA034cd52;
//         _dealERC20(_crv, users.alice , 100000 * 1e18);
//         _dealERC20(_crv, users.bob , 100000 * 1e18);

//         // approve alice
//         vm.startPrank(address(0x40907540d8a6C65c637785e8f8B742ae6b0b9968)); // dao address
//         ISmartWalletWhitelist(address(0xca719728Ef172d0961768581fdF35CB116e0B7a4)).approveWallet(users.alice);
//         ISmartWalletWhitelist(address(0xca719728Ef172d0961768581fdF35CB116e0B7a4)).approveWallet(users.bob);
//         vm.stopPrank();

//         // ======= CREATE LOCK =======

//         vm.startPrank(users.alice);
//         uint256 _aliceAmountLocked = IERC20(_crv).balanceOf(users.alice) / 3;
//         IERC20(_crv).approve(address(_crvVotingEscrow), _aliceAmountLocked);
//         _crvVotingEscrow.create_lock(_aliceAmountLocked, block.timestamp + (4 * 365 * 86400));
//         vm.stopPrank();

//         vm.startPrank(users.bob);
//         uint256 _bobAmountLocked = IERC20(_crv).balanceOf(users.bob) / 3;
//         IERC20(_crv).approve(address(_crvVotingEscrow), _bobAmountLocked);
//         _crvVotingEscrow.create_lock(_bobAmountLocked, block.timestamp + (4 * 365 * 86400));
//         vm.stopPrank();

//         // ======= DEPOSIT FOR =======

//         vm.startPrank(users.bob);
//         IERC20(_crv).approve(address(_crvVotingEscrow), _bobAmountLocked);
//         vm.stopPrank();
//         vm.startPrank(users.alice);
//         _crvVotingEscrow.deposit_for(users.bob, _aliceAmountLocked);
//         vm.stopPrank();

//         vm.startPrank(users.alice);
//         IERC20(_crv).approve(address(_crvVotingEscrow), _bobAmountLocked);
//         vm.stopPrank();
//         vm.startPrank(users.bob);
//         _crvVotingEscrow.deposit_for(users.alice, _bobAmountLocked);
//         vm.stopPrank();

//         // --- INCREASE UNLOCK TIME ---

//         skip((4 * 365 * 86400) / 2); // skip half of the lock time

//         vm.startPrank(users.alice);
//         _crvVotingEscrow.increase_unlock_time(block.timestamp + (4 * 365 * 86400));
//         vm.stopPrank();
//     }

//     // =======================================================
//     // Internal functions
//     // =======================================================

//     function _checkCreateLockWrongFlows(address _user) internal {
//         uint256 _puppetBalance = _puppetERC20.balanceOf(_user);
//         uint256 _maxTime = _votingEscrow.MAXTIME();
//         require(_puppetBalance > 0, "no PUPPET balance");

//         vm.startPrank(_user);
        
//         vm.expectRevert(); // ```"Arithmetic over/underflow"``` (NO ALLOWANCE)
//         _votingEscrow.createLock(_user, _puppetBalance, block.timestamp + _maxTime);

//         _puppetERC20.approve(address(_votingEscrow), _puppetBalance);

//         vm.expectRevert(bytes4(keccak256("ZeroValue()")));
//         _votingEscrow.createLock(_user, 0, block.timestamp + _maxTime);

//         vm.expectRevert(bytes4(keccak256("LockTimeInThePast()")));
//         _votingEscrow.createLock(_user, _puppetBalance, block.timestamp - 1);

//         vm.expectRevert(bytes4(keccak256("LockTimeTooLong()")));
//         _votingEscrow.createLock(_user, _puppetBalance, block.timestamp + _maxTime + _maxTime);

//         _puppetERC20.approve(address(_votingEscrow), 0);

//         vm.stopPrank();
//     }

//     function _checkUserVotingDataAfterCreateLock(address _user, uint256 _amountLocked, uint256 _totalSupplyBefore, uint256 _votingEscrowBalanceBefore, uint256 _lockedAmountBefore) internal {
//         vm.startPrank(_user);

//         uint256 _puppetBalance = _puppetERC20.balanceOf(_user);
//         uint256 _maxTime = _votingEscrow.MAXTIME();
//         _puppetERC20.approve(address(_votingEscrow), _puppetBalance);
//         vm.expectRevert(bytes4(keccak256("WithdrawOldTokensFirst()")));
//         _votingEscrow.createLock(_user, _puppetBalance, block.timestamp + _maxTime);
//         _puppetERC20.approve(address(_votingEscrow), 0);

//         assertTrue(_votingEscrow.getLastUserSlope(_user) != 0, "_checkUserVotingDataAfterCreateLock: E0");
//         assertTrue(_votingEscrow.userPointHistoryTs(_user, 1) != 0, "_checkUserVotingDataAfterCreateLock: E1");
//         assertApproxEqAbs(_votingEscrow.lockedEnd(_user), block.timestamp + _votingEscrow.MAXTIME(), 1e10, "_checkUserVotingDataAfterCreateLock: E2");
//         assertApproxEqAbs(_votingEscrow.balanceOf(_user), _amountLocked, 1e23, "_checkUserVotingDataAfterCreateLock: E3");
//         assertApproxEqAbs(_votingEscrow.balanceOfAtT(_user, block.timestamp), _amountLocked, 1e23, "_checkUserVotingDataAfterCreateLock: E4");
//         assertApproxEqAbs(_votingEscrow.balanceOfAt(_user, block.number), _amountLocked, 1e23, "_checkUserVotingDataAfterCreateLock: E5");
//         assertApproxEqAbs(_votingEscrow.totalSupply(), _totalSupplyBefore + _amountLocked, 1e23, "_checkUserVotingDataAfterCreateLock: E6");
//         assertApproxEqAbs(_votingEscrow.totalSupplyAt(block.number), _totalSupplyBefore + _amountLocked, 1e23, "_checkUserVotingDataAfterCreateLock: E7");
//         assertEq(_votingEscrowBalanceBefore, _puppetERC20.balanceOf(address(_votingEscrow)) - _amountLocked, "_checkUserVotingDataAfterCreateLock: E8");
//         assertTrue(_puppetERC20.balanceOf(address(_votingEscrow)) > 0, "_checkUserVotingDataAfterCreateLock: E9");
//         assertEq(_votingEscrowBalanceBefore + _amountLocked, _puppetERC20.balanceOf(address(_votingEscrow)), "_checkUserVotingDataAfterCreateLock: E10");
//         assertEq(_votingEscrow.lockedAmount(_user), _lockedAmountBefore + _amountLocked, "_checkUserVotingDataAfterCreateLock: E11");
//     }

//     function _checkDepositForWrongFlows(uint256 _amount, address _user, address _receiver) internal {
//         vm.startPrank(_user);

//         vm.expectRevert(bytes4(keccak256("ZeroValue()")));
//         _votingEscrow.depositFor(_receiver, 0);

//         vm.expectRevert(bytes4(keccak256("NoLockFound()")));
//         _votingEscrow.depositFor(users.yossi, _amount);

//         vm.expectRevert(); // ```"Arithmetic over/underflow"``` (NO ALLOWANCE)
//         _votingEscrow.depositFor(_receiver, _amount);

//         vm.stopPrank();
//     }

//     function _checkUserBalancesAfterDepositFor(address _user, address _receiver, uint256 _userBalanceBefore, uint256 _receiverBalanceBefore, uint256 _amount, uint256 _totalSupplyBefore, uint256 _votingEscrowBalanceBefore, uint256 _lockedAmountBefore) internal {
//         assertEq(_votingEscrow.balanceOf(_user), _userBalanceBefore, "_checkUserBalancesAfterDepositFor: E0");
//         assertApproxEqAbs(_votingEscrow.balanceOf(_receiver), _receiverBalanceBefore + _amount, 1e23, "_checkUserBalancesAfterDepositFor: E1");
//         assertEq(_votingEscrow.balanceOfAtT(_user, block.timestamp), _userBalanceBefore, "_checkUserBalancesAfterDepositFor: E2");
//         assertApproxEqAbs(_votingEscrow.balanceOfAtT(_receiver, block.timestamp), _receiverBalanceBefore + _amount, 1e23, "_checkUserBalancesAfterDepositFor: E3");
//         assertEq(_votingEscrow.balanceOfAt(_user, block.number), _userBalanceBefore, "_checkUserBalancesAfterDepositFor: E4");
//         assertApproxEqAbs(_votingEscrow.balanceOfAt(_receiver, block.number), _receiverBalanceBefore + _amount, 1e23, "_checkUserBalancesAfterDepositFor: E5");
//         assertApproxEqAbs(_votingEscrow.totalSupply(), _totalSupplyBefore + _amount, 1e23, "_checkUserBalancesAfterDepositFor: E6");
//         assertApproxEqAbs(_votingEscrow.totalSupplyAt(block.number), _totalSupplyBefore + _amount, 1e23, "_checkUserBalancesAfterDepositFor: E7");
//         assertEq(_puppetERC20.balanceOf(address(_votingEscrow)), _votingEscrowBalanceBefore + _amount, "_checkUserBalancesAfterDepositFor: E8");
//         assertEq(_votingEscrow.lockedAmount(_receiver), _lockedAmountBefore + _amount, "_checkUserBalancesAfterDepositFor: E9");
//     }

//     function _checkLockTimesBeforeSkip() internal {
//         assertApproxEqAbs(_votingEscrow.lockedEnd(users.alice), block.timestamp + _votingEscrow.MAXTIME(), 1e6, "_checkLockTimesBeforeSkip: E0");
//         assertApproxEqAbs(_votingEscrow.lockedEnd(users.bob), block.timestamp + _votingEscrow.MAXTIME(), 1e6, "_checkLockTimesBeforeSkip: E1");
//     }

//     function _checkLockTimesAfterSkipHalf(uint256 _aliceBalanceBefore, uint256 _bobBalanceBefore, uint256 _totalSupplyBefore) internal {
//         assertApproxEqAbs(_votingEscrow.balanceOf(users.alice), _aliceBalanceBefore / 2, 1e21, "_checkLockTimesAfterSkipHalf: E0");
//         assertApproxEqAbs(_votingEscrow.balanceOf(users.bob), _bobBalanceBefore / 2, 1e21, "_checkLockTimesAfterSkipHalf: E1");
//         assertEq(_votingEscrow.balanceOfAtT(users.alice, block.timestamp - _votingEscrow.MAXTIME() / 2), _aliceBalanceBefore, "_checkLockTimesAfterSkipHalf: E2");
//         assertEq(_votingEscrow.balanceOfAtT(users.bob, block.timestamp - _votingEscrow.MAXTIME() / 2), _bobBalanceBefore, "_checkLockTimesAfterSkipHalf: E3");
//         assertApproxEqAbs(_votingEscrow.totalSupply(), _totalSupplyBefore / 2, 1e21, "_checkLockTimesAfterSkipHalf: E4");
//         assertEq(_votingEscrow.totalSupplyAtT(block.timestamp - _votingEscrow.MAXTIME() / 2), _totalSupplyBefore, "_checkLockTimesAfterSkipHalf: E5");
//     }

//     function _checkIncreaseUnlockTimeWrongFlows(address _user) internal {
//         uint256 _maxTime = _votingEscrow.MAXTIME();
//         // uint256 _userLockEnd = _votingEscrow.lockedEnd(_user);

//         vm.startPrank(users.yossi);
//         vm.expectRevert(bytes4(keccak256("NoLockFound()")));
//         _votingEscrow.increaseUnlockTime(block.timestamp + _maxTime);
//         vm.stopPrank();

//         // vm.startPrank(_user);
//         // // vm.expectRevert(bytes4(keccak256("LockTimeInThePast()")));
//         // _votingEscrow.increaseUnlockTime(_userLockEnd);
//         // vm.stopPrank();

//         vm.startPrank(_user);
//         vm.expectRevert(bytes4(keccak256("LockTimeTooLong()")));
//         _votingEscrow.increaseUnlockTime(block.timestamp + _maxTime + _maxTime);
//         vm.stopPrank();
//     }

//     function _checkUserLockTimesAfterIncreaseUnlockTime(uint256 _userBalanceBeforeUnlock, uint256 _userBalanceBefore, uint256 _totalSupplyBeforeUnlock, uint256 _totalSupplyBefore, address _user) internal {
//         assertApproxEqAbs(_votingEscrow.lockedEnd(_user), block.timestamp + _votingEscrow.MAXTIME(), 1e6, "_checkUserLockTimesAfterIncreaseUnlockTime: E0");
//         assertApproxEqAbs(_votingEscrow.balanceOf(_user), _userBalanceBeforeUnlock * 2, 1e21, "_checkUserLockTimesAfterIncreaseUnlockTime: E1");
//         assertApproxEqAbs(_votingEscrow.balanceOfAtT(_user, block.timestamp), _userBalanceBeforeUnlock * 2, 1e21, "_checkUserLockTimesAfterIncreaseUnlockTime: E2");
//         // assertEq(_votingEscrow.balanceOfAtT(_user, block.timestamp - _votingEscrow.MAXTIME() / 2), _votingEscrow.balanceOf(_user), "_checkUserLockTimesAfterIncreaseUnlockTime: E3");
//         assertTrue(_votingEscrow.totalSupply() > _totalSupplyBeforeUnlock, "_checkUserLockTimesAfterIncreaseUnlockTime: E4");
//         assertApproxEqAbs(_votingEscrow.totalSupply(), _totalSupplyBefore, 1e21, "_checkUserLockTimesAfterIncreaseUnlockTime: E5");
//         assertApproxEqAbs(_userBalanceBefore, _votingEscrow.balanceOf(_user), 1e21, "_checkUserLockTimesAfterIncreaseUnlockTime: E6");
//     }

//     function _checkIncreaseAmountWrongFlows(address _user) internal {
//         vm.startPrank(_user);
//         vm.expectRevert();
//         _votingEscrow.increaseAmount(0);
//         vm.stopPrank();
//     }

//     function _checkUserBalancesAfterIncreaseAmount(address _user, uint256 _balanceBefore, uint256 _totalSupplyBefore, uint256 _amountLocked, uint256 _votingEscrowBalanceBefore, uint256 _lockedAmountBefore) internal {
//         assertApproxEqAbs(_votingEscrow.balanceOf(_user), _balanceBefore + _amountLocked, 1e21, "_checkUserBalancesAfterIncreaseAmount: E0");
//         assertApproxEqAbs(_votingEscrow.totalSupply(), _totalSupplyBefore + _amountLocked, 1e21, "_checkUserBalancesAfterIncreaseAmount: E1");
//         assertEq(_puppetERC20.balanceOf(address(_votingEscrow)), _votingEscrowBalanceBefore + _amountLocked, "_checkUserBalancesAfterIncreaseAmount: E2");
//         assertEq(_votingEscrow.lockedAmount(_user), _lockedAmountBefore + _amountLocked, "_checkUserBalancesAfterIncreaseAmount: E3");
//     }

//     function _checkWithdrawWrongFlows(address _user) internal {
//         vm.startPrank(_user);
//         vm.expectRevert(); // reverts with ```The lock didn't expire```
//         _votingEscrow.withdraw();
//         vm.stopPrank();
//     }

//     function _checkUserBalancesAfterWithdraw(address _user, uint256 _totalSupplyBefore, uint256 _puppetBalanceBefore) internal {
//         assertEq(_votingEscrow.balanceOf(_user), 0, "_checkUserBalancesAfterWithdraw: E0");
//         assertTrue(_votingEscrow.totalSupply() < _totalSupplyBefore, "_checkUserBalancesAfterWithdraw: E1");
//         assertTrue(_puppetERC20.balanceOf(_user) > _puppetBalanceBefore, "_checkUserBalancesAfterWithdraw: E2");
//     }
// }