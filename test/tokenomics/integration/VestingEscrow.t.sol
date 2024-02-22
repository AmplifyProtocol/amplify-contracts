// // SPDX-License-Identifier: AGPL-3.0-only
// pragma solidity 0.8.19;

// import {VestingEscrow} from "src/tokenomics/VestingEscrow.sol";

// import "../../Base.t.sol";

// contract VestingEscrowTests is Base {

//     VestingEscrow internal _vestingEscrow;

//     function setUp() public override {
//         Base.setUp();

//         vm.startPrank(users.owner);
//         _vestingEscrow = new VestingEscrow(_dictator);

//         bytes4 _initializeSig = _vestingEscrow.initialize.selector;
//         _setRoleCapability(_dictator, 0, address(_vestingEscrow), _initializeSig, true);
//         _setUserRole(_dictator, users.owner, 0, true);

//         vm.stopPrank();

//         _dealERC20(address(_puppetERC20), users.owner, 10 ether);
//         require(_puppetERC20.balanceOf(users.owner) > 0, "PuppetERC20Tests: users.owner balance is zero");
//     }

//     // ============================================================================================
//     // Test Functions
//     // ============================================================================================

//     function testFlow() external {
//         uint256 _amountToVest = _puppetERC20.balanceOf(users.owner);
//         require(_amountToVest > 0, "VestingEscrow: amountToVest is zero");

//         uint256 _startTime = block.timestamp;
//         uint256 _endTime = _startTime + 365 days;
//         uint256 _vestingEscrowBalanceBefore = _puppetERC20.balanceOf(address(_vestingEscrow));

//         vm.startPrank(users.owner);
//         _puppetERC20.approve(address(_vestingEscrow), _amountToVest);
//         _vestingEscrow.initialize(address(_puppetERC20), users.alice, _amountToVest, _startTime, _endTime, true);
//         vm.stopPrank();

//         assertEq(_puppetERC20.balanceOf(address(_vestingEscrow)), _vestingEscrowBalanceBefore + _amountToVest, "testFlow: E0");
//         assertEq(_puppetERC20.balanceOf(users.owner), 0, "testFlow: E1");
//         assertEq(_puppetERC20.balanceOf(users.alice), 0, "testFlow: E2");
//         assertEq(_vestingEscrow.vestedSupply(), 0, "testFlow: E3");
//         assertEq(_vestingEscrow.lockedSupply(), _amountToVest, "testFlow: E4");
//         assertEq(_vestingEscrow.vestedOf(users.alice), 0, "testFlow: E5");
//         assertEq(_vestingEscrow.balanceOf(users.alice), 0, "testFlow: E6");
//         assertEq(_vestingEscrow.lockedOf(users.alice), _amountToVest, "testFlow: E7");

//         skip(365 days / 2);

//         assertEq(_puppetERC20.balanceOf(users.alice), 0, "testFlow: E8");
//         assertEq(_vestingEscrow.vestedSupply(), _amountToVest / 2, "testFlow: E9");
//         assertEq(_vestingEscrow.lockedSupply(), _amountToVest / 2, "testFlow: E10");
//         assertEq(_vestingEscrow.vestedOf(users.alice), _amountToVest / 2, "testFlow: E11");
//         assertEq(_vestingEscrow.balanceOf(users.alice), _amountToVest / 2, "testFlow: E12");
//         assertEq(_vestingEscrow.lockedOf(users.alice), _amountToVest / 2, "testFlow: E13");

//         _vestingEscrow.claim(users.alice);

//         assertEq(_puppetERC20.balanceOf(users.alice), _amountToVest / 2, "testFlow: E14");
//         assertEq(_vestingEscrow.vestedSupply(), _amountToVest / 2, "testFlow: E15");
//         assertEq(_vestingEscrow.lockedSupply(), _amountToVest / 2, "testFlow: E16");
//         assertEq(_vestingEscrow.vestedOf(users.alice), _amountToVest / 2, "testFlow: E17");
//         assertEq(_vestingEscrow.balanceOf(users.alice), 0, "testFlow: E18");
//         assertEq(_vestingEscrow.lockedOf(users.alice), _amountToVest / 2, "testFlow: E19");

//         skip(365 days / 2);

//         assertEq(_puppetERC20.balanceOf(users.alice), _amountToVest / 2, "testFlow: E20");
//         assertEq(_vestingEscrow.vestedSupply(), _amountToVest, "testFlow: E21");
//         assertEq(_vestingEscrow.lockedSupply(), 0, "testFlow: E22");
//         assertEq(_vestingEscrow.vestedOf(users.alice), _amountToVest, "testFlow: E23");
//         assertEq(_vestingEscrow.balanceOf(users.alice), _amountToVest / 2, "testFlow: E24");
//         assertEq(_vestingEscrow.lockedOf(users.alice), 0, "testFlow: E25");

//         _vestingEscrow.claim(users.alice);

//         assertEq(_puppetERC20.balanceOf(users.alice), _amountToVest, "testFlow: E26");
//         assertEq(_vestingEscrow.vestedSupply(), _amountToVest, "testFlow: E27");
//         assertEq(_vestingEscrow.lockedSupply(), 0, "testFlow: E28");
//         assertEq(_vestingEscrow.vestedOf(users.alice), _amountToVest, "testFlow: E29");
//         assertEq(_vestingEscrow.balanceOf(users.alice), 0, "testFlow: E30");
//         assertEq(_vestingEscrow.lockedOf(users.alice), 0, "testFlow: E31");
//     }
// }