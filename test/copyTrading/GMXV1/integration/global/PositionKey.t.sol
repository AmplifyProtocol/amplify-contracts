// // SPDX-License-Identifier: AGPL-3.0-only
// pragma solidity 0.8.23;

// import {IGMXVault} from "../../../../../src/integrations/GMXV1/interfaces/IGMXVault.sol";

// import "../../BaseGMXV1.t.sol";

// contract GMXV1PositionKeyIntegration is BaseGMXV1 {

//     function setUp() public override {
//         BaseGMXV1.setUp();
//     }

//     function testCorrespondingPositionKey() external {
//         address _collateralToken = _weth;
//         address _indexToken = _weth;
//         bool _isLong = true;
//         bytes32 _routeKey = _registerRoute.registerRoute(
//             context,
//             context.users.trader,
//             _weth,
//             _indexToken,
//             _isLong,
//             _emptyBytes
//         );

//         address _route = CommonHelper.routeAddress(context.dataStore, _routeKey);
//         bytes32 _puppetPositionKey = IBaseOrchestrator(context.orchestrator).positionKey(_route);
//         bytes32 _gmxV1PositionKey = IGMXVault(_gmxV1Vault).getPositionKey(_route, _collateralToken, _indexToken, _isLong);

//         assertEq(_puppetPositionKey, _gmxV1PositionKey, "testCorrespondingPositionKey: E1");
//     }
// }