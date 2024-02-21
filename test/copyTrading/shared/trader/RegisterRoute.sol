// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../BaseHelper.t.sol";

contract RegisterRoute is BaseHelper {

    // ============================================================================================
    // Helper Functions
    // ============================================================================================

    function registerRoute(
        Context memory _context,
        address _trader,
        address _collateralToken,
        address _indexToken,
        bool _isLong,
        bytes memory _data
    ) public returns (bytes32 _routeKey) {
        IBaseOrchestrator _orchestratorInstance = IBaseOrchestrator(_context.orchestrator);

        uint256 _routesLengthBefore = CommonHelper.routes(_context.dataStore).length;
        bytes32 _routeTypeKey = Keys.routeTypeKey(_collateralToken, _indexToken, _isLong, _data);

        bytes32 _faultyRouteTypeKey = Keys.routeTypeKey(address(0), _indexToken, _isLong, _data);
        vm.expectRevert(bytes4(keccak256("RouteTypeNotRegistered()")));
        _orchestratorInstance.registerRoute(_faultyRouteTypeKey);

        vm.startPrank(_trader);
        _routeKey = _orchestratorInstance.registerRoute(_routeTypeKey);

        vm.expectRevert(bytes4(keccak256("RouteAlreadyRegistered()")));
        _orchestratorInstance.registerRoute(_routeTypeKey);
        vm.stopPrank();

        address _route = CommonHelper.routeAddress(_context.dataStore, _routeKey);
        assertTrue(CommonHelper.routeAddress(_context.dataStore, _routeKey) != address(0), "registerRoute: E1");
        assertTrue(CommonHelper.isRouteRegistered(_context.dataStore, _route), "registerRoute: E2");
        assertEq(CommonHelper.trader(_context.dataStore, _route), _trader, "registerRoute: E3");
        assertEq(CommonHelper.collateralToken(_context.dataStore, _route), _collateralToken, "registerRoute: E4");
        assertEq(CommonHelper.indexToken(_context.dataStore, _route), _indexToken, "registerRoute: E5");
        assertEq(CommonHelper.isLong(_context.dataStore, _route), _isLong, "registerRoute: E6");
        assertEq(CommonHelper.routeType(_context.dataStore, _route), keccak256(abi.encode(_collateralToken, _indexToken, _isLong, _data)), "registerRoute: E7");
        assertEq(CommonHelper.routes(_context.dataStore).length, _routesLengthBefore + 1, "registerRoute: E8");
    }
}