// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../../BaseGMXV2.t.sol";

contract GMXV2ReferralLinkIntegration is BaseGMXV2 {

    bytes32 _routeKeyReferralLinkUnitConcrete;

    function setUp() public override {
        BaseGMXV2.setUp();

        _routeKeyReferralLinkUnitConcrete = _registerRoute.registerRoute(context, context.users.trader, _weth, _weth, true, _ethLongMarketData);
    }

    function testReferralLink() external {
        context.expectations.isSuccessfulExecution = true;
        context.expectations.isArtificialExecution = true;
        context.expectations.isUsingMocks = true;

        _referralLink.referralLinkTest(context, _deposit, _subscribe, _requestPosition, _callbackAsserts, address(_positionHandler), _routeKeyReferralLinkUnitConcrete);
    }
}