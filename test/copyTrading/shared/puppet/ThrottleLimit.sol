// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../BaseHelper.t.sol";

contract ThrottleLimit is BaseHelper {

    // ============================================================================================
    // Helper Functions
    // ============================================================================================

    function setThrottleLimit(Context memory _context, address _puppet, uint256 _throttleLimit, bytes32 _routeTypeKey) public {
        vm.prank(_puppet);
        IBaseOrchestrator(_context.orchestrator).setThrottleLimit(_throttleLimit, _routeTypeKey);

        assertEq(IDataStore(_context.dataStore).getUint(Keys.puppetThrottleLimitKey(_puppet, _routeTypeKey)), _throttleLimit, "setThrottleLimit: E0");
    }

    // ============================================================================================
    // Test Functions
    // ============================================================================================

    function throttleLimitTest(Context memory _context) external {
        setThrottleLimit(_context, _context.users.alice, 1 days, _context.longETHRouteTypeKey);
        setThrottleLimit(_context, _context.users.alice, 1 days, _context.shortETHRouteTypeKey);
        setThrottleLimit(_context, _context.users.bob, 2 days, _context.longETHRouteTypeKey);
        setThrottleLimit(_context, _context.users.yossi, 3 days, _context.shortETHRouteTypeKey);
    }
}