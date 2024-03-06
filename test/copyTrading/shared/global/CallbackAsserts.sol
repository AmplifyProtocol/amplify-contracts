// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {LibDataTypes} from "@gelato/libraries/LibDataTypes.sol";
import {LibTaskId} from "@gelato/libraries/LibTaskId.sol";
import {IAutomate} from "@gelato/interfaces/IAutomate.sol";

import {IPositionHandler} from "../interfaces/IPositionHandler.sol";

import "../BaseHelper.t.sol";

contract CallbackAsserts is BaseHelper {

    struct BeforeData {
        uint256 aliceDepositAccountBalanceBefore;
        uint256 orchestratorEthBalanceBefore;
        uint256 executionFeeBalanceBefore;
        uint256 volumeGeneratedBefore;
        uint256 traderSharesBefore;
        uint256 traderLastAmountIn;
        uint256 traderETHBalanceBefore;
        uint256 traderCollateralTokenBalanceBefore;
        uint256 orchestratorCollateralTokenBalanceBefore;
        address trader;
        bool isIncrease;
        bytes32 routeKey;
    }

    // ============================================================================================
    // Test Functions
    // ============================================================================================

    function postSuccessfulExecution(Context memory _context, BeforeData memory _beforeData) external {
        bytes32 _routeKey = _beforeData.routeKey;
        address _route = IDataStore(_context.dataStore).getAddress(Keys.routeAddressKey(_routeKey));

        assertTrue(!IBaseOrchestrator(_context.orchestrator).isWaitingForCallback(_routeKey), "postSuccessfulExecution: E1");
        assertTrue(!RouteReader.isWaitingForCallback(_context.dataStore, _route), "requestPositionERC20: E01");

        uint256 _positionIndex = IDataStore(_context.dataStore).getUint(Keys.positionIndexKey(_route));
        address _collateralToken = IDataStore(_context.dataStore).getAddress(Keys.routeCollateralTokenKey(_route));
        if (_route.balance > 0) {
            // GMXV2 sends unused execution fees AFTER calling the callback
            assertEq(_route.balance, _context.executionFee, "postSuccessfulExecution: E2");
            if (_beforeData.isIncrease && !_context.expectations.isExpectingNonZeroBalance) {
                assertEq(IERC20(_collateralToken).balanceOf(_beforeData.trader), _beforeData.traderCollateralTokenBalanceBefore, "postSuccessfulExecution: E04");
            }
        } else {
            // GMXV1 sends unused execution fees BEFORE calling the callback
            // unused execution fees are sent to the Trader as WETH
            assertEq(address(_context.orchestrator).balance, _beforeData.orchestratorEthBalanceBefore, "postSuccessfulExecution: E3");
            assertEq(_context.dataStore.getUint(Keys.EXECUTION_FEE_BALANCE), _beforeData.executionFeeBalanceBefore, "postSuccessfulExecution: E4");
            if (_beforeData.isIncrease && !_context.expectations.isGMXV1) {
                assertEq(IERC20(_collateralToken).balanceOf(_beforeData.trader) - _context.executionFee, _beforeData.traderCollateralTokenBalanceBefore, "postSuccessfulExecution: E05");
            }
        }

        assertEq(IDataStore(_context.dataStore).getBytes32(Keys.pendingRequestKey(_positionIndex, _route)), bytes32(0), "postSuccessfulExecution: E06");
        assertEq(IERC20(IDataStore(_context.dataStore).getAddress(Keys.routeCollateralTokenKey(_route))).balanceOf(_route), 0, "postSuccessfulExecution: E5");

        if (_beforeData.isIncrease) {
            assertTrue(IDataStore(_context.dataStore).getUint(Keys.cumulativeVolumeGeneratedKey(_positionIndex, _route)) > _beforeData.volumeGeneratedBefore, "postSuccessfulExecution: E6");
            assertTrue(IDataStore(_context.dataStore).getInt(Keys.traderPnLKey(_positionIndex, _route)) != 0, "postSuccessfulExecution: E7");
            assertTrue(IDataStore(_context.dataStore).getUint(Keys.positionTraderSharesKey(_positionIndex, _route)) > _beforeData.traderSharesBefore, "postSuccessfulExecution: E8");
            assertTrue(IDataStore(_context.dataStore).getBool(Keys.isPositionOpenKey(_route)), "postSuccessfulExecution: E9");
            assertTrue(IDataStore(_context.dataStore).getUint(Keys.positionTotalAssetsKey(_positionIndex, _route)) > 0, "postSuccessfulExecution: E10");
            assertTrue(IDataStore(_context.dataStore).getUint(Keys.positionTotalAssetsKey(_positionIndex, _route)) > 0, "postSuccessfulExecution: E11");
            assertEq(_beforeData.trader.balance, _beforeData.traderETHBalanceBefore, "postSuccessfulExecution: E12");
            if (_beforeData.traderLastAmountIn != 0) {
                if (_context.expectations.isArtificialExecution && !_context.expectations.isExpectingAdjustment) {
                    assertEq(IDataStore(_context.dataStore).getUint(Keys.positionLastTraderAmountInKey(_positionIndex, _route)), _beforeData.traderLastAmountIn, "postSuccessfulExecution: E14");
                } else {
                    assertTrue(IDataStore(_context.dataStore).getUint(Keys.positionLastTraderAmountInKey(_positionIndex, _route)) != _beforeData.traderLastAmountIn, "postSuccessfulExecution: E15");
                    assertTrue(IDataStore(_context.dataStore).getUint(Keys.positionLastTraderAmountInKey(_positionIndex, _route)) != 0, "postSuccessfulExecution: E16");
                }
            }
            if (!_context.expectations.isExpectingNonZeroBalance) {
                assertEq(IERC20(_collateralToken).balanceOf(address(_context.orchestrator)), _beforeData.orchestratorCollateralTokenBalanceBefore, "postSuccessfulExecution: E18");
            }
            if (_context.expectations.isPuppetsSubscribed || _context.expectations.isExpectingAdjustment) {
                _postSuccessfulIncreaseExecutionPuppetsSubscribed(
                    _context,
                    _positionIndex,
                    _routeKey
                );
            }
        } else {
            _postSuccessfulDecreaseExecution(_context, _beforeData);
        }
    }

    function postFailedExecution(Context memory _context, BeforeData memory _beforeData) external {
        bytes32 _routeKey = _beforeData.routeKey;
        address _route = IDataStore(_context.dataStore).getAddress(Keys.routeAddressKey(_routeKey));

        assertTrue(!IBaseOrchestrator(_context.orchestrator).isWaitingForCallback(_routeKey), "postFailedExecution: E2");
        assertTrue(!RouteReader.isWaitingForCallback(_context.dataStore, _route), "postFailedExecution: E02");

        address _collateralToken = IDataStore(_context.dataStore).getAddress(Keys.routeCollateralTokenKey(_route));
        if (_route.balance > 0) {
            // GMXV2 sends unused execution fees AFTER calling the callback
            assertEq(_route.balance, _context.executionFee, "postFailedExecution: E3");
        } else {
            // GMXV1 sends unused execution fees BEFORE calling the callback
            // unused execution fees are sent to the Trader as WETH
            assertEq(address(_context.orchestrator).balance, _beforeData.orchestratorEthBalanceBefore, "postFailedExecution: E4");
            assertEq(_context.dataStore.getUint(Keys.EXECUTION_FEE_BALANCE), _beforeData.executionFeeBalanceBefore, "postFailedExecution: E5");
        }
        assertEq(IERC20(IDataStore(_context.dataStore).getAddress(Keys.routeCollateralTokenKey(_route))).balanceOf(_route), 0, "postFailedExecution: E6");

        uint256 _positionIndex = IDataStore(_context.dataStore).getUint(Keys.positionIndexKey(_route));
        assertEq(IDataStore(_context.dataStore).getBytes32(Keys.pendingRequestKey(_positionIndex, _route)), bytes32(0), "postFailedExecution: E06");
        assertEq(IDataStore(_context.dataStore).getUint(Keys.cumulativeVolumeGeneratedKey(_positionIndex, _route)), _beforeData.volumeGeneratedBefore, "postFailedExecution: E7");
        assertEq(IDataStore(_context.dataStore).getUint(Keys.positionTraderSharesKey(_positionIndex, _route)), _beforeData.traderSharesBefore, "postFailedExecution: E8");
        assertEq(IDataStore(_context.dataStore).getUint(Keys.positionLastTraderAmountInKey(_positionIndex, _route)), _beforeData.traderLastAmountIn, "postFailedExecution: E9");
        assertTrue(!IDataStore(_context.dataStore).getBool(Keys.isPositionOpenKey(_route)), "postFailedExecution: E10");
        assertEq(IDataStore(_context.dataStore).getUint(Keys.positionTotalAssetsKey(_positionIndex, _route)), 0, "postFailedExecution: E11");
        assertEq(IDataStore(_context.dataStore).getUint(Keys.positionTotalAssetsKey(_positionIndex, _route)), 0, "postFailedExecution: E12");

        assertTrue(IERC20(IDataStore(_context.dataStore).getAddress(Keys.routeCollateralTokenKey(_route))).balanceOf(_beforeData.trader) > _beforeData.traderCollateralTokenBalanceBefore, "postFailedExecution: E13");

        assertEq(_beforeData.trader.balance, _beforeData.traderETHBalanceBefore, "postFailedExecution: E14");

        if (_context.expectations.isPuppetsSubscribed) {
            assertTrue(IERC20(IDataStore(_context.dataStore).getAddress(Keys.routeCollateralTokenKey(_route))).balanceOf(address(_context.orchestrator)) > _beforeData.orchestratorCollateralTokenBalanceBefore, "postFailedExecution: E18");
            if (_beforeData.isIncrease) {
                assertTrue(_beforeData.aliceDepositAccountBalanceBefore < CommonHelper.puppetAccountBalance(_context.dataStore, _context.users.alice, _collateralToken), "postFailedExecution: E19");
            }
        } else {
            assertEq(IERC20(IDataStore(_context.dataStore).getAddress(Keys.routeCollateralTokenKey(_route))).balanceOf(address(_context.orchestrator)), _beforeData.orchestratorCollateralTokenBalanceBefore, "postFailedExecution: E20");
            assertEq(_beforeData.aliceDepositAccountBalanceBefore, CommonHelper.puppetAccountBalance(_context.dataStore, _context.users.alice, _collateralToken), "postFailedExecution: E19");
        }
    }

    // ============================================================================================
    // Internal Helpers
    // ============================================================================================

    function _postSuccessfulIncreaseExecutionPuppetsSubscribed(
        Context memory _context,
        uint256 _positionIndex,
        bytes32 _routeKey
    ) internal {
        address _route = IDataStore(_context.dataStore).getAddress(Keys.routeAddressKey(_routeKey));
        {
            uint256[] memory _lastPuppetsAmountsIn = IDataStore(_context.dataStore).getUintArray(Keys.positionLastPuppetsAmountsInKey(_positionIndex, _route));
            for (uint256 i = 0; i < _lastPuppetsAmountsIn.length; i++) {
                assertTrue(_lastPuppetsAmountsIn[i] > 0, "_postSuccessfulIncreaseExecutionPuppetsSubscribed: E1");
            }
        }
        address _alice = _context.users.alice;
        address _bob = _context.users.bob;
        address _yossi = _context.users.yossi;
        bytes32 _routeType = IDataStore(_context.dataStore).getBytes32(Keys.routeRouteTypeKey(_route));
        if (_context.expectations.isExpectingAdjustment) {
            if (_context.expectations.isPuppetsSubscribed) {
                assertEq(IDataStore(_context.dataStore).getUint(Keys.puppetLastPositionOpenedTimestampKey(_alice, _routeType)), block.timestamp, "_postSuccessfulIncreaseExecutionPuppetsSubscribed: E2");
                assertEq(IDataStore(_context.dataStore).getUint(Keys.puppetLastPositionOpenedTimestampKey(_bob, _routeType)), block.timestamp, "_postSuccessfulIncreaseExecutionPuppetsSubscribed: E3");
                assertEq(IDataStore(_context.dataStore).getUint(Keys.puppetLastPositionOpenedTimestampKey(_yossi, _routeType)), block.timestamp, "_postSuccessfulIncreaseExecutionPuppetsSubscribed: E4");
            } else {
                assertEq(IDataStore(_context.dataStore).getUint(Keys.puppetLastPositionOpenedTimestampKey(_alice, _routeType)), block.timestamp - 25 hours, "_postSuccessfulIncreaseExecutionPuppetsSubscribed: E5");
                assertEq(IDataStore(_context.dataStore).getUint(Keys.puppetLastPositionOpenedTimestampKey(_bob, _routeType)), block.timestamp - 25 hours, "_postSuccessfulIncreaseExecutionPuppetsSubscribed: E6");
                assertEq(IDataStore(_context.dataStore).getUint(Keys.puppetLastPositionOpenedTimestampKey(_yossi, _routeType)), block.timestamp - 25 hours, "_postSuccessfulIncreaseExecutionPuppetsSubscribed: E7");
            }

            assertTrue(IDataStore(_context.dataStore).getBool(Keys.isWaitingForKeeperAdjustmentKey(_route)), "_postSuccessfulIncreaseExecutionPuppetsSubscribed: E8");
            assertTrue(IDataStore(_context.dataStore).getBool(Keys.isKeeperAdjustmentEnabledKey(_route)), "_postSuccessfulIncreaseExecutionPuppetsSubscribed: E08");
            assertTrue(IDataStore(_context.dataStore).getUint(Keys.targetLeverageKey(_route)) > 0, "_postSuccessfulIncreaseExecutionPuppetsSubscribed: E9");
            assertTrue(DecreaseSizeResolver(_context.decreaseSizeResolver).requiredAdjustmentSize(_route) > 0, "_postSuccessfulIncreaseExecutionPuppetsSubscribed: E10");

            IBaseRoute.AdjustPositionParams memory _adjustPositionParams;
            {
                (bool _canExec, bytes memory _execPayload) = DecreaseSizeResolver(_context.decreaseSizeResolver).checker();
                assertTrue(_canExec, "_postSuccessfulIncreaseExecutionPuppetsSubscribed: E11");

                uint256 _executionFee;
                bytes32 _routeKeyFromResolver;
                (_adjustPositionParams, _executionFee, _routeKeyFromResolver) = _decodeResolverData(_execPayload);
                assertEq(_routeKey, _routeKey, "_postSuccessfulIncreaseExecutionPuppetsSubscribed: E12");
                assertEq(_executionFee, _context.executionFee, "_postSuccessfulIncreaseExecutionPuppetsSubscribed: E13");
                assertEq(_routeKeyFromResolver, _routeKey, "_postSuccessfulIncreaseExecutionPuppetsSubscribed: E14");
            }

            {
                address[] memory _path = new address[](1);
                _path[0] = _weth;
                IBaseRoute.SwapParams memory _swapParams = IBaseRoute.SwapParams({
                    path: _path,
                    amount: 0,
                    minOut: 0
                });

                IBaseRoute.ExecutionFees memory _executionFees = IBaseRoute.ExecutionFees({
                    dexKeeper: _context.executionFee,
                    puppetKeeper: _context.expectations.isExpectingAdjustment ? _context.executionFee : 0
                });

                vm.startPrank(_context.users.trader);
                bytes32 _routeTypeKey = _context.longETHRouteTypeKey;
                vm.expectRevert(bytes4(keccak256("WaitingForKeeperAdjustment()")));
                IBaseOrchestrator(_context.orchestrator).requestPosition{ value: _context.expectations.isExpectingAdjustment ? _context.executionFee * 2 : _context.executionFee }(_adjustPositionParams, _swapParams, _executionFees, _routeTypeKey, true);
                vm.stopPrank();
            }

            assertTrue(DecreaseSizeResolver(_context.decreaseSizeResolver).requiredAdjustmentSize(_route) > 0, "_postSuccessfulIncreaseExecutionPuppetsSubscribed: E15");
            assertTrue(!IBaseOrchestrator(_context.orchestrator).isWaitingForCallback(_routeKey), "_postSuccessfulIncreaseExecutionPuppetsSubscribed: E16");
            assertTrue(IDataStore(_context.dataStore).getBool(Keys.isWaitingForKeeperAdjustmentKey(_route)), "_postSuccessfulIncreaseExecutionPuppetsSubscribed: E17");

            _executeKeeperAdjustmentRequest(_context, _routeKey);

            assertTrue(IBaseOrchestrator(_context.orchestrator).isWaitingForCallback(_routeKey), "_postSuccessfulIncreaseExecutionPuppetsSubscribed: E18");
            assertTrue(IDataStore(_context.dataStore).getBool(Keys.isWaitingForKeeperAdjustmentKey(_route)), "_postSuccessfulIncreaseExecutionPuppetsSubscribed: E19");
            assertTrue(!IDataStore(_context.dataStore).getBool(Keys.isKeeperAdjustmentEnabledKey(_route)), "_postSuccessfulIncreaseExecutionPuppetsSubscribed: E019");
        } else {
            assertTrue(!IDataStore(_context.dataStore).getBool(Keys.isWaitingForKeeperAdjustmentKey(_route)), "_postSuccessfulIncreaseExecutionPuppetsSubscribed: E20");
            assertEq(IDataStore(_context.dataStore).getUint(Keys.targetLeverageKey(_route)), 0, "_postSuccessfulIncreaseExecutionPuppetsSubscribed: E21");
            assertEq(DecreaseSizeResolver(_context.decreaseSizeResolver).requiredAdjustmentSize(_route), 0, "_postSuccessfulIncreaseExecutionPuppetsSubscribed: E22");
            (bool _canExec,) = DecreaseSizeResolver(_context.decreaseSizeResolver).checker();
            assertTrue(!_canExec, "_postSuccessfulIncreaseExecutionPuppetsSubscribed: E23");
        }
    }

    function _decodeResolverData(bytes memory _data) internal pure returns (IBaseRoute.AdjustPositionParams memory, uint256, bytes32) {
        // Verify the function selector
        bytes4 _selector;
        assembly {
            _selector := mload(add(_data, 32))
        }
        require(_selector == IBaseOrchestrator.decreaseSize.selector, "_decodeResolverData: Invalid selector");

        // Create a new bytes memory array for the sliced data
        bytes memory _slicedData = new bytes(_data.length - 4);
        for (uint i = 4; i < _data.length; i++) {
            _slicedData[i - 4] = _data[i];
        }

        // Decode the data
        IBaseRoute.AdjustPositionParams memory _params;
        uint256 _executionFee;
        bytes32 _routeKey;

        (_params, _executionFee, _routeKey) = abi.decode(_slicedData, (IBaseRoute.AdjustPositionParams, uint256, bytes32));

        return (_params, _executionFee, _routeKey);
    }

    function _executeKeeperAdjustmentRequest(Context memory _context, bytes32 _routeKey) internal {
        require(DecreaseSizeResolver(_context.decreaseSizeResolver).taskId() != bytes32(0), "_executeKeeperAdjustmentRequest: E1");

        (bool _canExec, bytes memory _execPayload) = DecreaseSizeResolver(_context.decreaseSizeResolver).checker();
        assertTrue(_canExec, "_executeKeeperAdjustmentRequest: E2");

        LibDataTypes.ModuleData memory _moduleData = LibDataTypes.ModuleData({
            modules: new LibDataTypes.Module[](2),
            args: new bytes[](2)
        });

        _moduleData.modules[0] = LibDataTypes.Module.RESOLVER;
        _moduleData.modules[1] = LibDataTypes.Module.PROXY;

        _moduleData.args[0] = abi.encode(
            _context.decreaseSizeResolver,
            abi.encodeCall(DecreaseSizeResolver(_context.decreaseSizeResolver).checker, ())
        );

        _moduleData.args[1] = bytes("");

        bytes32 _taskId = LibTaskId.getTaskId(
            _context.decreaseSizeResolver,
            address(_context.orchestrator),
            IBaseOrchestrator.decreaseSize.selector,
            _moduleData,
            _eth
        );
        assertEq(_taskId, DecreaseSizeResolver(_context.decreaseSizeResolver).taskId(), "_executeKeeperAdjustmentRequest: E3");
        assertTrue(_taskId != bytes32(0), "_executeKeeperAdjustmentRequest: E4");

        address _route = CommonHelper.routeAddress(_context.dataStore, _routeKey);
        uint256 _positionIndex = IDataStore(_context.dataStore).getUint(Keys.positionIndexKey(_route));
        assertEq(_context.dataStore.getBytes32(Keys.pendingRequestKey(_positionIndex, _route)), bytes32(0), "_executeKeeperAdjustmentRequest: E5");

        vm.prank(_gelatoAutomationCallerArbi);
        IAutomate(_gelatoAutomationArbi).exec(
            _context.decreaseSizeResolver, // taskCreator
            address(_context.orchestrator), // execAddress
            _execPayload,
            _moduleData,
            0.1 ether, // txFee
            _eth, // feeToken
            // false, // useTaskTreasuryFunds (If taskCreator's balance on TaskTreasury should pay for the tx.)
            true // revertOnFailure
        );

        assertTrue(_context.dataStore.getBytes32(Keys.pendingRequestKey(_positionIndex, _route)) != bytes32(0), "_executeKeeperAdjustmentRequest: E6");

        if (_context.expectations.isUsingMocks) {
            // add request key to order list
            IDataStore _dataStoreInstance = _context.dataStore;
            bytes32 _requestKey = _dataStoreInstance.getBytes32(Keys.pendingRequestKey(_positionIndex, _route));
            bytes32 _orderListKey = keccak256(
                abi.encode(keccak256(abi.encode("ACCOUNT_ORDER_LIST")),
                _route)
            );
            GMXV2RouteHelper.gmxDataStore(_dataStoreInstance).addBytes32(_orderListKey, _requestKey);
        }
    }

    function _postSuccessfulDecreaseExecution(Context memory _context, BeforeData memory _beforeData) internal {
        IDataStore _dataStoreInstance = IDataStore(_context.dataStore);
        bytes32 _routeKey = _beforeData.routeKey;
        address _route = _dataStoreInstance.getAddress(Keys.routeAddressKey(_routeKey));

        {
            uint256 _positionIndex;
            if (_context.expectations.isPositionClosed) {
                _positionIndex = _dataStoreInstance.getUint(Keys.positionIndexKey(_route)) - 1;
                assertEq(_dataStoreInstance.getUint(Keys.cumulativeVolumeGeneratedKey(_positionIndex + 1, _route)), 0, "_postSuccessfulDecreaseExecution: E13");
                assertEq(_dataStoreInstance.getUint(Keys.cumulativeVolumeGeneratedKey(_positionIndex, _route)), _beforeData.volumeGeneratedBefore, "_postSuccessfulDecreaseExecution: E013");
                _postSuccessfulDecreaseExecutionScoreGauge(_context, _route);
            } else {
                _positionIndex = _dataStoreInstance.getUint(Keys.positionIndexKey(_route));
                assertEq(_dataStoreInstance.getUint(Keys.cumulativeVolumeGeneratedKey(_positionIndex, _route)), _beforeData.volumeGeneratedBefore, "_postSuccessfulDecreaseExecution: E14");
            }
            assertEq(_dataStoreInstance.getUint(Keys.positionTraderSharesKey(_positionIndex, _route)), _beforeData.traderSharesBefore, "_postSuccessfulDecreaseExecution: E16");
            assertEq(_dataStoreInstance.getUint(Keys.positionLastTraderAmountInKey(_positionIndex, _route)), _beforeData.traderLastAmountIn, "_postSuccessfulDecreaseExecution: E17");
        }

        _context.expectations.isPositionClosed ? assertTrue(!_dataStoreInstance.getBool(Keys.isPositionOpenKey(_route)), "_postSuccessfulDecreaseExecution: E18") : assertTrue(_dataStoreInstance.getBool(Keys.isPositionOpenKey(_route)), "_postSuccessfulDecreaseExecution: E19");

        address _collateralToken = _dataStoreInstance.getAddress(Keys.routeCollateralTokenKey(_route));
        address _orchestrator = address(_context.orchestrator);
        uint256 _orchestratorCollateralTokenBalanceAfter = IERC20(_collateralToken).balanceOf(_orchestrator);
        assertTrue(IERC20(_collateralToken).balanceOf(_beforeData.trader) > _beforeData.traderCollateralTokenBalanceBefore, "_postSuccessfulDecreaseExecution: E20");
        if (_context.expectations.isPuppetsSubscribed || _context.expectations.isExpectingAdjustment || _context.expectations.isPuppetsExpiryExpected) {
            assertTrue(_orchestratorCollateralTokenBalanceAfter > _beforeData.orchestratorCollateralTokenBalanceBefore, "_postSuccessfulDecreaseExecution: E21");
        } else {
            assertEq(_orchestratorCollateralTokenBalanceAfter, _beforeData.orchestratorCollateralTokenBalanceBefore, "_postSuccessfulDecreaseExecution: E22");
        }
    }

    function _postSuccessfulDecreaseExecutionScoreGauge(Context memory _context, address _route) internal {
        if (_context.expectations.isExpectingReferralBoost) {
            uint256 _positionIndex = _context.dataStore.getUint(Keys.positionIndexKey(_route)) - 1;
            uint256 _totalVolume = _context.dataStore.getUint(Keys.cumulativeVolumeGeneratedKey(_positionIndex, _route));
            uint256 _puppetsProfit;
            uint256 _traderProfit;

            _puppetsProfit = uint256(_context.dataStore.getInt(Keys.puppetsPnLKey(_positionIndex, _route)) * -1);
            _traderProfit = uint256(_context.dataStore.getInt(Keys.traderPnLKey(_positionIndex, _route)) * -1);
            address _collateralToken = CommonHelper.collateralToken(_context.dataStore, _route);
            _traderProfit = _context.orchestrator.getPrice(_collateralToken) * _traderProfit / CommonHelper.collateralTokenDecimals(_context.dataStore, _collateralToken);
            _puppetsProfit = _context.orchestrator.getPrice(_collateralToken) * _puppetsProfit / CommonHelper.collateralTokenDecimals(_context.dataStore, _collateralToken);

            assertTrue(_puppetsProfit > 0, "_postSuccessfulDecreaseExecutionScoreGauge: E1");
            assertTrue(_traderProfit > 0, "_postSuccessfulDecreaseExecutionScoreGauge: E2");

            assertTrue(_totalVolume > 0, "_postSuccessfulDecreaseExecutionScoreGauge: E3");
            assertEq(_context.dataStore.getUint(Keys.cumulativeVolumeGeneratedKey(_positionIndex + 1, _route)), 0, "_postSuccessfulDecreaseExecutionScoreGauge: E4");

            uint256 _userProfit;
            uint256 _userVolume;
            address _scoreGauge = _context.dataStore.getAddress(keccak256(abi.encode("SCORE_GAUGE")));
            require(_scoreGauge != address(0), "_postSuccessfulDecreaseExecutionScoreGauge: ADDRESS 0");
            (_userVolume, _userProfit) = ScoreGauge(_scoreGauge).userPerformance(0, _context.expectations.subscribedPuppets[0]);
            assertEq(_userProfit, _puppetsProfit * 10250 / 10000, "_postSuccessfulDecreaseExecutionScoreGauge: E5");
            assertTrue(_userVolume > 0, "_postSuccessfulDecreaseExecutionScoreGauge: E6");

            (_userVolume, _userProfit) = ScoreGauge(_scoreGauge).userPerformance(0, CommonHelper.trader(_context.dataStore, _route));
            assertEq(_userProfit, _traderProfit * 10250 / 10000, "_postSuccessfulDecreaseExecutionScoreGauge: E7");
            assertTrue(_userVolume > 0, "_postSuccessfulDecreaseExecutionScoreGauge: E8");

            uint256 _expectedReferrerProfit = (((_puppetsProfit + _traderProfit) * 10250 / 10000) * 5 / 100);
            uint256 _expectedReferrerVolume = ((_totalVolume * 10250 / 10000) * 5 / 100);
            (_userVolume, _userProfit) = ScoreGauge(_scoreGauge).userPerformance(0, _context.users.referrer);
            assertEq(_userProfit, _expectedReferrerProfit, "_postSuccessfulDecreaseExecutionScoreGauge: E9");
            assertEq(_userVolume, _expectedReferrerVolume, "_postSuccessfulDecreaseExecutionScoreGauge: E10");
        }
    }
}