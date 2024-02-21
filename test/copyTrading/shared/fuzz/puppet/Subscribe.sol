// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../../BaseHelper.t.sol";

contract FuzzPuppetSubscribe is BaseHelper {

    // /// @inheritdoc IBaseOrchestrator
    // function subscribe(
    //     uint256 _allowance,
    //     uint256 _expiry,
    //     address _puppet,
    //     address _trader,
    //     bytes32 _routeTypeKey
    // ) public globalNonReentrant notPaused {
    //     address _route = OrchestratorHelper.updateSubscription(
    //         dataStore,
    //         _expiry,
    //         _allowance,
    //         msg.sender,
    //         _trader,
    //         _puppet,
    //         _routeTypeKey
    //     );

    //     emit Subscribe(_allowance, _expiry, _trader, _puppet, _route, _routeTypeKey);
    // }

    // /// @inheritdoc IBaseOrchestrator
    // function batchSubscribe(
    //     address _puppet,
    //     uint256[] memory _allowances,
    //     uint256[] memory _expiries,
    //     address[] memory _traders,
    //     bytes32[] memory _routeTypeKeys
    // ) public {
    //     if (_traders.length != _allowances.length) revert MismatchedInputArrays();
    //     if (_traders.length != _expiries.length) revert MismatchedInputArrays();
    //     if (_traders.length != _routeTypeKeys.length) revert MismatchedInputArrays();

    //     for (uint256 i = 0; i < _traders.length; i++) {
    //         subscribe(_allowances[i], _expiries[i], _puppet, _traders[i], _routeTypeKeys[i]);
    //     }
    // }

    // /// @inheritdoc IBaseOrchestrator
    // function depositAndBatchSubscribe(
    //     uint256 _amount,
    //     address _token,
    //     address _puppet,
    //     uint256[] memory _allowances,
    //     uint256[] memory _expiries,
    //     address[] memory _traders,
    //     bytes32[] memory _routeTypeKeys
    // ) external payable {
    //     deposit(_amount, _token, _puppet);

    //     batchSubscribe(_puppet, _allowances, _expiries, _traders, _routeTypeKeys);
    // }

    // function updateSubscription(
    //     IDataStore _dataStore,
    //     uint256 _expiry,
    //     uint256 _allowance,
    //     address _caller,
    //     address _trader,
    //     address _puppet,
    //     bytes32 _routeTypeKey
    // ) external returns (address _route) {
    //     if (_caller != _dataStore.getAddress(Keys.MULTI_SUBSCRIBER)) _puppet = _caller;

    //     bytes32 _routeKey = CommonHelper.routeKey(_dataStore, _trader, _routeTypeKey);
    //     _route = validateRouteKey(_dataStore, _routeKey);
    //     if (IBaseOrchestrator(CommonHelper.orchestrator(_dataStore)).isWaitingForCallback(_routeKey)) revert RouteWaitingForCallback();

    //     {
    //         bytes32 _puppetSubscriptionExpiryKey = Keys.puppetSubscriptionExpiryKey(_puppet, _routeKey);
    //         bytes32 _puppetAllowancesKey = Keys.puppetAllowancesKey(_puppet);
    //         bytes32 _routePuppetsKey = Keys.routePuppetsKey(_routeKey);
    //         if (_expiry > 0) {
    //             if (_allowance > CommonHelper.basisPointsDivisor() || _allowance == 0) revert InvalidAllowancePercentage();
    //             if (_expiry < block.timestamp + 24 hours) revert InvalidSubscriptionExpiry();

    //             _dataStore.setUint(_puppetSubscriptionExpiryKey, _expiry);

    //             _dataStore.addAddressToUint(_puppetAllowancesKey, _route, _allowance);
    //             _dataStore.addAddress(_routePuppetsKey, _puppet);
    //         } else {
    //             _dataStore.removeUint(_puppetSubscriptionExpiryKey);

    //             _dataStore.removeUintToAddress(_puppetAllowancesKey, _route);
    //             _dataStore.removeAddress(_routePuppetsKey, _puppet);
    //         }
    //     }
    // }

    // ============================================================================================
    // Helper Functions
    // ============================================================================================

    function subscribe_fuzzAllowance(Context memory _context, uint256 _allowance, bytes32 _routeTypeKey) external {
        address _user = _context.users.alice;
        address _trader = _context.users.trader;
        uint256 _expiry = block.timestamp + 30 days;
        bytes32 _routeKey = CommonHelper.routeKey(_context.dataStore, _trader, _routeTypeKey);
        address _route = CommonHelper.routeAddress(_context.dataStore, _routeKey);

        vm.startPrank(_user);

        if (_allowance == 0 || _allowance > CommonHelper.basisPointsDivisor()) {
            vm.expectRevert(bytes4(keccak256("InvalidAllowancePercentage()")));
            _context.orchestrator.subscribe(_allowance, _expiry, _user, _trader, _routeTypeKey);
        } else {
            assertEq(CommonHelper.puppetSubscriptionExpiry(_context.dataStore, _user, _route), 0);
            assertEq(CommonHelper.puppetAllowancePercentage(_context.dataStore, _user, _route), 0);

            _context.orchestrator.subscribe(_allowance, _expiry, _user, _trader, _routeTypeKey);

            assertEq(CommonHelper.puppetSubscriptionExpiry(_context.dataStore, _user, _route), _expiry);
            assertEq(CommonHelper.puppetAllowancePercentage(_context.dataStore, _user, _route), _allowance);
        }
    }
}