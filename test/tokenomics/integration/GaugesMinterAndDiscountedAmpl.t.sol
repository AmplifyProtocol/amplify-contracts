// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../../Base.t.sol";

contract GaugesMinterAndDiscountedAmplTests is Base {

    address internal _route;
    address internal _orchestrator;

    ScoreGauge internal _scoreGauge1;
    ScoreGauge internal _scoreGauge2;
    ScoreGauge internal _scoreGauge3;

    function setUp() public override {
        Base.setUp();

        _scoreGauge1 = new ScoreGauge(_governor, _votingEscrow, _minter, _dataStore, _dAmpl, IERC20(address(_ampl)));
        _scoreGauge2 = new ScoreGauge(_governor, _votingEscrow, _minter, _dataStore, _dAmpl, IERC20(address(_ampl)));
        _scoreGauge3 = new ScoreGauge(_governor, _votingEscrow, _minter, _dataStore, _dAmpl, IERC20(address(_ampl)));

        // mint some PUPPET to users
        _dealERC20(address(_ampl), users.alice, 10 ether);
        _dealERC20(address(_ampl), users.bob, 10 ether);
        _dealERC20(address(_ampl), users.yossi, 10 ether);
        uint256 _balance = _ampl.balanceOf(users.alice);

        uint256 _votingEscrowBalanceBefore = _ampl.balanceOf(address(_votingEscrow));

        // vote lock for alice
        vm.startPrank(users.alice);
        _balance = _ampl.balanceOf(users.alice);
        _ampl.approve(address(_votingEscrow), _balance);
        _votingEscrow.modifyLock(_balance, block.timestamp + _votingEscrow.maxTime(), users.alice);
        require(_ampl.balanceOf(address(_votingEscrow)) - _balance == _votingEscrowBalanceBefore);
        vm.stopPrank();

        _votingEscrowBalanceBefore = _ampl.balanceOf(address(_votingEscrow));

        // vote lock for bob
        vm.startPrank(users.bob);
        _balance = _ampl.balanceOf(users.bob);
        _ampl.approve(address(_votingEscrow), _balance);
        _votingEscrow.modifyLock(_balance, block.timestamp + _votingEscrow.maxTime(), users.bob);
        require(_ampl.balanceOf(address(_votingEscrow)) - _balance == _votingEscrowBalanceBefore);
        vm.stopPrank();

        // vote lock for yossi
        vm.startPrank(users.yossi);
        _balance = _ampl.balanceOf(users.yossi);
        _ampl.approve(address(_votingEscrow), _balance);
        _votingEscrow.modifyLock(_balance, block.timestamp + _votingEscrow.maxTime(), users.yossi);
        vm.stopPrank();

        // give owner permission
        vm.startPrank(users.owner);
        _setRoleCapability(_governor, 0, address(_gaugeController), _gaugeController.addType.selector, true);
        _setRoleCapability(_governor, 0, address(_gaugeController), _gaugeController.addGauge.selector, true);
        _setRoleCapability(_governor, 0, address(_gaugeController), _gaugeController.initializeEpoch.selector, true);
        _setRoleCapability(_governor, 0, address(_revenueDistributer), _revenueDistributer.toggleAllowCheckpointToken.selector, true);
        _setRoleCapability(_governor, 0, address(_dAmpl), _dAmpl.setDiscount.selector, true);

        _dAmpl.setScoreGauge(address(_scoreGauge1), true);
        _dAmpl.setScoreGauge(address(_scoreGauge2), true);
        _dAmpl.setScoreGauge(address(_scoreGauge3), true);

        vm.stopPrank();

        // setup a mocks
        _route = _createUser("Route");
        _orchestrator = _createUser("Orchestrator");
        bytes32 _routeKey = CommonHelper.routeKey(_dataStore, _route);
        require(_routeKey != bytes32(0), "GaugesAndMinterTests setUp: routeKey is 0");
        vm.startPrank(users.owner);
        _dataStore.setBool(Keys.isRouteRegisteredKey(_route), true);
        _dataStore.setAddress(keccak256(abi.encode("ORCHESTRATOR")), _orchestrator);
        vm.stopPrank();

        vm.startPrank(users.owner);
        _revenueDistributer.toggleAllowCheckpointToken();
        vm.stopPrank();
    }

    // ============================================================================================
    // Test Functions
    // ============================================================================================

    function testCorrectFlow() public {

        // ADD GAUGE TYPE1
        _preGaugeTypeAddAsserts();
        vm.startPrank(users.owner);
        _gaugeController.addType("Arbitrum", 1000000000000000000);
        vm.stopPrank();
        _postGaugeTypeAddAsserts();

        // ADD GAUGE1
        _preGauge1AddAsserts();
        vm.startPrank(users.owner);
        _gaugeController.addGauge(address(_scoreGauge1), 0, 1);
        vm.stopPrank();
        _postGauge1AddAsserts();

        // ADD GAUGE2
        _preGauge2AddAsserts();
        vm.startPrank(users.owner);
        _gaugeController.addGauge(address(_scoreGauge2), 0, 0);
        vm.stopPrank();
        _postGauge2AddAsserts();

        // ADD GAUGE TYPE2
        _preGauge2TypeAddAsserts();
        vm.startPrank(users.owner);
        _gaugeController.addType("Optimism", 1000000000000000000);
        vm.stopPrank();
        _postGauge2TypeAddAsserts();

        // ADD GAUGE3
        _preGauge3AddAsserts();
        vm.startPrank(users.owner);
        _gaugeController.addGauge(address(_scoreGauge3), 1, 0);
        vm.stopPrank();
        _postGauge3AddAsserts();

        // INIT 1st EPOCH
        _preInitEpochAsserts();
        skip(86400); // wait _INFLATION_DELAY so we can initEpoch
        vm.startPrank(users.owner);
        _gaugeController.initializeEpoch();
        vm.stopPrank();
        _postInitEpochAsserts(); // epoch has not ended yet

        // TRADE 1st EPOCH (update ScoreGauge)
        _updateScoreGauge(_scoreGauge1, users.alice, false);
        _updateScoreGauge(_scoreGauge1, users.bob, false);
        _updateScoreGauge(_scoreGauge1, users.yossi, false);
        _checkScoreGaugeTotals();

        // FINISH 1st EPOCH
        skip(86400 * 7); // skip epoch duration (1 week)
        _preAdvanceEpochAsserts(); // epoch has ended
        _gaugeController.advanceEpoch();
        _postAdvanceEpochAsserts();

        // SET DISCOUNT (to 50%)
        vm.startPrank(users.owner);
        _dAmpl.setDiscount(50);
        vm.stopPrank();

        // MINT REWARDS FOR 1st EPOCH
        address[] memory _gauges = new address[](3);
        _gauges[0] = address(_scoreGauge1);
        _gauges[1] = address(_scoreGauge2);
        _gauges[2] = address(_scoreGauge3);
        _minter.mintMany(_gauges);
        _postMintRewardsAsserts();

        // CLAIM 1st EPOCH
        uint256 _aliceClaimedRewards = _claimForUser(_scoreGauge1, users.alice);
        uint256 _bobClaimedRewards = _claimForUser(_scoreGauge1, users.bob);
        uint256 _yossiClaimedRewards = _claimForUser(_scoreGauge1, users.yossi);
        _postClaimRewardsAsserts(_aliceClaimedRewards, _bobClaimedRewards, _yossiClaimedRewards);

        // VOTE FOR 2nd EPOCH (gauge2 gets all rewards) (we vote immediately after minting, if we wait a few days, votes will be valid for 3rd epoch)
        _preVote2ndEpochAsserts();
        _userVote2ndEpoch(users.alice);
        _userVote2ndEpoch(users.bob);
        _userVote2ndEpoch(users.yossi);

        // TRADE 2nd EPOCH (update ScoreGauge)
        _updateScoreGauge(_scoreGauge2, users.alice, true);
        _updateScoreGauge(_scoreGauge2, users.bob, true);
        _updateScoreGauge(_scoreGauge2, users.yossi, true);
        _checkScoreGaugeTotals();

        // ON 2nd EPOCH END
        skip(86400 * 7); // skip 1 epoch (1 week)
        _pre1stEpochEndAsserts(); // (before calling advanceEpoch())
        _gaugeController.advanceEpoch();
        _post1stEpochEndAsserts();

        // MINT REWARDS FOR 2nd EPOCH
        uint256 _dAmplBalanceBefore = _ampl.balanceOf(address(_dAmpl));
        _minter.mintMany(_gauges);
        _postMintFor1stEpochRewardsAsserts(_dAmplBalanceBefore);

        // CLAIM 2nd EPOCH
        _aliceClaimedRewards = _claimAndExcerciseForUser(_scoreGauge2, users.alice);
        _bobClaimedRewards = _claimAndExcerciseForUser(_scoreGauge2, users.bob);
        _yossiClaimedRewards = _claimAndExcerciseForUser(_scoreGauge2, users.yossi);
        _postClaimRewardsAsserts(_aliceClaimedRewards, _bobClaimedRewards, _yossiClaimedRewards);

        // VOTE FOR 3rd EPOCH (gauge1 gets half of rewards, gauge2 gets half of rewards)
        // skip(86400 * 1); // skip 5 days, just to make it more realistic
        _userVote3rdEpoch(users.alice);
        _userVote3rdEpoch(users.bob);
        _userVote3rdEpoch(users.yossi);
        _postVote3rdEpochAsserts();

        // TRADE 3rd EPOCH (update ScoreGauge)
        _updateScoreGauge(_scoreGauge1, users.alice, false);
        _updateScoreGauge(_scoreGauge1, users.bob, false);
        _updateScoreGauge(_scoreGauge1, users.yossi, false);
        _checkScoreGaugeTotals();

        // ON 2nd EPOCH END
        skip(86400 * 7); // skip the 2 days left in the epoch
        _pre2ndEpochEndAsserts(); // (before calling advanceEpoch())
        _gaugeController.advanceEpoch();
        _post2ndEpochEndAsserts();

        // MINT REWARDS FOR 2nd EPOCH
        _dAmplBalanceBefore = _ampl.balanceOf(address(_dAmpl));
        _minter.mintMany(_gauges);
        _postMintFor3rdEpochRewardsAsserts(_dAmplBalanceBefore);

        // SET DISCOUNT (to 100%)
        vm.startPrank(users.owner);
        _dAmpl.setDiscount(100);
        vm.stopPrank();

        // CLAIM 3rd EPOCH (claim rewards from ScoreGauge)
        _aliceClaimedRewards = _claimExcerciseAndLockForUser(_scoreGauge1, users.alice);
        _bobClaimedRewards = _claimExcerciseAndLockForUser(_scoreGauge1, users.bob);
        _yossiClaimedRewards = _claimExcerciseAndLockForUser(_scoreGauge1, users.yossi);
        _postClaimRewardsAsserts(_aliceClaimedRewards, _bobClaimedRewards, _yossiClaimedRewards);

        // VOTE FOR 4th EPOCH (gauge3 gets all rewards)
        _userVote4thEpoch(users.alice);
        _userVote4thEpoch(users.bob);
        _userVote4thEpoch(users.yossi);
        _postVote4thEpochAsserts();

        // TRADE 4th EPOCH (update ScoreGauge)
        _updateScoreGauge(_scoreGauge3, users.alice, false);
        _updateScoreGauge(_scoreGauge3, users.bob, false);
        _updateScoreGauge(_scoreGauge3, users.yossi, false);
        _checkScoreGaugeTotals();

        // ON 4th EPOCH END
        skip(7 days);
        _pre4thEpochEndAsserts(); // (before calling advanceEpoch())
        _gaugeController.advanceEpoch();
        _post4thEpochEndAsserts();

        // MINT REWARDS FOR 4th EPOCH
        _minter.mintMany(_gauges);

        // CLAIM 4th EPOCH (dAmpls are not claimed, and are refunded)
        _refundOptions(_scoreGauge3, users.alice);
        _refundOptions(_scoreGauge3, users.bob);
        _refundOptions(_scoreGauge3, users.yossi);

        // DEPOSIT REVENUE (to revenueDistributer)
        _depositToRevenueDistributer();
        _claimRevenueDistributerRewards();
    }

    // =======================================================
    // Internal Helper Functions
    // =======================================================

    function _preGaugeTypeAddAsserts() internal {
        assertEq(_gaugeController.gaugeTypeNames(0), "", "_preGaugeTypeAddAsserts: E0");
        assertEq(_gaugeController.numberGaugeTypes(), 0, "_preGaugeTypeAddAsserts: E1");
        assertEq(_gaugeController.getTypeWeight(0), 0, "_preGaugeTypeAddAsserts: E2");
        assertEq(_gaugeController.getTotalWeight(), 0, "_preGaugeTypeAddAsserts: E3");
        assertEq(_gaugeController.getWeightsSumPerType(0), 0, "_preGaugeTypeAddAsserts: E4");

        vm.expectRevert("UNAUTHORIZED");
        _gaugeController.addType("Arbitrum", 0);
    }

    function _postGaugeTypeAddAsserts() internal {
        assertEq(_gaugeController.gaugeTypeNames(0), "Arbitrum", "_postGaugeTypeAddAsserts: E0");
        assertEq(_gaugeController.numberGaugeTypes(), 1, "_postGaugeTypeAddAsserts: E1");
        assertEq(_gaugeController.getTypeWeight(0), 1000000000000000000, "_postGaugeTypeAddAsserts: E2");
        assertEq(_gaugeController.getTotalWeight(), 0, "_postGaugeTypeAddAsserts: E3");
        assertEq(_gaugeController.getWeightsSumPerType(0), 0, "_postGaugeTypeAddAsserts: E4");
    }

    function _preGauge1AddAsserts() internal {
        assertEq(_gaugeController.numberGauges(), 0, "_preGaugeAddAsserts: E0");
        assertEq(_gaugeController.getGaugeWeight(address(_scoreGauge1)), 0, "_preGaugeAddAsserts: E1");
        assertEq(_gaugeController.getTotalWeight(), 0, "_preGaugeAddAsserts: E2");
        assertEq(_gaugeController.getWeightsSumPerType(0), 0, "_preGaugeAddAsserts: E3");
        assertEq(_gaugeController.gauges(0), address(0), "_preGaugeAddAsserts: E4");
        assertEq(_gaugeController.gaugeRelativeWeightWrite(address(_scoreGauge1), block.timestamp), 0, "_preGaugeAddAsserts: E5");

        int128 _numberGaugeTypes = _gaugeController.numberGaugeTypes();

        vm.expectRevert("UNAUTHORIZED");
        _gaugeController.addGauge(address(_scoreGauge1), _numberGaugeTypes, 0);

        vm.startPrank(users.owner);
        vm.expectRevert(bytes4(keccak256("InvalidGaugeType()")));
        _gaugeController.addGauge(address(_scoreGauge1), _numberGaugeTypes, 0);
        vm.stopPrank();
    }

    function _postGauge1AddAsserts() internal {
        assertEq(_gaugeController.numberGauges(), 1, "_postGauge1AddAsserts: E0");
        assertEq(_gaugeController.getGaugeWeight(address(_scoreGauge1)), 1, "_postGauge1AddAsserts: E1");
        assertEq(_gaugeController.getTotalWeight(), 1000000000000000000, "_postGauge1AddAsserts: E2");
        assertEq(_gaugeController.getWeightsSumPerType(0), 1, "_postGauge1AddAsserts: E3");
        assertEq(_gaugeController.gauges(0), address(_scoreGauge1), "_postGauge1AddAsserts: E4");
        assertEq(_gaugeController.gaugeRelativeWeightWrite(address(_scoreGauge1), block.timestamp), 0, "_postGauge1AddAsserts: E5"); // some time need to pass before this is updated
        assertEq(_gaugeController.gaugeRelativeWeight(address(_scoreGauge1), block.timestamp), 0, "_postGauge1AddAsserts: E6"); // same here

        vm.startPrank(users.owner);
        vm.expectRevert(bytes4(keccak256("GaugeAlreadyAdded()")));
        _gaugeController.addGauge(address(_scoreGauge1), 0, 0);
        vm.stopPrank();
    }

    function _preGauge2AddAsserts() internal {
        assertEq(_gaugeController.numberGauges(), 1, "_preGauge2AddAsserts: E0");
        assertEq(_gaugeController.getGaugeWeight(address(_scoreGauge2)), 0, "_preGauge2AddAsserts: E1");
        assertEq(_gaugeController.getTotalWeight(), 1000000000000000000, "_preGauge2AddAsserts: E2");
        assertEq(_gaugeController.getWeightsSumPerType(0), 1, "_preGauge2AddAsserts: E3");
        assertEq(_gaugeController.gauges(1), address(0), "_preGauge2AddAsserts: E4");

        int128 _numberGaugeTypes = _gaugeController.numberGaugeTypes();

        vm.expectRevert("UNAUTHORIZED");
        _gaugeController.addGauge(address(_scoreGauge2), _numberGaugeTypes, 0);

        vm.startPrank(users.owner);
        vm.expectRevert(bytes4(keccak256("InvalidGaugeType()")));
        _gaugeController.addGauge(address(_scoreGauge1), _numberGaugeTypes, 0);
        vm.stopPrank();
    }

    function _postGauge2AddAsserts() internal {
        assertEq(_gaugeController.numberGauges(), 2, "_postGauge2AddAsserts: E0");
        assertEq(_gaugeController.getGaugeWeight(address(_scoreGauge2)), 0, "_postGauge2AddAsserts: E1");
        assertEq(_gaugeController.getTotalWeight(), 1000000000000000000, "_postGauge2AddAsserts: E2");
        assertEq(_gaugeController.getWeightsSumPerType(0), 1, "_postGauge2AddAsserts: E3");
        assertEq(_gaugeController.gauges(1), address(_scoreGauge2), "_postGauge2AddAsserts: E4");
        assertEq(_gaugeController.gaugeRelativeWeightWrite(address(_scoreGauge2), block.timestamp), 0, "_postGauge2AddAsserts: E5");

        vm.startPrank(users.owner);
        vm.expectRevert(bytes4(keccak256("GaugeAlreadyAdded()")));
        _gaugeController.addGauge(address(_scoreGauge2), 0, 0);
        vm.stopPrank();
    }

    function _preGauge2TypeAddAsserts() internal {
        assertEq(_gaugeController.gaugeTypeNames(1), "", "_preGauge2TypeAddAsserts: E0");
        assertEq(_gaugeController.numberGaugeTypes(), 1, "_preGauge2TypeAddAsserts: E1");
        assertEq(_gaugeController.getTypeWeight(1), 0, "_preGauge2TypeAddAsserts: E2");
        assertEq(_gaugeController.getTotalWeight(), 1000000000000000000, "_preGauge2TypeAddAsserts: E3");
        assertEq(_gaugeController.getWeightsSumPerType(1), 0, "_preGauge2TypeAddAsserts: E4");

        vm.expectRevert("UNAUTHORIZED");
        _gaugeController.addType("Optimism", 0);
    }

    function _postGauge2TypeAddAsserts() internal {
        assertEq(_gaugeController.gaugeTypeNames(1), "Optimism", "_postGauge2TypeAddAsserts: E0");
        assertEq(_gaugeController.numberGaugeTypes(), 2, "_postGauge2TypeAddAsserts: E1");
        assertEq(_gaugeController.getTypeWeight(1), 1000000000000000000, "_postGauge2TypeAddAsserts: E2");
        assertEq(_gaugeController.getTotalWeight(), 1000000000000000000, "_postGauge2TypeAddAsserts: E3");
        assertEq(_gaugeController.getWeightsSumPerType(0), 1, "_postGauge2TypeAddAsserts: E4");
    }

    function _preGauge3AddAsserts() internal {
        assertEq(_gaugeController.numberGauges(), 2, "_preGaugeAddAsserts: E0");
        assertEq(_gaugeController.getGaugeWeight(address(_scoreGauge3)), 0, "_preGaugeAddAsserts: E1");
        assertEq(_gaugeController.getTotalWeight(), 1000000000000000000, "_preGaugeAddAsserts: E2");
        assertEq(_gaugeController.getWeightsSumPerType(1), 0, "_preGaugeAddAsserts: E3");
        assertEq(_gaugeController.gauges(2), address(0), "_preGaugeAddAsserts: E4");

        int128 _numberGaugeTypes = _gaugeController.numberGaugeTypes();

        vm.expectRevert("UNAUTHORIZED");
        _gaugeController.addGauge(address(_scoreGauge3), _numberGaugeTypes, 0);

        vm.startPrank(users.owner);
        vm.expectRevert(bytes4(keccak256("InvalidGaugeType()")));
        _gaugeController.addGauge(address(_scoreGauge3), _numberGaugeTypes, 0);
        vm.stopPrank();
    }

    function _postGauge3AddAsserts() internal {
        assertEq(_gaugeController.numberGauges(), 3, "_postGaugeAddAsserts: E0");
        assertEq(_gaugeController.getGaugeWeight(address(_scoreGauge3)), 0, "_postGaugeAddAsserts: E1");
        assertEq(_gaugeController.getTotalWeight(), 1000000000000000000, "_postGaugeAddAsserts: E2");
        assertEq(_gaugeController.getWeightsSumPerType(1), 0, "_postGaugeAddAsserts: E3");
        assertEq(_gaugeController.gauges(2), address(_scoreGauge3), "_postGaugeAddAsserts: E4");
        assertEq(_gaugeController.gaugeRelativeWeightWrite(address(_scoreGauge3), block.timestamp), 0, "_postGaugeAddAsserts: E5");

        vm.startPrank(users.owner);
        vm.expectRevert(bytes4(keccak256("GaugeAlreadyAdded()")));
        _gaugeController.addGauge(address(_scoreGauge3), 0, 0);
        vm.stopPrank();
    }

    function _preInitEpochAsserts() internal {
        vm.expectRevert(); // revert with ```Arithmetic over/underflow```
        _minter.mint(address(_scoreGauge1));
        vm.expectRevert(); // revert with ```Arithmetic over/underflow```
        _minter.mint(address(_scoreGauge2));
        vm.expectRevert(); // revert with ```Arithmetic over/underflow```
        _minter.mint(address(_scoreGauge3));

        vm.startPrank(users.alice);
        vm.expectRevert(bytes4(keccak256("EpochNotSet()")));
        _gaugeController.voteForGaugeWeights(address(_scoreGauge1), 10000);
        vm.stopPrank();

        vm.expectRevert(bytes4(keccak256("EpochNotSet()")));
        _gaugeController.advanceEpoch();

        assertEq(_gaugeController.epoch(), 0, "_preInitEpochAsserts: E0");
        assertEq(_ampl.mintableInTimeframe(block.timestamp, block.timestamp + 1 weeks), 0, "_preInitEpochAsserts: E1"); // must wait _INFLATION_DELAY

        vm.expectRevert("UNAUTHORIZED");
        _gaugeController.initializeEpoch();

        vm.startPrank(users.owner);
        vm.expectRevert(bytes4(keccak256("TooSoon()")));
        _gaugeController.initializeEpoch(); // must wait _INFLATION_DELAY
        vm.stopPrank();

        (uint256 _startTime, uint256 _endTime) = _gaugeController.epochTimeframe(0);
        assertEq(_startTime, 0, "_preInitEpochAsserts: E2");
        assertEq(_endTime, 0, "_preInitEpochAsserts: E3");
    }

    function _postInitEpochAsserts() internal {
        assertEq(_gaugeController.epoch(), 1, "_postInitEpochAsserts: E0");
        assertTrue(_ampl.mintableInTimeframe(block.timestamp, block.timestamp + 1 weeks) > 0, "_postInitEpochAsserts: E1");
        assertEq(_gaugeController.getTotalWeight(), 1000000000000000000, "_postInitEpochAsserts: E2");
        assertEq(_gaugeController.getWeightsSumPerType(0), 1, "_postInitEpochAsserts: E3");
        assertEq(_gaugeController.currentEpochEndTime(), block.timestamp + 1 weeks, "_postInitEpochAsserts: E4");
        (uint256 _startTime, uint256 _endTime) = _gaugeController.epochTimeframe(1);
        assertEq(_startTime, 0, "_postInitEpochAsserts: E5");
        assertEq(_endTime, 0, "_postInitEpochAsserts: E6");

        vm.expectRevert(bytes4(keccak256("EpochNotEnded()")));
        _minter.mint(address(_scoreGauge1));

        vm.expectRevert(bytes4(keccak256("EpochNotEnded()")));
        _gaugeController.advanceEpoch();
    }

    function _preVote2ndEpochAsserts() internal {
        assertEq(_gaugeController.gaugeRelativeWeightWrite(address(address(_scoreGauge1)), block.timestamp), 1e18, "_preVote2ndEpochAsserts: E0");
        assertEq(_gaugeController.gaugeRelativeWeightWrite(address(address(_scoreGauge2)), block.timestamp), 0, "_preVote2ndEpochAsserts: E1");
        assertEq(_gaugeController.gaugeRelativeWeightWrite(address(address(_scoreGauge3)), block.timestamp), 0, "_preVote2ndEpochAsserts: E2");
        assertEq(_gaugeController.gaugeWeightForEpoch(1, address(address(_scoreGauge1))), 1e18, "_preVote2ndEpochAsserts: E3");
        assertEq(_gaugeController.gaugeWeightForEpoch(1, address(address(_scoreGauge2))), 0, "_preVote2ndEpochAsserts: E4");
        assertEq(_gaugeController.gaugeWeightForEpoch(1, address(address(_scoreGauge3))), 0, "_preVote2ndEpochAsserts: E5");
        assertEq(_gaugeController.gaugeWeightForEpoch(2, address(address(_scoreGauge1))), 0, "_preVote2ndEpochAsserts: E6");
        assertEq(_gaugeController.gaugeWeightForEpoch(2, address(address(_scoreGauge2))), 0, "_preVote2ndEpochAsserts: E7");
        assertEq(_gaugeController.gaugeWeightForEpoch(2, address(address(_scoreGauge3))), 0, "_preVote2ndEpochAsserts: E8");
        assertEq(_gaugeController.gaugeWeightForEpoch(3, address(address(_scoreGauge1))), 0, "_preVote2ndEpochAsserts: E9");
        assertEq(_gaugeController.gaugeWeightForEpoch(3, address(address(_scoreGauge2))), 0, "_preVote2ndEpochAsserts: E10");
        assertEq(_gaugeController.gaugeWeightForEpoch(3, address(address(_scoreGauge3))), 0, "_preVote2ndEpochAsserts: E11");
        assertTrue(_gaugeController.getTotalWeight() > 0, "_preVote2ndEpochAsserts: E12");
    }

    function _preAdvanceEpochAsserts() internal {
        assertEq(_gaugeController.gaugeRelativeWeightWrite(address(_scoreGauge1), block.timestamp), 1e18, "_preAdvanceEpochAsserts: E0");
        assertEq(_gaugeController.gaugeRelativeWeight(address(_scoreGauge2), block.timestamp), 0, "_preAdvanceEpochAsserts: E1");
        assertEq(_gaugeController.gaugeRelativeWeight(address(_scoreGauge3), block.timestamp), 0, "_preAdvanceEpochAsserts: E2");
        assertEq(_gaugeController.gaugeRelativeWeight(address(_scoreGauge1), block.timestamp), 1e18, "_preAdvanceEpochAsserts: E3");
        assertEq(_gaugeController.gaugeRelativeWeightWrite(address(_scoreGauge2), block.timestamp), 0, "_preAdvanceEpochAsserts: E4");
        assertEq(_gaugeController.gaugeRelativeWeightWrite(address(_scoreGauge3), block.timestamp), 0, "_preAdvanceEpochAsserts: E5");
    }

    function _postAdvanceEpochAsserts() internal {
        assertEq(_gaugeController.epoch(), 2, "_postAdvanceEpochAsserts: E0");
        (uint256 _start, uint256 _end) = _gaugeController.epochTimeframe(1);
        assertEq(_end, block.timestamp, "_postAdvanceEpochAsserts: E1");
        assertEq(_start, block.timestamp - 1 weeks, "_postAdvanceEpochAsserts: E2");
        assertEq(_gaugeController.gaugeWeightForEpoch(1, address(_scoreGauge1)), 1e18, "_postAdvanceEpochAsserts: E3");
        assertEq(_gaugeController.gaugeWeightForEpoch(1, address(_scoreGauge2)), 0, "_postAdvanceEpochAsserts: E4");
        assertEq(_gaugeController.gaugeWeightForEpoch(1, address(_scoreGauge3)), 0, "_postAdvanceEpochAsserts: E5");
        assertTrue(_gaugeController.hasEpochEnded(1), "_postAdvanceEpochAsserts: E6");
        assertTrue(!_gaugeController.hasEpochEnded(2), "_postAdvanceEpochAsserts: E7");

        assertTrue(_ampl.mintableInTimeframe(_start, _end) > 20000 * 1e18, "_postAdvanceEpochAsserts: E9");

        assertEq(_gaugeController.gaugeRelativeWeight(address(_scoreGauge1), block.timestamp), 1e18, "_postAdvanceEpochAsserts: E10");
        assertEq(_gaugeController.gaugeRelativeWeight(address(_scoreGauge2), block.timestamp), 0, "_postAdvanceEpochAsserts: E11");
        assertEq(_gaugeController.gaugeRelativeWeight(address(_scoreGauge3), block.timestamp), 0, "_postAdvanceEpochAsserts: E12");
    }

    function _postMintRewardsAsserts() internal {
        (uint256 _start, uint256 _end) = _gaugeController.epochTimeframe(1);
        uint256 _totalMintable = _ampl.mintableInTimeframe(_start, _end);
        assertEq(_ampl.balanceOf(address(_scoreGauge1)), 0, "_postMintRewardsAsserts: E0");
        assertEq(_ampl.balanceOf(address(_scoreGauge2)), 0, "_postMintRewardsAsserts: E1");
        assertEq(_ampl.balanceOf(address(_scoreGauge3)), 0, "_postMintRewardsAsserts: E2");
        assertEq(_ampl.balanceOf(address(_dAmpl)), _totalMintable, "_postMintRewardsAsserts: E3");
        assertEq(_dAmpl.rewards(address(_scoreGauge1)), _totalMintable, "_postMintRewardsAsserts: E4");
        assertEq(_dAmpl.rewards(address(_scoreGauge2)), 0, "_postMintRewardsAsserts: E5");
        assertEq(_dAmpl.rewards(address(_scoreGauge3)), 0, "_postMintRewardsAsserts: E6");

        vm.expectRevert(bytes4(keccak256("AlreadyMinted()")));
        _minter.mint(address(_scoreGauge1));
    }

    function _userVote2ndEpoch(address _user) internal {
        vm.startPrank(_user);
        _gaugeController.voteForGaugeWeights(address(_scoreGauge2), 10000);

        vm.expectRevert(bytes4(keccak256("AlreadyVoted()")));
        _gaugeController.voteForGaugeWeights(address(_scoreGauge2), 10000);

        vm.expectRevert(bytes4(keccak256("TooMuchPowerUsed()")));
        _gaugeController.voteForGaugeWeights(address(_scoreGauge1), 1);

        vm.stopPrank();

        assertEq(_gaugeController.gaugeRelativeWeightWrite(address(_scoreGauge1), block.timestamp), 1e18, "_userVote2ndEpoch: E0");
        assertEq(_gaugeController.gaugeRelativeWeightWrite(address(_scoreGauge2), block.timestamp), 0, "_userVote2ndEpoch: E1");
        assertEq(_gaugeController.gaugeRelativeWeightWrite(address(_scoreGauge3), block.timestamp), 0, "_userVote2ndEpoch: E2");
        assertEq(_gaugeController.gaugeRelativeWeightWrite(address(_scoreGauge1), block.timestamp + 1 weeks), 0, "_userVote2ndEpoch: E3");
        assertApproxEqAbs(_gaugeController.gaugeRelativeWeightWrite(address(_scoreGauge2), block.timestamp + 1 weeks), 1e18, 1e5, "_userVote2ndEpoch: E4");
        assertEq(_gaugeController.gaugeRelativeWeightWrite(address(_scoreGauge3), block.timestamp + 1 weeks), 0, "_userVote2ndEpoch: E5");
    }

    function _pre1stEpochEndAsserts() internal {
        assertEq(_gaugeController.gaugeRelativeWeight(address(_scoreGauge1), block.timestamp), 0, "_pre1stEpochEndAsserts: E0");
        assertApproxEqAbs(_gaugeController.gaugeRelativeWeight(address(_scoreGauge2), block.timestamp), 1e18, 1e5, "_pre1stEpochEndAsserts: E1");
        assertEq(_gaugeController.gaugeRelativeWeight(address(_scoreGauge3), block.timestamp), 0, "_pre1stEpochEndAsserts: E2");

        assertEq(_gaugeController.gaugeRelativeWeightWrite(address(_scoreGauge1), block.timestamp), 0, "_pre1stEpochEndAsserts: E3");
        assertApproxEqAbs(_gaugeController.gaugeRelativeWeightWrite(address(_scoreGauge2), block.timestamp), 1e18, 1e5, "_pre1stEpochEndAsserts: E4");
        assertEq(_gaugeController.gaugeRelativeWeightWrite(address(_scoreGauge3), block.timestamp), 0, "_pre1stEpochEndAsserts: E5");
    }

    function _post1stEpochEndAsserts() internal {
        assertEq(_gaugeController.epoch(), 3, "_post1stEpochEndAsserts: E0");
        (uint256 _start, uint256 _end) = _gaugeController.epochTimeframe(2);
        assertEq(_end, block.timestamp, "_post1stEpochEndAsserts: E1");
        assertEq(_start, block.timestamp - 1 weeks, "_post1stEpochEndAsserts: E2");
        assertEq(_gaugeController.gaugeWeightForEpoch(2, address(_scoreGauge1)), 0, "_post1stEpochEndAsserts: E3");
        assertApproxEqAbs(_gaugeController.gaugeWeightForEpoch(2, address(_scoreGauge2)), 1e18, 1e5, "_post1stEpochEndAsserts: E4");
        assertEq(_gaugeController.gaugeWeightForEpoch(2, address(_scoreGauge3)), 0, "_post1stEpochEndAsserts: E5");
        assertTrue(_gaugeController.hasEpochEnded(1), "_post1stEpochEndAsserts: E6");
        assertTrue(_gaugeController.hasEpochEnded(2), "_post1stEpochEndAsserts: E7");
        assertTrue(!_gaugeController.hasEpochEnded(3), "_post1stEpochEndAsserts: E71");

        assertTrue(_ampl.mintableInTimeframe(_start, _end) > 20000 * 1e18, "_post1stEpochEndAsserts: E9");

        assertEq(_gaugeController.gaugeRelativeWeight(address(_scoreGauge1), block.timestamp), 0, "_post1stEpochEndAsserts: E10");
        assertApproxEqAbs(_gaugeController.gaugeRelativeWeight(address(_scoreGauge2), block.timestamp), 1e18, 1e5, "_post1stEpochEndAsserts: E11");
        assertEq(_gaugeController.gaugeRelativeWeight(address(_scoreGauge3), block.timestamp), 0, "_post1stEpochEndAsserts: E12");
    }

    function _postMintFor1stEpochRewardsAsserts(uint256 _dAmplBalanceBefore) internal {
        (uint256 _start, uint256 _end) = _gaugeController.epochTimeframe(2);
        uint256 _totalMintable = _ampl.mintableInTimeframe(_start, _end);
        assertEq(IERC20(address(_ampl)).balanceOf(address(_scoreGauge1)), 0, "_postMintFor1stEpochRewardsAsserts: E0");
        assertEq(IERC20(address(_ampl)).balanceOf(address(_scoreGauge2)), 0, "_postMintFor1stEpochRewardsAsserts: E1");
        assertEq(IERC20(address(_ampl)).balanceOf(address(_scoreGauge3)), 0, "_postMintFor1stEpochRewardsAsserts: E2");
        assertApproxEqAbs(IERC20(address(_ampl)).balanceOf(address(_dAmpl)), _dAmplBalanceBefore + _totalMintable, 1e5, "_postMintFor1stEpochRewardsAsserts: E3");

        vm.expectRevert(bytes4(keccak256("AlreadyMinted()")));
        _minter.mint(address(_scoreGauge2));
    }

    function _userVote3rdEpoch(address _user) internal {
        vm.startPrank(_user);
        _gaugeController.voteForGaugeWeights(address(_scoreGauge2), 5000);
        _gaugeController.voteForGaugeWeights(address(_scoreGauge1), 5000);

        vm.expectRevert(bytes4(keccak256("AlreadyVoted()")));
        _gaugeController.voteForGaugeWeights(address(_scoreGauge1), 10000);

        vm.expectRevert(bytes4(keccak256("AlreadyVoted()")));
        _gaugeController.voteForGaugeWeights(address(_scoreGauge2), 10000);

        vm.expectRevert(bytes4(keccak256("TooMuchPowerUsed()")));
        _gaugeController.voteForGaugeWeights(address(_scoreGauge3), 1);

        vm.stopPrank();

        assertEq(_gaugeController.gaugeRelativeWeightWrite(address(_scoreGauge1), block.timestamp), 0, "_userVote3rdEpoch: E0");
        assertApproxEqAbs(_gaugeController.gaugeRelativeWeightWrite(address(_scoreGauge2), block.timestamp), 1e18, 1e5, "_userVote3rdEpoch: E1");
        assertEq(_gaugeController.gaugeRelativeWeightWrite(address(_scoreGauge3), block.timestamp), 0, "_userVote3rdEpoch: E2");
    }

    function _postVote3rdEpochAsserts() internal {
        assertApproxEqAbs(_gaugeController.gaugeRelativeWeightWrite(address(_scoreGauge1), block.timestamp + 1 weeks), 1e18 / 2, 1e5, "_postVote3rdEpochAsserts: E0");
        assertApproxEqAbs(_gaugeController.gaugeRelativeWeightWrite(address(_scoreGauge2), block.timestamp + 1 weeks), 1e18 / 2, 1e5, "_postVote3rdEpochAsserts: E1");
        assertEq(_gaugeController.gaugeRelativeWeightWrite(address(_scoreGauge3), block.timestamp + 1 weeks), 0, "_postVote3rdEpochAsserts: E2");
    }

    function _pre2ndEpochEndAsserts() internal {
        assertApproxEqAbs(_gaugeController.gaugeRelativeWeight(address(_scoreGauge1), block.timestamp), 1e18 / 2, 1e5, "_pre2ndEpochEndAsserts: E0");
        assertApproxEqAbs(_gaugeController.gaugeRelativeWeight(address(_scoreGauge2), block.timestamp), 1e18 / 2, 1e5, "_pre2ndEpochEndAsserts: E1");
        assertEq(_gaugeController.gaugeRelativeWeight(address(_scoreGauge3), block.timestamp), 0, "_pre2ndEpochEndAsserts: E2");

        assertApproxEqAbs(_gaugeController.gaugeRelativeWeightWrite(address(_scoreGauge1), block.timestamp), 1e18 / 2, 1e5, "_pre2ndEpochEndAsserts: E3");
        assertApproxEqAbs(_gaugeController.gaugeRelativeWeightWrite(address(_scoreGauge2), block.timestamp), 1e18 / 2, 1e5, "_pre2ndEpochEndAsserts: E4");
        assertEq(_gaugeController.gaugeRelativeWeightWrite(address(_scoreGauge3), block.timestamp), 0, "_pre2ndEpochEndAsserts: E5");
        assertTrue(_gaugeController.getTypeWeight(0) > 0, "_pre2ndEpochEndAsserts: E6");
        assertEq(_gaugeController.getTypeWeight(1), 1000000000000000000, "_pre2ndEpochEndAsserts: E7");
    }

    function _post2ndEpochEndAsserts() internal {
        assertEq(_gaugeController.epoch(), 4, "_post2ndEpochEndAsserts: E0");
        (uint256 _start, uint256 _end) = _gaugeController.epochTimeframe(3);
        assertEq(_end, block.timestamp, "_post2ndEpochEndAsserts: E1");
        assertEq(_start, block.timestamp - 1 weeks, "_post2ndEpochEndAsserts: E2");
        assertApproxEqAbs(_gaugeController.gaugeWeightForEpoch(3, address(_scoreGauge1)), 1e18 / 2, 1e5, "_post2ndEpochEndAsserts: E3");
        assertApproxEqAbs(_gaugeController.gaugeWeightForEpoch(3, address(_scoreGauge2)), 1e18 / 2, 1e5, "_post2ndEpochEndAsserts: E4");
        assertEq(_gaugeController.gaugeWeightForEpoch(3, address(_scoreGauge3)), 0, "_post2ndEpochEndAsserts: E5");
        assertTrue(_gaugeController.hasEpochEnded(1), "_post2ndEpochEndAsserts: E6");
        assertTrue(_gaugeController.hasEpochEnded(2), "_post2ndEpochEndAsserts: E7");
        assertTrue(_gaugeController.hasEpochEnded(3), "_post2ndEpochEndAsserts: E8");
        assertTrue(!_gaugeController.hasEpochEnded(4), "_post2ndEpochEndAsserts: E9");

        assertTrue(_ampl.mintableInTimeframe(_start, _end) > 20000 * 1e18, "_post2ndEpochEndAsserts: E10");

        assertApproxEqAbs(_gaugeController.gaugeRelativeWeight(address(_scoreGauge1), block.timestamp), 1e18 / 2, 1e5, "_post2ndEpochEndAsserts: E11");
        assertApproxEqAbs(_gaugeController.gaugeRelativeWeight(address(_scoreGauge2), block.timestamp), 1e18 / 2, 1e5, "_post2ndEpochEndAsserts: E12");
        assertEq(_gaugeController.gaugeRelativeWeight(address(_scoreGauge3), block.timestamp), 0, "_post2ndEpochEndAsserts: E13");
        assertTrue(_gaugeController.getTypeWeight(0) > 0, "_post2ndEpochEndAsserts: E14");
        assertEq(_gaugeController.getTypeWeight(1), 1e18, "_post2ndEpochEndAsserts: E15");
    }

    function _postMintFor3rdEpochRewardsAsserts(uint256 _dAmplBalanceBefore) internal {
        (uint256 _start, uint256 _end) = _gaugeController.epochTimeframe(3);
        uint256 _totalMintable = _ampl.mintableInTimeframe(_start, _end);
        assertEq(IERC20(address(_ampl)).balanceOf(address(_scoreGauge1)), 0, "_postMintFor3rdEpochRewardsAsserts: E0");
        assertEq(IERC20(address(_ampl)).balanceOf(address(_scoreGauge2)), 0, "_postMintFor3rdEpochRewardsAsserts: E1");
        assertEq(IERC20(address(_ampl)).balanceOf(address(_scoreGauge3)), 0, "_postMintFor3rdEpochRewardsAsserts: E2");
        assertApproxEqAbs(IERC20(address(_ampl)).balanceOf(address(_dAmpl)), _dAmplBalanceBefore + _totalMintable, 1e5, "_postMintFor3rdEpochRewardsAsserts: E3");

        vm.expectRevert(bytes4(keccak256("AlreadyMinted()")));
        _minter.mint(address(_scoreGauge1));

        vm.expectRevert(bytes4(keccak256("AlreadyMinted()")));
        _minter.mint(address(_scoreGauge2));
    }

    function _userVote4thEpoch(address _user) internal {
        vm.startPrank(_user);
        _gaugeController.voteForGaugeWeights(address(_scoreGauge2), 0);
        _gaugeController.voteForGaugeWeights(address(_scoreGauge1), 0);
        _gaugeController.voteForGaugeWeights(address(_scoreGauge3), 10000);

        vm.expectRevert(bytes4(keccak256("AlreadyVoted()")));
        _gaugeController.voteForGaugeWeights(address(_scoreGauge1), 10000);

        vm.expectRevert(bytes4(keccak256("AlreadyVoted()")));
        _gaugeController.voteForGaugeWeights(address(_scoreGauge2), 10000);

        vm.expectRevert(bytes4(keccak256("AlreadyVoted()")));
        _gaugeController.voteForGaugeWeights(address(_scoreGauge3), 10000);

        vm.stopPrank();

        assertApproxEqAbs(_gaugeController.gaugeRelativeWeightWrite(address(_scoreGauge1), block.timestamp), 1e18 / 2, 1e5, "_userVote4thEpoch: E0");
        assertApproxEqAbs(_gaugeController.gaugeRelativeWeightWrite(address(_scoreGauge2), block.timestamp), 1e18 / 2, 1e5, "_userVote4thEpoch: E1");
        assertEq(_gaugeController.gaugeRelativeWeightWrite(address(_scoreGauge3), block.timestamp), 0, "_userVote4thEpoch: E2");
    }

    function _postVote4thEpochAsserts() internal {
        assertEq(_gaugeController.gaugeRelativeWeightWrite(address(_scoreGauge1), block.timestamp + 1 weeks), 0, "_postVote4thEpochAsserts: E0");
        assertEq(_gaugeController.gaugeRelativeWeightWrite(address(_scoreGauge2), block.timestamp + 1 weeks), 0, "_postVote4thEpochAsserts: E1");
        assertApproxEqAbs(_gaugeController.gaugeRelativeWeightWrite(address(_scoreGauge3), block.timestamp + 1 weeks), 1e18, 1e5, "_postVote4thEpochAsserts: E2");
        assertEq(_gaugeController.getTypeWeight(0), 1e18, "_postVote4thEpochAsserts: E3");
        assertEq(_gaugeController.getTypeWeight(1), 1e18, "_postVote4thEpochAsserts: E4");
    }

    function _pre4thEpochEndAsserts() internal {
        assertEq(_gaugeController.gaugeRelativeWeight(address(_scoreGauge1), block.timestamp), 0, "_pre4thEpochEndAsserts: E0");
        assertEq(_gaugeController.gaugeRelativeWeight(address(_scoreGauge2), block.timestamp), 0, "_pre4thEpochEndAsserts: E1");
        assertApproxEqAbs(_gaugeController.gaugeRelativeWeight(address(_scoreGauge3), block.timestamp), 1e18, 1e5, "_pre4thEpochEndAsserts: E2");

        assertEq(_gaugeController.gaugeRelativeWeightWrite(address(_scoreGauge1), block.timestamp), 0, "_pre4thEpochEndAsserts: E3");
        assertEq(_gaugeController.gaugeRelativeWeightWrite(address(_scoreGauge2), block.timestamp), 0, "_pre4thEpochEndAsserts: E4");
        assertApproxEqAbs(_gaugeController.gaugeRelativeWeightWrite(address(_scoreGauge3), block.timestamp), 1e18, 1e5, "_pre4thEpochEndAsserts: E5");
        assertEq(_gaugeController.getTypeWeight(0), 1e18, "_pre4thEpochEndAsserts: E6");
        assertEq(_gaugeController.getTypeWeight(1), 1e18, "_pre4thEpochEndAsserts: E7");
    }

    function _post4thEpochEndAsserts() internal {
        assertEq(_gaugeController.epoch(), 5, "_post4thEpochEndAsserts: E0");
        (uint256 _start, uint256 _end) = _gaugeController.epochTimeframe(4);
        assertEq(_end, block.timestamp, "_post4thEpochEndAsserts: E1");
        assertEq(_start, block.timestamp - 1 weeks, "_post4thEpochEndAsserts: E2");
        assertEq(_gaugeController.gaugeWeightForEpoch(4, address(_scoreGauge1)), 0, "_post4thEpochEndAsserts: E3");
        assertEq(_gaugeController.gaugeWeightForEpoch(4, address(_scoreGauge2)), 0, "_post4thEpochEndAsserts: E4");
        assertApproxEqAbs(_gaugeController.gaugeWeightForEpoch(4, address(_scoreGauge3)), 1e18, 1e5, "_post4thEpochEndAsserts: E5");
        assertTrue(_gaugeController.hasEpochEnded(1), "_post4thEpochEndAsserts: E6");
        assertTrue(_gaugeController.hasEpochEnded(2), "_post4thEpochEndAsserts: E7");
        assertTrue(_gaugeController.hasEpochEnded(3), "_post4thEpochEndAsserts: E8");
        assertTrue(_gaugeController.hasEpochEnded(4), "_post4thEpochEndAsserts: E9");
        assertTrue(!_gaugeController.hasEpochEnded(5), "_post4thEpochEndAsserts: E9");

        assertTrue(_ampl.mintableInTimeframe(_start, _end) > 20000 * 1e18, "_post4thEpochEndAsserts: E10");

        assertEq(_gaugeController.gaugeRelativeWeight(address(_scoreGauge1), block.timestamp), 0, "_post4thEpochEndAsserts: E11");
        assertEq(_gaugeController.gaugeRelativeWeight(address(_scoreGauge2), block.timestamp), 0, "_post4thEpochEndAsserts: E12");
        assertApproxEqAbs(_gaugeController.gaugeRelativeWeight(address(_scoreGauge3), block.timestamp), 1e18, 1e5, "_post4thEpochEndAsserts: E13");
        assertEq(_gaugeController.getTypeWeight(0), 1e18, "_post4thEpochEndAsserts: E14");
        assertEq(_gaugeController.getTypeWeight(1), 1e18, "_post4thEpochEndAsserts: E15");
    }

    function _updateScoreGauge(ScoreGauge _scoreGauge, address _user, bool _isZero) internal {
        (uint256 _volumeGeneratedBefore, uint256 _profitBefore) = _scoreGauge.userPerformance(_gaugeController.epoch(), _user);

        (
            ,
            ,
            uint256 _totalProfitBefore,
            uint256 _totalVolumeBefore,
            ,
        ) = _scoreGauge.epochInfo(_gaugeController.epoch());

        vm.prank(address(_scoreGauge));
        _scoreGauge.updateReferrerScore(1 ether, _isZero ? 0 : 1 ether, _user);

        (
            uint256 _profitRewards,
            uint256 _volumeRewards,
            uint256 _totalProfitAfter,
            uint256 _totalVolumeAfter,
            uint256 _profitWeight,
            uint256 _volumeWeight
        ) = _scoreGauge.epochInfo(_gaugeController.epoch());

        assertEq(_scoreGauge.claimableRewards(_gaugeController.epoch(), _user), 0, "_updateScoreGauge: E0");

        assertEq(_profitRewards, 0, "_updateScoreGauge: E1");
        assertEq(_volumeRewards, 0, "_updateScoreGauge: E2");
        assertEq(_totalProfitAfter, _totalProfitBefore + (_isZero ? 0 : 1 ether), "_updateScoreGauge: E3");
        assertEq(_totalVolumeAfter, _totalVolumeBefore + 1 ether, "_updateScoreGauge: E4");

        assertEq(_profitWeight, 2000, "_updateScoreGauge: E5");
        assertEq(_volumeWeight, 8000, "_updateScoreGauge: E6");
        assertTrue(!_scoreGauge.hasClaimed(_gaugeController.epoch(), _user), "_updateScoreGauge: E7");
        _updateScoreGaugeExtension(_scoreGauge, _volumeGeneratedBefore, _profitBefore, _user, _isZero ? 0 : 1 ether);
    }

    function _updateScoreGaugeExtension(ScoreGauge _scoreGauge, uint256 _volumeGeneratedBefore, uint256 _profitBefore, address _user, uint256 _profit) internal {
        (uint256 _volumeGeneratedAfter, uint256 _profitAfter) = _scoreGauge.userPerformance(_gaugeController.epoch(), _user);
        assertEq(_volumeGeneratedBefore + 1 ether, _volumeGeneratedAfter, "_updateScoreGauge: E8");
        assertEq(_profitBefore + _profit, _profitAfter, "_updateScoreGauge: E9");
    }

    function _checkScoreGaugeTotals() internal {
        (uint256 _aliceVolumeGenerated, uint256 _aliceProfit) = _scoreGauge1.userPerformance(_gaugeController.epoch(), users.alice);
        (uint256 _bobVolumeGenerated, uint256 _bobProfit) = _scoreGauge1.userPerformance(_gaugeController.epoch(), users.bob);
        (uint256 _yossiVolumeGenerated, uint256 _yossiProfit) = _scoreGauge1.userPerformance(_gaugeController.epoch(), users.yossi);

        assertEq(_aliceVolumeGenerated, _bobVolumeGenerated, "_checkScoreGaugeTotals: E0");
        assertEq(_aliceVolumeGenerated, _yossiVolumeGenerated, "_checkScoreGaugeTotals: E1");
        assertEq(_aliceProfit, _bobProfit, "_checkScoreGaugeTotals: E2");
        assertEq(_aliceProfit, _yossiProfit, "_checkScoreGaugeTotals: E3");
    }

    function _claimForUser(ScoreGauge _scoreGauge, address _user) internal returns (uint256 _rewards) {
        uint256 _epoch = _gaugeController.epoch();
        uint256 _userBalanceBefore = _ampl.balanceOf(_user);
        uint256 _userdAmplBalanceBefore = _dAmpl.balanceOf(_user);

        {
            (uint256 _profitRewards, uint256 _volumeRewards,,,,) = _scoreGauge.epochInfo(_gaugeController.epoch() - 1);
            assertTrue(_profitRewards > 0, "_claimForUser: E1");
            assertTrue(_volumeRewards > 0, "_claimForUser: E2");
            assertEq(_profitRewards * 40 / 10, _volumeRewards, "_claimForUser: E3"); // volume gets 80% of the rewards in the current config
        }
        {
            (uint256 _profitRewards1, uint256 _volumeRewards1,,,,) = _scoreGauge.epochInfo(_gaugeController.epoch());
            assertEq(_profitRewards1, 0, "_claimForUser: E4");
            assertEq(_volumeRewards1, 0, "_claimForUser: E5");
        }

        uint256 _claimableRewards = _scoreGauge.claimableRewards(_epoch - 1, _user);

        vm.expectRevert(bytes4(keccak256("NoRewards()")));
        _scoreGauge.claim(_epoch - 1, _user);

        vm.startPrank(_user);

        uint256[] memory _epochs = new uint256[](1);
        _epochs[0] = _epoch - 1;
        (uint256 _claimedRewards, uint256[] memory _ids) = _scoreGauge.claimMany(_epochs, _user);

        vm.expectRevert(bytes4(keccak256("AlreadyClaimed()")));
        _scoreGauge.claim(_epoch - 1, _user);

        // vm.expectRevert();
        require(_scoreGauge.claimableRewards(_epoch, _user) == 0, "_claimForUser: E6");

        vm.stopPrank();

        assertEq(_scoreGauge.claimableRewards(_epoch - 1, _user), 0, "_claimForUser: E6");
        assertEq(_claimableRewards, _claimedRewards, "_claimForUser: E7");
        assertEq(_ampl.balanceOf(_user), _userBalanceBefore, "_claimForUser: E8");
        assertEq(_dAmpl.balanceOf(_user), _userdAmplBalanceBefore + 1, "_claimForUser: E9");
        assertTrue(_claimedRewards > 0, "_claimForUser: E10");

        _exersiceOption(_user, _claimedRewards, _ids);

        return _claimedRewards;
    }

    function _exersiceOption(address _user, uint256 _claimedRewards, uint256[] memory _ids) internal {
        require(_ids.length == 1, "_exersiceOption: E0");

        vm.startPrank(users.owner);
        vm.expectRevert(bytes4(keccak256("NotOwner()")));
        _dAmpl.exercise(_ids[0], _user, false);
        vm.stopPrank();

        uint256 _userBalanceBefore = _ampl.balanceOf(_user);
        uint256 _userdAmplBalanceBefore = _dAmpl.balanceOf(_user);
        uint256 _treasuryUSDCBalanceBefore = IERC20(_usdcOld).balanceOf(users.treasury);
        uint256 _amountToPay = _dAmpl.amountToPay(_ids[0]);
        uint256 _underlyingAmount = _dAmpl.amount(_ids[0]);

        _dealERC20(_usdcOld, _user, _amountToPay);
        uint256 _userUSDCBalanceBefore = IERC20(_usdcOld).balanceOf(_user);

        assertTrue(!_dAmpl.exercised(_ids[0]), "_exersiceOption: E1");

        vm.startPrank(_user);
        _approveERC20(address(_dAmpl), _usdcOld, _amountToPay);

        vm.expectRevert("Flashloan exercise not implemented yet!");
        _dAmpl.exercise(_ids[0], _user, true);

        _dAmpl.exercise(_ids[0], _user, false);

        vm.expectRevert(); // ERC721NonexistentToken(tokenId)
        _dAmpl.exercise(_ids[0], _user, false);

        vm.stopPrank();

        assertEq(_ampl.balanceOf(_user), _userBalanceBefore + _claimedRewards, "_exersiceOption: E2");
        assertEq(_ampl.balanceOf(_user), _userBalanceBefore + _underlyingAmount, "_exersiceOption: E3");
        assertEq(_dAmpl.balanceOf(_user), _userdAmplBalanceBefore - 1, "_exersiceOption: E4");
        assertEq(IERC20(_usdcOld).balanceOf(_user), _userUSDCBalanceBefore - _amountToPay, "_exersiceOption: E5");
        assertTrue(_dAmpl.exercised(_ids[0]), "_exersiceOption: E6");
        assertEq(IERC20(_usdcOld).balanceOf(users.treasury), _treasuryUSDCBalanceBefore + _amountToPay, "_exersiceOption: E7");
    }

    function _claimAndExcerciseForUser(ScoreGauge _scoreGauge, address _user) internal returns (uint256) {
        uint256 _epoch = _gaugeController.epoch();
        uint256 _userBalanceBefore = _ampl.balanceOf(_user);
        uint256 _userdAmplBalanceBefore = _dAmpl.balanceOf(_user);
        uint256 _treasuryUSDCBalanceBefore = IERC20(_usdcOld).balanceOf(users.treasury);

        uint256 _claimableRewards = _scoreGauge.claimableRewards(_epoch - 1, _user);

        uint256 _amountToPay = (_dAmpl.price() * (_dAmpl.BASE() - _dAmpl.discount()) / _dAmpl.BASE()) * _claimableRewards / 1e18; 
        _amountToPay = IERC20Metadata(_dAmpl.payWith()).decimals() == 18 ? _amountToPay : _amountToPay / 10 ** (18 - IERC20Metadata(_dAmpl.payWith()).decimals());

        _dealERC20(_usdcOld, _user, _amountToPay);
        uint256 _userUSDCBalanceBefore = IERC20(_usdcOld).balanceOf(_user);

        {
            (uint256 _profitRewards, uint256 _volumeRewards,,,,) = _scoreGauge.epochInfo(_gaugeController.epoch() - 1);
            assertTrue(_profitRewards > 0, "_claimForUser: E1");
            assertTrue(_volumeRewards > 0, "_claimForUser: E2");
            assertEq(_profitRewards * 40 / 10, _volumeRewards, "_claimForUser: E3"); // volume gets 80% of the rewards in the current config
        }
        {
            (uint256 _profitRewards1, uint256 _volumeRewards1,,,,) = _scoreGauge.epochInfo(_gaugeController.epoch());
            assertEq(_profitRewards1, 0, "_claimForUser: E4");
            assertEq(_volumeRewards1, 0, "_claimForUser: E5");
        }

        vm.expectRevert(bytes4(keccak256("NoRewards()")));
        _scoreGauge.claim(_epoch - 1, _user);

        vm.startPrank(_user);

        if (_dAmpl.discount() == 100) {
            require(_amountToPay == 0, "_claimAndExcerciseForUser: amountToPay should be 0");
        } else {
            _approveERC20(address(_scoreGauge), _dAmpl.payWith(), _amountToPay);
        }

        uint256[] memory _epochs = new uint256[](1);
        _epochs[0] = _epoch - 1;
        (uint256 _claimedRewards, uint256[] memory _ids) = _scoreGauge.claimAndExcerciseMany(_epochs, _user, false);

        vm.expectRevert(bytes4(keccak256("AlreadyClaimed()")));
        _scoreGauge.claim(_epoch - 1, _user);

        require(_scoreGauge.claimableRewards(_epoch, _user) == 0, "_claimForUser: E6");

        vm.stopPrank();

        assertEq(_scoreGauge.claimableRewards(_epoch - 1, _user), 0, "_claimForUser: E6");
        assertEq(_claimableRewards, _claimedRewards, "_claimForUser: E7");
        assertEq(_ampl.balanceOf(_user), _userBalanceBefore + _claimedRewards, "_claimForUser: E8");
        assertEq(_dAmpl.balanceOf(_user), _userdAmplBalanceBefore, "_claimForUser: E9");
        assertTrue(_claimedRewards > 0, "_claimForUser: E10");

        assertEq(_ampl.balanceOf(_user), _userBalanceBefore + _claimableRewards, "_exersiceOption: E3");
        assertEq(IERC20(_usdcOld).balanceOf(_user), _userUSDCBalanceBefore - _amountToPay, "_exersiceOption: E5");
        assertTrue(_dAmpl.exercised(_ids[0]), "_exersiceOption: E6");
        assertEq(IERC20(_usdcOld).balanceOf(users.treasury), _treasuryUSDCBalanceBefore + _amountToPay, "_exersiceOption: E7");

        return _claimedRewards;
    }

    function _claimExcerciseAndLockForUser(ScoreGauge _scoreGauge, address _user) internal returns (uint256) {
        uint256 _epoch = _gaugeController.epoch();
        // uint256 _userBalanceBefore = _ampl.balanceOf(_user);
        uint256 _userdAmplBalanceBefore = _dAmpl.balanceOf(_user);
        uint256 _treasuryUSDCBalanceBefore = IERC20(_usdcOld).balanceOf(users.treasury);
        uint256 _userVePuppetBefore = _votingEscrow.balanceOf(_user, block.timestamp);
        uint256 _userLockedAmountBefore = _votingEscrow.lockedAmount(_user);

        uint256 _claimableRewards = _scoreGauge.claimableRewards(_epoch - 1, _user);

        uint256 _amountToPay = (_dAmpl.price() * (_dAmpl.BASE() - _dAmpl.discount()) / _dAmpl.BASE()) * _claimableRewards / 1e18; 
        _amountToPay = IERC20Metadata(_dAmpl.payWith()).decimals() == 18 ? _amountToPay : _amountToPay / 10 ** (18 - IERC20Metadata(_dAmpl.payWith()).decimals());

        _dealERC20(_usdcOld, _user, _amountToPay);
        uint256 _userUSDCBalanceBefore = IERC20(_usdcOld).balanceOf(_user);

        {
            (uint256 _profitRewards, uint256 _volumeRewards,,,,) = _scoreGauge.epochInfo(_gaugeController.epoch() - 1);
            assertTrue(_profitRewards > 0, "_claimExcerciseAndLockForUser: E1");
            assertTrue(_volumeRewards > 0, "_claimExcerciseAndLockForUser: E2");
            assertEq(_profitRewards * 40 / 10, _volumeRewards, "_claimExcerciseAndLockForUser: E3"); // volume gets 80% of the rewards in the current config
        }
        {
            (uint256 _profitRewards1, uint256 _volumeRewards1,,,,) = _scoreGauge.epochInfo(_gaugeController.epoch());
            assertEq(_profitRewards1, 0, "_claimExcerciseAndLockForUser: E4");
            assertEq(_volumeRewards1, 0, "_claimExcerciseAndLockForUser: E5");
        }

        vm.expectRevert(bytes4(keccak256("NoRewards()")));
        _scoreGauge.claim(_epoch - 1, _user);

        vm.startPrank(_user);

        if (_dAmpl.discount() == 100) {
            require(_amountToPay == 0, "_claimExcerciseAndLockForUser: amountToPay should be 0");
        } else {
            _approveERC20(address(_scoreGauge), _dAmpl.payWith(), _amountToPay);
        }

        uint256 _claimedRewards;
        uint256[] memory _ids = new uint256[](1);
        {
            uint256[] memory _epochs = new uint256[](1);
            _epochs[0] = _epoch - 1;

            (_claimedRewards, _ids) = _scoreGauge.claimExcerciseAndLockMany(
                _epochs,
                0, // _unlockTime (user already have an active lock)
                false // _useFlashLoan
            );

            // // addLiquidityOneToken
            // (_claimedRewards, _ids) = _scoreGauge.claimExcerciseAndLockMany(
            //     _epochs,
            //     0, // _unlockTime (user already have an active lock)
            //     false, // _useFlashLoan
            // );
        }

        vm.expectRevert(bytes4(keccak256("AlreadyClaimed()")));
        _scoreGauge.claim(_epoch - 1, _user);

        require(_scoreGauge.claimableRewards(_epoch, _user) == 0, "_claimExcerciseAndLockForUser: E6");

        vm.stopPrank();

        assertEq(_scoreGauge.claimableRewards(_epoch - 1, _user), 0, "_claimExcerciseAndLockForUser: E7");
        // assertEq(_claimableRewards, _claimedRewards, "_claimForUser: E7");
        // assertEq(_ampl.balanceOf(_user), _userBalanceBefore, "_claimExcerciseAndLockForUser: E8");
        assertEq(_dAmpl.balanceOf(_user), _userdAmplBalanceBefore, "_claimExcerciseAndLockForUser: E9");
        assertTrue(_claimableRewards > 0, "_claimExcerciseAndLockForUser: E10");

        assertEq(IERC20(_usdcOld).balanceOf(_user), _userUSDCBalanceBefore - _amountToPay, "_claimExcerciseAndLockForUser: E10");
        assertTrue(_dAmpl.exercised(_ids[0]), "_claimExcerciseAndLockForUser: E11");
        assertEq(IERC20(_usdcOld).balanceOf(users.treasury), _treasuryUSDCBalanceBefore + _amountToPay, "_claimExcerciseAndLockForUser: E12");
        assertTrue(_votingEscrow.balanceOf(_user, block.timestamp) > _userVePuppetBefore, "_claimExcerciseAndLockForUser: E13");
        assertEq(_votingEscrow.lockedAmount(_user), _userLockedAmountBefore + _claimedRewards, "_claimExcerciseAndLockForUser: E14");
        assertEq(_votingEscrow.balanceOf(address(_scoreGauge), block.timestamp), 0, "_claimExcerciseAndLockForUser: E15");
        assertEq(_votingEscrow.lockedAmount(address(_scoreGauge)), 0, "_claimExcerciseAndLockForUser: E16");

        return _claimableRewards;
    }

    function _refundOptions(ScoreGauge _scoreGauge, address _user) internal {
        uint256 _epoch = _gaugeController.epoch();
        uint256 _claimableRewards = _scoreGauge.claimableRewards(_epoch - 1, _user);
        uint256 _treasuryPuppetBalanceBefore = _ampl.balanceOf(users.treasury);
        uint256 _treasuryUSDBalanceBefore = IERC20(_dAmpl.payWith()).balanceOf(users.treasury);
        uint256 _userUSDBalanceBefore = IERC20(_dAmpl.payWith()).balanceOf(_user);

        assertTrue(_claimableRewards > 0, "_refundOptions: E0");

        vm.startPrank(_user);

        uint256[] memory _epochs = new uint256[](1);
        _epochs[0] = _epoch - 1;
        (uint256 _claimedRewards, uint256[] memory _ids) = _scoreGauge.claimMany(_epochs, _user);
        uint256 _id = _ids[0];

        assertEq(_claimableRewards, _claimedRewards, "_refundOptions: E1");
        assertTrue(!_dAmpl.exercised(_id), "_refundOptions: E2");
        assertTrue(_dAmpl.expiry(_id) > block.timestamp, "_refundOptions: E3");
        assertEq(_dAmpl.refund(_ids), 0, "_refundOptions: E4");

        skip(_dAmpl.expiry(_id) - block.timestamp + 1); // skip to after expiry

        assertTrue(_dAmpl.expiry(_id) < block.timestamp, "_refundOptions: E5");

        vm.expectRevert(bytes4(keccak256("Expired()")));
        _dAmpl.exercise(_id, _user, false);

        assertEq(_dAmpl.refund(_ids), _claimableRewards, "_refundOptions: E6");
        assertEq(_ampl.balanceOf(users.treasury), _treasuryPuppetBalanceBefore + _claimableRewards, "_refundOptions: E7");
        assertEq(IERC20(_dAmpl.payWith()).balanceOf(_user), _userUSDBalanceBefore, "_refundOptions: E8");
        assertEq(IERC20(_dAmpl.payWith()).balanceOf(users.treasury), _treasuryUSDBalanceBefore, "_refundOptions: E9");
    }

    function _postClaimRewardsAsserts(uint256 _aliceClaimedRewards, uint256 _bobClaimedRewards, uint256 _yossiClaimedRewards) internal {
        assertEq(_ampl.balanceOf(address(_scoreGauge1)), 0, "_postClaimRewardsAsserts: E0");
        assertEq(_aliceClaimedRewards, _bobClaimedRewards, "_postClaimRewardsAsserts: E1");
        assertEq(_aliceClaimedRewards, _yossiClaimedRewards, "_postClaimRewardsAsserts: E2");
    }

    function _depositToRevenueDistributer() internal {
        vm.startPrank(users.alice);
        IERC20(_weth).transfer(users.keeper, IERC20(_weth).balanceOf(users.alice)); // reset alice balance
        require(IERC20(_weth).balanceOf(users.alice) == 0, "_depositToRevenueDistributer: E0");
        vm.stopPrank();

        _dealERC20(_weth, users.alice, 100);

        vm.prank(users.owner);
        _revenueDistributer.checkpointToken();

        assertEq(IERC20(_weth).balanceOf(address(_revenueDistributer)), 0, "_depositToRevenueDistributer: E0");
        vm.startPrank(users.alice);
        _approveERC20(address(_revenueDistributer), _weth, 100 ether);
        _revenueDistributer.burn();
        assertEq(IERC20(_weth).balanceOf(address(_revenueDistributer)), 100 ether, "_depositToRevenueDistributer: E1");
        assertEq(_revenueDistributer.totalReceived(), 100 ether, "_depositToRevenueDistributer: E2");
        vm.stopPrank();
    }

    function _claimRevenueDistributerRewards() internal {
        uint256 _aliceBalanceBefore = IERC20(_weth).balanceOf(users.alice);
        uint256 _bobBalanceBefore = IERC20(_weth).balanceOf(users.bob);
        uint256 _yossiBalanceBefore = address(users.yossi).balance;
        uint256 _totalRewards = 100 ether;
        uint256 _rewardsForUser = _totalRewards / uint256(3);

        skip(1 weeks);
        
        // claim for alice
        vm.startPrank(users.alice);
        uint256 _aliceClaimed1 = _revenueDistributer.claim(users.alice, false);
        assertEq(_aliceClaimed1, IERC20(_weth).balanceOf(users.alice) - _aliceBalanceBefore, "_claimRevenueDistributerRewards: E0");
        assertEq(_revenueDistributer.tokenLastBalance(), _totalRewards - _aliceClaimed1, "_claimRevenueDistributerRewards: E01");
        vm.stopPrank();

        // claim for bob
        vm.startPrank(users.bob);
        uint256 _bobClaimed1 = _revenueDistributer.claimMany(users.bob, false);
        assertEq(_bobClaimed1, IERC20(_weth).balanceOf(users.bob) - _bobBalanceBefore, "_claimRevenueDistributerRewards: E1");
        assertEq(_revenueDistributer.tokenLastBalance(), _totalRewards - _aliceClaimed1 - _bobClaimed1, "_claimRevenueDistributerRewards: E11");
        vm.stopPrank();

        skip(1 weeks);

        // claim for alice
        vm.startPrank(users.alice);
        uint256 _aliceClaimed2 = _revenueDistributer.claimMany(users.alice, false);
        assertEq(_aliceClaimed2, IERC20(_weth).balanceOf(users.alice) - _aliceBalanceBefore - _aliceClaimed1, "_claimRevenueDistributerRewards: E3");
        vm.stopPrank();

        // claim for bob
        vm.startPrank(users.bob);
        uint256 _bobClaimed2 = _revenueDistributer.claim(users.bob, false);
        assertEq(_bobClaimed2, IERC20(_weth).balanceOf(users.bob) - _bobBalanceBefore - _bobClaimed1, "_claimRevenueDistributerRewards: E4");
        vm.stopPrank();

        // claim for yossi
        vm.startPrank(users.yossi);
        uint256 _yossiClaimed = _revenueDistributer.claim(users.yossi, true);
        assertEq(_yossiClaimed, address(users.yossi).balance - _yossiBalanceBefore, "_claimRevenueDistributerRewards: E5");
        vm.stopPrank();

        assertApproxEqAbs(_revenueDistributer.tokenLastBalance(), 0, 1e2, "_claimRevenueDistributerRewards: E6");
        assertEq(_revenueDistributer.totalReceived(), 100 ether, "_claimRevenueDistributerRewards: E7");
        assertApproxEqAbs(IERC20(_weth).balanceOf(address(_revenueDistributer)), 0, 1e5, "_claimRevenueDistributerRewards: E8");
        assertApproxEqAbs(_aliceClaimed1 + _aliceClaimed2, _rewardsForUser, 1e5, "_claimRevenueDistributerRewards: E9");
        assertApproxEqAbs(_bobClaimed1 + _bobClaimed2, _rewardsForUser, 1e5, "_claimRevenueDistributerRewards: E10");
        assertApproxEqAbs(_yossiClaimed, _rewardsForUser, 1e5, "_claimRevenueDistributerRewards: E11");
    }
}