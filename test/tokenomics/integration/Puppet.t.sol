// // SPDX-License-Identifier: AGPL-3.0-only
// pragma solidity 0.8.19;

// import "../../Base.t.sol";

// contract PuppetERC20Tests is Base {

//     // ============================================================================================
//     // Test Functions
//     // ============================================================================================

//     function testParamsOnDeployment() external {
//         assertEq(_puppetERC20.name(), "Puppet Finance Token", "testParamsOnDeployment: E0");
//         assertEq(_puppetERC20.symbol(), "PUPPET", "testParamsOnDeployment: E1");
//         assertEq(_puppetERC20.decimals(), 18, "testParamsOnDeployment: E2");
//         assertEq(_puppetERC20.totalSupply(), 3000000 * 1e18, "testParamsOnDeployment: E3");
//         assertEq(_puppetERC20.startEpochSupply(), 3000000 * 1e18, "testParamsOnDeployment: E4");
//         assertEq(_puppetERC20.balanceOf(users.owner), 3000000 * 1e18, "testParamsOnDeployment: E5");
//         assertEq(_puppetERC20.availableSupply(), 3000000 * 1e18, "testParamsOnDeployment: E6");
//     }

//     function testParamsOnFinishedEpochs() external {

//         skip(86400); // skip INFLATION_DELAY (1 day)

//         // First Epoch
//         _puppetERC20.updateMiningParameters(); // start 1st epoch

//         uint256 _mintableForFirstEpoch = _puppetERC20.mintableInTimeframe(_puppetERC20.startEpochTime(), _puppetERC20.startEpochTime() + (86400 * 365));

//         assertApproxEqAbs(_mintableForFirstEpoch, 1115000 * 1e18, 1e20, "testParamsOnFinishedEpochs: E7"); // make sure ~1,125,000 tokens will be emitted in 1st year

//         skip(86400 * 365 / 2); // skip half of 1st epoch (year)
//         assertEq(_puppetERC20.availableSupply(), _puppetERC20.totalSupply() + (_mintableForFirstEpoch / 2), "testParamsOnFinishedEpochs: E8");

//         vm.expectRevert(); // reverts with ```too soon!```
//         _puppetERC20.updateMiningParameters();

//         skip(86400 * 365 / 2); // skip 2nd half of 1st epoch (year)
//         assertEq(_puppetERC20.availableSupply(), _puppetERC20.totalSupply() + _mintableForFirstEpoch, "testParamsOnFinishedEpochs: E8");

//         _testMint(_mintableForFirstEpoch); // this also starts the next epoch

//         uint256 _mintedLastEpoch = _mintableForFirstEpoch;
//         for (uint256 i = 0; i < 39; i++) {
//             uint256 _mintableForEpoch = _puppetERC20.mintableInTimeframe(_puppetERC20.startEpochTime(), _puppetERC20.startEpochTime() + (86400 * 365));

//             assertTrue(_mintableForEpoch > 0, "testParamsOnFinishedEpochs: E9:");

//              // make sure inflation is decreasing by ~18% each year
//             assertApproxEqAbs(_mintableForEpoch, _mintedLastEpoch - (_mintedLastEpoch * 18 / 100), 1e23, "testParamsOnFinishedEpochs: E10:");

//             skip(86400 * 365); // skip the entire epoch (year)

//             _testMint(_mintableForEpoch); // this also starts the next epoch

//             _mintedLastEpoch = _mintableForEpoch;
//         }

//         assertEq(_puppetERC20.availableSupply(), 10000000 * 1e18, "testParamsOnFinishedEpochs: E11:");
//         assertEq(_puppetERC20.totalSupply(), 10000000 * 1e18, "testParamsOnFinishedEpochs: E12:");

//         vm.startPrank(address(_minter));
//         vm.expectRevert(); // reverts with ```exceeds allowable mint amount```        
//         _puppetERC20.mint(users.owner, 1);
//         vm.stopPrank();
//     }

//     function _testMint(uint256 _mintableForEpoch) internal {
//         uint256 _aliceBalanceBefore = _puppetERC20.balanceOf(users.alice);
//         uint256 _totalSupplyBefore = _puppetERC20.totalSupply();

//         assertEq(_puppetERC20.totalSupply(), _totalSupplyBefore, "_testMint: E1");

//         vm.expectRevert(); // reverts with ```minter only```        
//         _puppetERC20.mint(users.owner, _mintableForEpoch);

//         vm.startPrank(address(_minter));
//         _puppetERC20.mint(users.alice, _mintableForEpoch);
//         vm.stopPrank();

//         assertEq(_puppetERC20.availableSupply(), _totalSupplyBefore + _mintableForEpoch, "_testMint: E2");
//         assertEq(_puppetERC20.totalSupply(), _totalSupplyBefore + _mintableForEpoch, "_testMint: E3");
//         assertEq(_puppetERC20.balanceOf(users.alice), _aliceBalanceBefore + _mintableForEpoch, "_testMint: E4");
//     }
// }