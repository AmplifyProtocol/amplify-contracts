// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../../Base.t.sol";

contract AmplifyTests is Base {

    // ============================================================================================
    // Test Functions
    // ============================================================================================

    function testParamsOnDeployment() external {
        assertEq(_ampl.name(), "Amplify Protocol Token", "testParamsOnDeployment: E0");
        assertEq(_ampl.symbol(), "AMPL", "testParamsOnDeployment: E1");
        assertEq(_ampl.decimals(), 18, "testParamsOnDeployment: E2");
        assertEq(_ampl.totalSupply(), 3000000 * 1e18, "testParamsOnDeployment: E3");
        assertEq(_ampl.startEpochSupply(), 3000000 * 1e18, "testParamsOnDeployment: E4");
        assertEq(_ampl.balanceOf(users.owner), 3000000 * 1e18, "testParamsOnDeployment: E5");
        assertEq(_ampl.availableSupply(), 3000000 * 1e18, "testParamsOnDeployment: E6");
    }

    function testParamsOnFinishedEpochs() external {

        skip(86400); // skip INFLATION_DELAY (1 day)

        // First Epoch
        _ampl.updateMiningParameters(); // start 1st epoch

        uint256 _mintableForFirstEpoch = _ampl.mintableInTimeframe(_ampl.startEpochTime(), _ampl.startEpochTime() + (86400 * 365));

        assertApproxEqAbs(_mintableForFirstEpoch, 1115000 * 1e18, 1e20, "testParamsOnFinishedEpochs: E7"); // make sure ~1,125,000 tokens will be emitted in 1st year

        skip(86400 * 365 / 2); // skip half of 1st epoch (year)
        assertEq(_ampl.availableSupply(), _ampl.totalSupply() + (_mintableForFirstEpoch / 2), "testParamsOnFinishedEpochs: E8");

        vm.expectRevert(); // reverts with ```too soon!```
        _ampl.updateMiningParameters();

        skip(86400 * 365 / 2); // skip 2nd half of 1st epoch (year)
        assertEq(_ampl.availableSupply(), _ampl.totalSupply() + _mintableForFirstEpoch, "testParamsOnFinishedEpochs: E8");

        _testMint(_mintableForFirstEpoch); // this also starts the next epoch

        uint256 _mintedLastEpoch = _mintableForFirstEpoch;
        for (uint256 i = 0; i < 39; i++) {
            uint256 _mintableForEpoch = _ampl.mintableInTimeframe(_ampl.startEpochTime(), _ampl.startEpochTime() + (86400 * 365));

            assertTrue(_mintableForEpoch > 0, "testParamsOnFinishedEpochs: E9:");

             // make sure inflation is decreasing by ~18% each year
            assertApproxEqAbs(_mintableForEpoch, _mintedLastEpoch - (_mintedLastEpoch * 18 / 100), 1e23, "testParamsOnFinishedEpochs: E10:");

            skip(86400 * 365); // skip the entire epoch (year)

            _testMint(_mintableForEpoch); // this also starts the next epoch

            _mintedLastEpoch = _mintableForEpoch;
        }

        assertEq(_ampl.availableSupply(), 10000000 * 1e18, "testParamsOnFinishedEpochs: E11:");
        assertEq(_ampl.totalSupply(), 10000000 * 1e18, "testParamsOnFinishedEpochs: E12:");

        vm.startPrank(address(_minter));
        vm.expectRevert(); // reverts with ```exceeds allowable mint amount```        
        _ampl.mint(users.owner, 1);
        vm.stopPrank();
    }

    function _testMint(uint256 _mintableForEpoch) internal {
        uint256 _aliceBalanceBefore = _ampl.balanceOf(users.alice);
        uint256 _totalSupplyBefore = _ampl.totalSupply();

        assertEq(_ampl.totalSupply(), _totalSupplyBefore, "_testMint: E1");

        vm.expectRevert(); // reverts with ```minter only```        
        _ampl.mint(users.owner, _mintableForEpoch);

        vm.startPrank(address(_minter));
        _ampl.mint(users.alice, _mintableForEpoch);
        vm.stopPrank();

        assertEq(_ampl.availableSupply(), _totalSupplyBefore + _mintableForEpoch, "_testMint: E2");
        assertEq(_ampl.totalSupply(), _totalSupplyBefore + _mintableForEpoch, "_testMint: E3");
        assertEq(_ampl.balanceOf(users.alice), _aliceBalanceBefore + _mintableForEpoch, "_testMint: E4");
    }
}