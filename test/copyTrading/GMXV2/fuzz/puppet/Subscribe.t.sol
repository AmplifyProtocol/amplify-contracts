// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../../BaseGMXV2.t.sol";

contract GMXV2PuppetSubscribeFuzz is BaseGMXV2 {

    bytes32 private _localRouteTypeKey;

    function setUp() public override {
        BaseGMXV2.setUp();

        bytes32 _routeKey = _registerRoute.registerRoute(context, context.users.trader, _weth, _weth, true, _ethLongMarketData);
        address _route = CommonHelper.routeAddress(context.dataStore, _routeKey);
        _localRouteTypeKey = CommonHelper.routeType(context.dataStore, _route);
        require(_localRouteTypeKey != bytes32(0), "GMXV2PuppetSubscribeFuzz: SETUP FAILED - _localRouteTypeKey");

    }

    function testFuzz_Subscribe_Allowance(uint256 _allowance) external {
        _fuzz_PuppetSubscribe.subscribe_fuzzAllowance(context, _allowance, _localRouteTypeKey);
    }

    // function testFuzz_Subscribe_Expiry(uint256 _expiry) external {
    //     _fuzz_PuppetSubscribe.subscribe_fuzzExpiry(context, _expiry, _localRouteTypeKey);
    // }

    // function testFuzz_Subscribe_Puppet(Context memory _context,
    // function testFuzz_Subscribe_Trader(Context memory _context,

    // function testFuzz_Unsubscribe_Allowance(Context memory _context, uint256 _allowance) external {
    // function testFuzz_Unsubscribe_Expiry(Context memory _context,
    // function testFuzz_Unsubscribe_Puppet(Context memory _context,
    // function testFuzz_Unsubscribe_Trader(Context memory _context,
}