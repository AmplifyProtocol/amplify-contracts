// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../../BaseGMXV1.t.sol";

contract GMXV1ReferralLinkIntegration is BaseGMXV1 {

    bytes32 _routeKeyReferralLinkUnitConcrete;

    function setUp() public override {
        BaseGMXV1.setUp();

        _routeKeyReferralLinkUnitConcrete = _registerRoute.registerRoute(context, context.users.trader, _weth, _weth, true, _emptyBytes);
    }

    function testReferralLink() external {
        _referralLink.referralLinkTest(
            context,
            _deposit,
            _subscribe,
            _requestPosition,
            _callbackAsserts,
            address(_positionHandler),
            _routeKeyReferralLinkUnitConcrete
        );
    }
}