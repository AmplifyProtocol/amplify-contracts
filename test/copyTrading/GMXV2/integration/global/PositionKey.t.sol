// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

// import {IGMXVault} from "../../../../../src/integrations/GMXV1/interfaces/IGMXVault.sol";

import "../../BaseGMXV2.t.sol";

contract GMXV2PositionKeyIntegration is BaseGMXV2 {

    function setUp() public override {
        BaseGMXV2.setUp();
    }

    function testCorrespondingPositionKey() external {
        bytes32 _routeKey = _registerRoute.registerRoute(
            context,
            context.users.trader,
            _weth, // collateralToken
            _weth, // _indexToken
            true, // _isLong
            _ethLongMarketData
        );

        address _route = CommonHelper.routeAddress(context.dataStore, _routeKey);
        bytes32 _puppetPositionKey = IBaseOrchestrator(context.orchestrator).positionKey(_route);

        // https://github.com/gmx-io/gmx-synthetics/blob/main/contracts/position/PositionUtils.sol#L241
        bytes32 _gmxV2PositionKey = keccak256(abi.encode(
            address(_route),
            _ethMarket,
            CommonHelper.collateralToken(context.dataStore, _route),
            CommonHelper.isLong(context.dataStore, _route)
        ));

        assertEq(_puppetPositionKey, _gmxV2PositionKey, "testCorrespondingPositionKey: E1");
    }
}