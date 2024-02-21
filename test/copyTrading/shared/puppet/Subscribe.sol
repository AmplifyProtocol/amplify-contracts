// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {IPositionHandler} from "../interfaces/IPositionHandler.sol";

import {CallbackAsserts} from "../global/CallbackAsserts.sol";

import {RequestPosition} from "../trader/RequestPosition.sol";

import "../BaseHelper.t.sol";

contract Subscribe is BaseHelper {

    // ============================================================================================
    // Helper Functions
    // ============================================================================================

    function subscribe(
        Context memory _context,
        address _puppet,
        bool _subscribe,
        uint256 _allowance,
        uint256 _expiry,
        address _trader,
        bytes32 _routeTypeKey
    ) public {
        uint256[] memory _allowances = new uint256[](1);
        _allowances[0] = _allowance;
        uint256[] memory _expiries = new uint256[](1);
        _expiries[0] = _expiry;
        address[] memory _traders = new address[](1);
        _traders[0] = _trader;
        bytes32[] memory _routeTypeKeys = new bytes32[](1);
        _routeTypeKeys[0] = _routeTypeKey;

        batchSubscribe(_context, _puppet, _subscribe, _allowances, _expiries, _traders, _routeTypeKeys);
    }

    function batchSubscribe(
        Context memory _context,
        address _puppet,
        bool _subscribe,
        uint256[] memory _allowances,
        uint256[] memory _expiries,
        address[] memory _traders,
        bytes32[] memory _routeTypeKeys
    ) public {
        uint256 _length = _allowances.length;
        bool[] memory _subscribes = new bool[](_length);
        for (uint256 i = 0; i < _allowances.length; i++) {
            if (_subscribe) {
                require (_allowances[i] > 0, "batchSubscribe: E1");
                _subscribes[i] = true;
            } else {
                require (_allowances[i] == 0, "batchSubscribe: E2");
                _subscribes[i] = false;
            }
        }

        IBaseOrchestrator _orchestratorInstance = IBaseOrchestrator(_context.orchestrator);
        {
            uint256[] memory _faultyAllowances = new uint256[](_length + 1);
            uint256[] memory _faultyExpiries = new uint256[](_length + 1);
            address[] memory _faultyTraders = new address[](_length + 1);
            bytes32[] memory _faultyRouteTypeKeys = new bytes32[](_length + 1);

            vm.expectRevert(bytes4(keccak256("MismatchedInputArrays()")));
            _orchestratorInstance.batchSubscribe(_puppet, _faultyAllowances, _expiries, _traders, _routeTypeKeys);

            vm.expectRevert(bytes4(keccak256("MismatchedInputArrays()")));
            _orchestratorInstance.batchSubscribe(_puppet, _allowances, _faultyExpiries, _traders, _routeTypeKeys);

            vm.expectRevert(bytes4(keccak256("MismatchedInputArrays()")));
            _orchestratorInstance.batchSubscribe(_puppet, _allowances, _expiries, _faultyTraders, _routeTypeKeys);

            vm.expectRevert(bytes4(keccak256("MismatchedInputArrays()")));
            _orchestratorInstance.batchSubscribe(_puppet, _allowances, _expiries, _traders, _faultyRouteTypeKeys);
        }

        {
            uint256[] memory _zeroAllowances = new uint256[](_length);
            uint256[] memory _faultyExpiries = new uint256[](_length);
            _faultyExpiries[0] = block.timestamp + 1 hours;

            vm.expectRevert(bytes4(keccak256("InvalidAllowancePercentage()")));
            _orchestratorInstance.batchSubscribe(_puppet, _zeroAllowances, _expiries, _traders, _routeTypeKeys);

            vm.expectRevert(bytes4(keccak256("InvalidSubscriptionExpiry()")));
            _orchestratorInstance.batchSubscribe(_puppet, _allowances, _faultyExpiries, _traders, _routeTypeKeys);

            _traders[0] = _context.users.alice; // wrong Trader
            vm.expectRevert(bytes4(keccak256("RouteNotRegistered()")));
            _orchestratorInstance.batchSubscribe(_puppet, _allowances, _expiries, _traders, _routeTypeKeys);
            _traders[0] = _context.users.trader;
        }

        vm.prank(_puppet);
        _orchestratorInstance.batchSubscribe(_puppet, _allowances, _expiries, _traders, _routeTypeKeys);

        _batchSubscribeAsserts(_context, _puppet, _allowances, _expiries, _traders, _routeTypeKeys, _subscribes);
    }

    function expireSubscriptionsAndExecute(
        Context memory _context,
        IPositionHandler _positionHandler,
        RequestPosition _requestPosition,
        CallbackAsserts _callbackAsserts,
        address _trader,
        bytes32 _routeKey
    ) public {
        address _route = CommonHelper.routeAddress(_context.dataStore, _routeKey);
        uint256 _positionIndex = _context.dataStore.getUint(Keys.positionIndexKey(_route));
        uint256 _puppetsInPositionBefore = _context.dataStore.getAddressArray(Keys.positionPuppetsKey(_positionIndex, _route)).length;
        uint256 _aliceSharesBefore = _context.dataStore.getUintArray(Keys.positionPuppetsSharesKey(_positionIndex, _route))[0];
        uint256 _bobSharesBefore = _context.dataStore.getUintArray(Keys.positionPuppetsSharesKey(_positionIndex, _route))[1];
        uint256 _yossiSharesBefore = _context.dataStore.getUintArray(Keys.positionPuppetsSharesKey(_positionIndex, _route))[2];
        uint256 _traderSharesBefore = _context.dataStore.getUint(Keys.positionTraderSharesKey(_positionIndex, _route));

        skip(25 hours); // all puppets subscription should expire at this point

        _context.expectations.isExpectingAdjustment = true;
        _context.expectations.isPuppetsSubscribed = false;
        _context.expectations.requestKeyToExecute = _positionHandler.increasePosition(_context, _requestPosition, IBaseRoute.OrderType.MarketIncrease, _trader, _weth, _weth, true);
        _positionHandler.executeRequest(_context, _callbackAsserts, _trader, true, _routeKey);

        assertEq(_puppetsInPositionBefore, _context.dataStore.getAddressArray(Keys.positionPuppetsKey(_positionIndex, _route)).length, "expireSubscriptionsAndExecute: E1");
        assertEq(_aliceSharesBefore, _context.dataStore.getUintArray(Keys.positionPuppetsSharesKey(_positionIndex, _route))[0], "expireSubscriptionsAndExecute: E2");
        assertEq(_bobSharesBefore, _context.dataStore.getUintArray(Keys.positionPuppetsSharesKey(_positionIndex, _route))[1], "expireSubscriptionsAndExecute: E3");
        assertEq(_yossiSharesBefore, _context.dataStore.getUintArray(Keys.positionPuppetsSharesKey(_positionIndex, _route))[2], "expireSubscriptionsAndExecute: E4");
        assertTrue(_traderSharesBefore < _context.dataStore.getUint(Keys.positionTraderSharesKey(_positionIndex, _route)), "expireSubscriptionsAndExecute: E5");
        assertTrue(_aliceSharesBefore > 0, "expireSubscriptionsAndExecute: E6");
        assertTrue(_bobSharesBefore > 0, "expireSubscriptionsAndExecute: E7");
        assertTrue(_yossiSharesBefore > 0, "expireSubscriptionsAndExecute: E8");
    }

    // ============================================================================================
    // Test Functions
    // ============================================================================================

    function batchSubscribeFlowTest(Context memory _context, bytes32[] memory _routeKeys) external {
        require(_routeKeys.length == 2, "testBatchSubscribeFlow: E1");

        uint256[] memory _allowances = new uint256[](2);
        _allowances[0] = _BASIS_POINTS_DIVISOR; // 100%
        _allowances[1] = _BASIS_POINTS_DIVISOR / 2; // 50%
        uint256[] memory _expiries = new uint256[](2);
        _expiries[0] = block.timestamp + 24 hours;
        _expiries[1] = block.timestamp + 48 hours;
        address[] memory _traders = new address[](2);
        _traders[0] = _context.users.trader;
        _traders[1] = _context.users.trader;
        bytes32[] memory _routeTypeKeys = new bytes32[](2);
        _routeTypeKeys[0] = CommonHelper.routeType(_context.dataStore, CommonHelper.routeAddress(_context.dataStore, _routeKeys[0]));
        _routeTypeKeys[1] = CommonHelper.routeType(_context.dataStore, CommonHelper.routeAddress(_context.dataStore, _routeKeys[1]));

        batchSubscribe(_context, _context.users.alice, true, _allowances, _expiries, _traders, _routeTypeKeys);
    }

    // ============================================================================================
    // Internal Functions
    // ============================================================================================

    function _batchSubscribeAsserts(
        Context memory _context,
        address _puppet,
        uint256[] memory _allowances,
        uint256[] memory _expiries,
        address[] memory _traders,
        bytes32[] memory _routeTypeKeys,
        bool[] memory _subscribes
    ) internal {
        uint256 _length = _allowances.length;
        for (uint256 i = 0; i < _length; i++) {
            bytes32 _routeKey = CommonHelper.routeKey(_context.dataStore, _traders[i], _routeTypeKeys[i]);
            address _route = CommonHelper.routeAddress(_context.dataStore, _routeKey);
            uint256 _puppetSubscriptionExpiry = _context.dataStore.getUint(Keys.puppetSubscriptionExpiryKey(_puppet, _route));
            bytes32 _puppetAllowancesKey = Keys.puppetAllowancesKey(_puppet);
            (bool _success, uint256 _puppetAllowance) = _context.dataStore.tryGetAddressToUintFor(_puppetAllowancesKey, _route);
            if (_subscribes[i]) {
                assertEq(_puppetSubscriptionExpiry, _expiries[i], "testBatchSubscribeFlow: E1");
                assertEq(_puppetAllowance, _allowances[i], "testBatchSubscribeFlow: E2");
                assertTrue(_success, "testBatchSubscribeFlow: E3");
            } else {
                assertEq(_puppetSubscriptionExpiry, 0, "testBatchSubscribeFlow: E5");
                assertEq(_puppetAllowance, 0, "testBatchSubscribeFlow: E6");
                assertTrue(!_success, "testBatchSubscribeFlow: E7");

                vm.expectRevert(bytes4(keccak256("CannotUnsubscribeYet()")));
                IBaseOrchestrator(_context.orchestrator).batchSubscribe(_puppet, _allowances, _expiries, _traders, _routeTypeKeys);
            }
        }
    }
}