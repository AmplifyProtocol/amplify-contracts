// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {CallbackAsserts} from "../global/CallbackAsserts.sol";

import "../BaseHelper.t.sol";

contract RequestPosition is BaseHelper {

    struct BeforeData {
        uint256 swapParamsAmount;
        uint256 traderETHBalanceBefore;
        uint256 orchestratorCollateralTokenBalanceBefore;
        uint256 aliceCollateralTokenAccountBalanceBefore;
        uint256 bobCollateralTokenAccountBalanceBefore;
        uint256 yossiCollateralTokenAccountBalanceBefore;
        uint256 traderCollateralTokenBalanceBefore;
        address trader;
        bytes32 routeKey;
    }

    struct BeforeData2 {
        uint256 traderWETHBalanceBefore;
        uint256 orchestratorETHBalanceBefore;
        uint256 executionFeeBalanceBefore;
        uint256 unusedExecutionFee;
        address route;
    }

    // ============================================================================================
    // Helper Functions
    // ============================================================================================

    function requestPositionERC20(
        Context memory _context,
        IBaseRoute.AdjustPositionParams memory _adjustPositionParams,
        IBaseRoute.SwapParams memory _swapParams,
        address _trader,
        bool _isIncrease,
        bytes32 _routeTypeKey
    ) public returns (bytes32 _requestKey) {

        uint256 _executionFee = _context.executionFee;

        BeforeData2 memory _beforeData2;
        {
            _beforeData2.route = IDataStore(_context.dataStore).getAddress(Keys.routeAddressKey(CommonHelper.routeKey(_context.dataStore, _trader, _routeTypeKey)));
            if (_beforeData2.route.balance > 0) {
                _beforeData2.unusedExecutionFee = _beforeData2.route.balance;
                assertEq(_beforeData2.unusedExecutionFee, _executionFee, "requestPositionERC20: E1");
            }
            _beforeData2.orchestratorETHBalanceBefore = address(_context.orchestrator).balance;
            _beforeData2.executionFeeBalanceBefore = _context.dataStore.getUint(Keys.EXECUTION_FEE_BALANCE);
        }

        IBaseRoute.ExecutionFees memory _executionFees = IBaseRoute.ExecutionFees({
            dexKeeper: _executionFee,
            puppetKeeper: _context.expectations.isExpectingAdjustment ? _executionFee : 0
        });

        uint256 _totalExecutionFee = _context.expectations.isExpectingAdjustment ? _executionFee * 2 : _executionFee;

        if (_isIncrease) {
            _dealERC20(_swapParams.path[0], _context.users.owner, _swapParams.amount);
            vm.startPrank(_context.users.owner);
            vm.expectRevert(bytes4(keccak256("RouteNotRegistered()")));
            IBaseOrchestrator(_context.orchestrator).requestPosition{ value: _totalExecutionFee }(_adjustPositionParams, _swapParams, _executionFees, _routeTypeKey, _isIncrease);
            vm.stopPrank();

            _dealERC20(_swapParams.path[0], _trader, _swapParams.amount);

            vm.startPrank(_trader);

            {
                address _token = _swapParams.path[0];
                _swapParams.path[0] = _frax;
                _dealERC20(_swapParams.path[0], _trader, _swapParams.amount);
                _approveERC20(address(_context.orchestrator), _swapParams.path[0], _swapParams.amount);
                vm.expectRevert(bytes4(keccak256("InvalidPath()")));
                IBaseOrchestrator(_context.orchestrator).requestPosition{ value: _totalExecutionFee }(_adjustPositionParams, _swapParams, _executionFees, _routeTypeKey, _isIncrease);

                _swapParams.path[0] = _token;
            }

            vm.stopPrank();
        }

        vm.startPrank(_trader);

        vm.expectRevert(bytes4(keccak256("InvalidExecutionFee()")));
        IBaseOrchestrator(_context.orchestrator).requestPosition{ value: _totalExecutionFee - 1 }(_adjustPositionParams, _swapParams, _executionFees, _routeTypeKey, _isIncrease);

        _executionFees.dexKeeper = _executionFee - 1;
        vm.expectRevert(bytes4(keccak256("InvalidExecutionFee()")));
        IBaseOrchestrator(_context.orchestrator).requestPosition{ value: _totalExecutionFee - 1 }(_adjustPositionParams, _swapParams, _executionFees, _routeTypeKey, _isIncrease);
        _executionFees.dexKeeper = _executionFee;

        vm.expectRevert(bytes4(keccak256("InvalidExecutionFee()")));
        IBaseOrchestrator(_context.orchestrator).requestPosition{ value: _totalExecutionFee + 1 }(_adjustPositionParams, _swapParams, _executionFees, _routeTypeKey, _isIncrease);
        _executionFees.dexKeeper = _executionFee;

        _executionFees.dexKeeper = _executionFee + 1;
        vm.expectRevert(bytes4(keccak256("InvalidExecutionFee()")));
        IBaseOrchestrator(_context.orchestrator).requestPosition{ value: _totalExecutionFee }(_adjustPositionParams, _swapParams, _executionFees, _routeTypeKey, _isIncrease);
        _executionFees.dexKeeper = _executionFee;

        _executionFees.dexKeeper = _executionFee - 1;
        vm.expectRevert(bytes4(keccak256("InvalidExecutionFee()")));
        IBaseOrchestrator(_context.orchestrator).requestPosition{ value: _totalExecutionFee }(_adjustPositionParams, _swapParams, _executionFees, _routeTypeKey, _isIncrease);
        _executionFees.dexKeeper = _executionFee;

        bytes32 _routeKey = CommonHelper.routeKey(_context.dataStore, _trader, _routeTypeKey);
        _beforeData2.traderWETHBalanceBefore = IERC20(_weth).balanceOf(_trader);
        BeforeData memory _beforeData = _getAddCollateralAssertsData(_context, _routeKey, _swapParams.amount, _trader);

        if (_isIncrease) _approveERC20(address(_context.orchestrator), _swapParams.path[0], _swapParams.amount);
        _requestKey = IBaseOrchestrator(_context.orchestrator).requestPosition{ value: _totalExecutionFee }(
            _adjustPositionParams,
            _swapParams,
            _executionFees,
            _routeTypeKey,
            _isIncrease
        );

        if (_isIncrease) _approveERC20(address(_context.orchestrator), _swapParams.path[0], _swapParams.amount);
        vm.expectRevert(bytes4(keccak256("WaitingForCallback()")));
        IBaseOrchestrator(_context.orchestrator).requestPosition{ value: _totalExecutionFee }(_adjustPositionParams, _swapParams, _executionFees, _routeTypeKey, _isIncrease);

        vm.stopPrank();

        {
            if (_context.expectations.isUsingMocks) {
                // add request key to order list
                IDataStore _dataStoreInstance = _context.dataStore;
                bytes32 _orderListKey = keccak256(
                    abi.encode(keccak256(abi.encode("ACCOUNT_ORDER_LIST")),
                    CommonHelper.routeAddress(_dataStoreInstance, _routeKey))
                );
                GMXV2RouteHelper.gmxDataStore(_dataStoreInstance).addBytes32(_orderListKey, _requestKey);
            }
        }

        {
            address _puppet = _context.users.alice;
            address _orchestratorAddr = address(_context.orchestrator);
            uint256[] memory _allowances = new uint256[](1);
            _allowances[0] = 10000;
            uint256[] memory _expiries = new uint256[](1);
            _expiries[0] = block.timestamp + 24 hours;
            address[] memory _traders = new address[](1);
            _traders[0] = _trader;
            bytes32[] memory _routeTypeKeys = new bytes32[](1);
            _routeTypeKeys[0] = _routeTypeKey;
            vm.startPrank(_puppet);
            vm.expectRevert(bytes4(keccak256("RouteWaitingForCallback()")));
            IBaseOrchestrator(_orchestratorAddr).batchSubscribe(_puppet, _allowances, _expiries, _traders, _routeTypeKeys);
            vm.stopPrank();
        }

        if (_isIncrease && _swapParams.amount > 0) {
            _addCollateralAsserts(_context, _beforeData);
        } else {
            _removeCollateralAsserts(_context, _beforeData);
        }

        {
            address _route = IDataStore(_context.dataStore).getAddress(Keys.routeAddressKey(_routeKey));
            uint256 _positionIndex = IDataStore(_context.dataStore).getUint(Keys.positionIndexKey(_route));
            assertEq(IDataStore(_context.dataStore).getUint(Keys.pendingSizeDeltaKey(_positionIndex, _route)), _adjustPositionParams.sizeDelta, "requestPositionERC20: E1");
            assertEq(IDataStore(_context.dataStore).getBytes32(Keys.pendingRequestKey(_positionIndex, _route)), _requestKey, "requestPositionERC20: E2");
        }
        assertEq(IBaseOrchestrator(_context.orchestrator).isWaitingForCallback(_routeKey), true, "requestPositionERC20: E3");
        if (_beforeData2.unusedExecutionFee > 0) {
            if (_context.expectations.isExpectingAdjustment) {
                assertEq(_beforeData2.orchestratorETHBalanceBefore + _context.executionFee, address(_context.orchestrator).balance, "requestPositionERC20: E5");
                assertEq(_beforeData2.executionFeeBalanceBefore + _context.executionFee, _context.dataStore.getUint(Keys.EXECUTION_FEE_BALANCE), "requestPositionERC20: E6");
            } else {
                assertEq(_beforeData2.orchestratorETHBalanceBefore, address(_context.orchestrator).balance, "requestPositionERC20: E5");
                assertEq(_beforeData2.executionFeeBalanceBefore, _context.dataStore.getUint(Keys.EXECUTION_FEE_BALANCE), "requestPositionERC20: E6");
            }
            assertEq(_beforeData2.route.balance, 0, "requestPositionERC20: E7");
            if (!_context.expectations.isExpectingNonZeroBalance) {
                if (IDataStore(_context.dataStore).getAddress(Keys.routeCollateralTokenKey(_beforeData2.route)) == _weth) {
                    assertEq(_beforeData2.traderWETHBalanceBefore, IERC20(_weth).balanceOf(_trader) + _swapParams.amount - _beforeData2.unusedExecutionFee, "requestPositionERC20: E8");
                } else {
                    assertEq(_beforeData2.traderWETHBalanceBefore, IERC20(_weth).balanceOf(_trader) - _beforeData2.unusedExecutionFee, "requestPositionERC20: E9");
                }
            }
        }
    }

    function requestPositionFaulty(Context memory _context, bytes32 _routeKey) external returns (bytes32 _requestKey) {
        address _route = IDataStore(_context.dataStore).getAddress(Keys.routeAddressKey(_routeKey));
        require(_route != address(0), "requestPositionFaulty: ZERO_ADDRESS");

        address _collateralToken = IDataStore(_context.dataStore).getAddress(Keys.routeCollateralTokenKey(_route));
        require(_collateralToken == _weth, "requestPositionFaulty: NO_WETH");

        require(IDataStore(_context.dataStore).getAddress(Keys.routeTraderKey(_route)) == _context.users.trader, "requestPositionFaulty: NOT_TRADER");
        require(IDataStore(_context.dataStore).getBool(Keys.routeIsLongKey(_route)), "requestPositionFaulty: NOT_LONG");

        IBaseRoute.AdjustPositionParams memory _adjustPositionParams = IBaseRoute.AdjustPositionParams({
            orderType: IBaseRoute.OrderType.MarketIncrease,
            collateralDelta: 0,
            sizeDelta: 0,
            acceptablePrice: 0,
            triggerPrice: 0,
            puppets: _context.expectations.subscribedPuppets
        });

        IBaseRoute.SwapParams memory _swapParams;
        address[] memory _path = new address[](1);
        _path[0] = _collateralToken;
        _swapParams = IBaseRoute.SwapParams({
            path: _path,
            amount: 1 ether,
            minOut: 0
        });

        _requestKey = requestPositionERC20(
            _context,
            _adjustPositionParams,
            _swapParams,
            _context.users.trader,
            true,
            _context.longETHRouteTypeKey
        );
    }

    function cancelOrder(
        Context memory _context,
        CallbackAsserts _callbackAsserts,
        bool _isIncrease,
        bytes32 _requestKey,
        bytes32 _routeKey
    ) external {
        address _route = IDataStore(_context.dataStore).getAddress(Keys.routeAddressKey(_routeKey));
        address _trader = IDataStore(_context.dataStore).getAddress(Keys.routeTraderKey(_route));
        bytes32 _routeTypeKey = CommonHelper.routeType(_context.dataStore, _route);

        vm.startPrank(_trader);

        vm.expectRevert(bytes4(keccak256("InvalidExecutionFee()")));
        IBaseOrchestrator(_context.orchestrator).cancelRequest{ value: _context.executionFee - 1 }(_routeTypeKey, _requestKey);

        vm.expectRevert(bytes4(keccak256("InvalidExecutionFee()")));
        IBaseOrchestrator(_context.orchestrator).cancelRequest(_routeTypeKey, _requestKey);

        vm.stopPrank();

        {
            address _puppet = _context.users.alice;
            address _orchestratorAddr = address(_context.orchestrator);
            uint256[] memory _allowances = new uint256[](1);
            _allowances[0] = 10000;
            uint256[] memory _expiries = new uint256[](1);
            _expiries[0] = block.timestamp + 24 hours;
            address[] memory _traders = new address[](1);
            _traders[0] = _trader;
            bytes32[] memory _routeTypeKeys = new bytes32[](1);
            _routeTypeKeys[0] = _routeTypeKey;
            vm.startPrank(_puppet);
            vm.expectRevert(bytes4(keccak256("RouteWaitingForCallback()")));
            IBaseOrchestrator(_orchestratorAddr).batchSubscribe(_puppet, _allowances, _expiries, _traders, _routeTypeKeys);
            vm.stopPrank();
        }

        assertTrue(IBaseOrchestrator(_context.orchestrator).isWaitingForCallback(_routeKey), "cancelOrder: E1");

        CallbackAsserts.BeforeData memory _beforeData;
        {
            uint256 _positionIndex = IDataStore(_context.dataStore).getUint(Keys.positionIndexKey(_route));
            address _collateralToken = IDataStore(_context.dataStore).getAddress(Keys.routeCollateralTokenKey(_route));
            _beforeData = CallbackAsserts.BeforeData({
                aliceDepositAccountBalanceBefore: CommonHelper.puppetAccountBalance(_context.dataStore, _context.users.alice, _collateralToken),
                orchestratorEthBalanceBefore: address(_context.orchestrator).balance,
                executionFeeBalanceBefore: _context.dataStore.getUint(Keys.EXECUTION_FEE_BALANCE),
                volumeGeneratedBefore: IDataStore(_context.dataStore).getUint(Keys.cumulativeVolumeGeneratedKey(_positionIndex, _route)),
                traderSharesBefore: IDataStore(_context.dataStore).getUint(Keys.positionTraderSharesKey(_positionIndex, _route)),
                traderLastAmountIn: IDataStore(_context.dataStore).getUint(Keys.positionLastTraderAmountInKey(_positionIndex, _route)),
                traderETHBalanceBefore: _trader.balance - _context.executionFee, // `- _executionFee` because we record the balance before the execution fee is taken
                traderCollateralTokenBalanceBefore: IERC20(_collateralToken).balanceOf(_trader),
                orchestratorCollateralTokenBalanceBefore: IERC20(_collateralToken).balanceOf(address(_context.orchestrator)),
                trader: _trader,
                isIncrease: _isIncrease,
                routeKey: _routeKey
            });
        }

        vm.startPrank(_trader);

        bool _isWaitingForKeeperAdjustment = RouteReader.isWaitingForKeeperAdjustment(_context.dataStore, _route);
        _context.expectations.isExpectingAdjustment ? assertTrue(_isWaitingForKeeperAdjustment, "cancelOrder: E2") : assertTrue(!_isWaitingForKeeperAdjustment, "cancelOrder: E3");

        IBaseOrchestrator(_context.orchestrator).cancelRequest{ value: _context.executionFee }(_routeTypeKey, _requestKey);

        assertTrue(!IBaseOrchestrator(_context.orchestrator).isWaitingForCallback(_routeKey), "cancelOrder: E4");
        assertTrue(!RouteReader.isWaitingForKeeperAdjustment(_context.dataStore, _route), "cancelOrder: E5");

        vm.stopPrank();

        _callbackAsserts.postFailedExecution(_context, _beforeData);
    }

    // ============================================================================================
    // Internal Helper Functions
    // ============================================================================================

    function _addCollateralAsserts(Context memory _context, BeforeData memory _beforeData) internal {
        address _route = IDataStore(_context.dataStore).getAddress(Keys.routeAddressKey(_beforeData.routeKey));
        uint256 _positionIndex = IDataStore(_context.dataStore).getUint(Keys.positionIndexKey(_route));
        bool _isAdjustmentRequired = RouteReader.isWaitingForKeeperAdjustment(_context.dataStore, _route);
        _context.expectations.isExpectingAdjustment ? assertTrue(_isAdjustmentRequired, "_addCollateralAsserts: E1") : assertTrue(!_isAdjustmentRequired, "_addCollateralAsserts: E2");

        address _collateralToken = IDataStore(_context.dataStore).getAddress(Keys.routeCollateralTokenKey(_route));
        if (_context.expectations.isPuppetsSubscribed) {
            {
                uint256 _orchestratorCollateralTokenBalanceAfter = IERC20(_collateralToken).balanceOf(address(_context.orchestrator));
                uint256 _puppetsAmountIn = IDataStore(_context.dataStore).getUint(Keys.addCollateralRequestPuppetsAmountInKey(_positionIndex, _route));
                assertTrue(_beforeData.aliceCollateralTokenAccountBalanceBefore > IDataStore(_context.dataStore).getUint(Keys.puppetDepositAccountKey(_context.users.alice, _collateralToken)), "_addCollateralAsserts: E3");
                if (_context.expectations.subscribedPuppets.length > 1) {
                    assertTrue(_beforeData.bobCollateralTokenAccountBalanceBefore > IDataStore(_context.dataStore).getUint(Keys.puppetDepositAccountKey(_context.users.bob, _collateralToken)), "_addCollateralAsserts: E4");
                    assertTrue(_beforeData.yossiCollateralTokenAccountBalanceBefore > IDataStore(_context.dataStore).getUint(Keys.puppetDepositAccountKey(_context.users.yossi, _collateralToken)), "_addCollateralAsserts: E5");
                }
                assertTrue(_puppetsAmountIn > 0, "_addCollateralAsserts: E6");
                assertEq(_beforeData.orchestratorCollateralTokenBalanceBefore - _puppetsAmountIn, _orchestratorCollateralTokenBalanceAfter, "_addCollateralAsserts: E7");
            }
            assertTrue(IDataStore(_context.dataStore).getUintArray(Keys.addCollateralRequestPuppetsSharesKey(_positionIndex, _route)).length > 0, "_addCollateralAsserts: E8");
        } else {
            uint256 _orchestratorCollateralTokenBalanceAfter = IERC20(_collateralToken).balanceOf(address(_context.orchestrator));
            assertEq(_beforeData.aliceCollateralTokenAccountBalanceBefore, IDataStore(_context.dataStore).getUint(Keys.puppetDepositAccountKey(_context.users.alice, _collateralToken)), "_addCollateralAsserts: E10");
            assertEq(_beforeData.bobCollateralTokenAccountBalanceBefore, IDataStore(_context.dataStore).getUint(Keys.puppetDepositAccountKey(_context.users.bob, _collateralToken)), "_addCollateralAsserts: E11");
            assertEq(_beforeData.yossiCollateralTokenAccountBalanceBefore, IDataStore(_context.dataStore).getUint(Keys.puppetDepositAccountKey(_context.users.yossi, _collateralToken)), "_addCollateralAsserts: E12");
            assertEq(_beforeData.orchestratorCollateralTokenBalanceBefore, _orchestratorCollateralTokenBalanceAfter, "_addCollateralAsserts: E13");
        }

        // not taking a possible swap into account here. else would be ` > 0 `
        assertEq(IDataStore(_context.dataStore).getUint(Keys.addCollateralRequestTraderAmountInKey(_positionIndex, _route)), _beforeData.swapParamsAmount, "_addCollateralAsserts: E16");
        assertEq(IDataStore(_context.dataStore).getUint(Keys.addCollateralRequestTraderSharesKey(_positionIndex, _route)), _beforeData.swapParamsAmount, "_addCollateralAsserts: E17");

        assertTrue(IDataStore(_context.dataStore).getUint(Keys.addCollateralRequestTotalSupplyKey(_positionIndex, _route)) > 0, "_addCollateralAsserts: E18");

        assertTrue(_beforeData.traderETHBalanceBefore > _beforeData.trader.balance, "_addCollateralAsserts: E21");
        assertTrue(_beforeData.traderCollateralTokenBalanceBefore > IERC20(_collateralToken).balanceOf(_beforeData.trader), "_addCollateralAsserts: E22");
    }

    function _removeCollateralAsserts(Context memory _context, BeforeData memory _beforeData) internal {
        address _route = IDataStore(_context.dataStore).getAddress(Keys.routeAddressKey(_beforeData.routeKey));
        address _collateralToken = IDataStore(_context.dataStore).getAddress(Keys.routeCollateralTokenKey(_route));
        uint256 _orchestratorCollateralTokenBalanceAfter = IERC20(_collateralToken).balanceOf(address(_context.orchestrator));
        if (!_context.expectations.isExpectingNonZeroBalance) {
            assertEq(_beforeData.aliceCollateralTokenAccountBalanceBefore, IDataStore(_context.dataStore).getUint(Keys.puppetDepositAccountKey(_context.users.alice, _collateralToken)), "_removeCollateralAsserts: E5");
            assertEq(_beforeData.bobCollateralTokenAccountBalanceBefore, IDataStore(_context.dataStore).getUint(Keys.puppetDepositAccountKey(_context.users.bob, _collateralToken)), "_removeCollateralAsserts: E6");
            assertEq(_beforeData.yossiCollateralTokenAccountBalanceBefore, IDataStore(_context.dataStore).getUint(Keys.puppetDepositAccountKey(_context.users.yossi, _collateralToken)), "_removeCollateralAsserts: E7");
            assertEq(_beforeData.orchestratorCollateralTokenBalanceBefore, _orchestratorCollateralTokenBalanceAfter, "_removeCollateralAsserts: E8");
            if (_collateralToken == _weth && !_context.expectations.isGMXV1) { // unused execution fee is returned to the trader as WETH
                assertEq(_beforeData.traderCollateralTokenBalanceBefore, IERC20(_collateralToken).balanceOf(_beforeData.trader) - _context.executionFee, "_removeCollateralAsserts: E9");
            } else {
                assertEq(_beforeData.traderCollateralTokenBalanceBefore, IERC20(_collateralToken).balanceOf(_beforeData.trader), "_removeCollateralAsserts: E10");
            }
        }

        assertEq(IDataStore(_context.dataStore).getBool(Keys.isKeeperAdjustmentEnabledKey(_route)), false, "_removeCollateralAsserts: E11");
        assertTrue(_beforeData.traderETHBalanceBefore > _beforeData.trader.balance, "_removeCollateralAsserts: E12");
    }

    function _getAddCollateralAssertsData(
        Context memory _context,
        bytes32 _routeKey,
        uint256 _swapParamsAmount,
        address _trader
    ) internal view returns (BeforeData memory) {
        address _route = IDataStore(_context.dataStore).getAddress(Keys.routeAddressKey(_routeKey));
        address _collateralToken = IDataStore(_context.dataStore).getAddress(Keys.routeCollateralTokenKey(_route));
        return BeforeData({
            swapParamsAmount: _swapParamsAmount,
            traderETHBalanceBefore: _trader.balance,
            orchestratorCollateralTokenBalanceBefore: IERC20(_collateralToken).balanceOf(address(_context.orchestrator)),
            aliceCollateralTokenAccountBalanceBefore: IDataStore(_context.dataStore).getUint(Keys.puppetDepositAccountKey(_context.users.alice, _collateralToken)),
            bobCollateralTokenAccountBalanceBefore: IDataStore(_context.dataStore).getUint(Keys.puppetDepositAccountKey(_context.users.bob, _collateralToken)),
            yossiCollateralTokenAccountBalanceBefore: IDataStore(_context.dataStore).getUint(Keys.puppetDepositAccountKey(_context.users.yossi, _collateralToken)),
            traderCollateralTokenBalanceBefore: IERC20(_collateralToken).balanceOf(_trader),
            trader: _trader,
            routeKey: _routeKey
        });
    }
}