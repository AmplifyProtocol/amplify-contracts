// // SPDX-License-Identifier: AGPL-3.0-only
// pragma solidity 0.8.23;

// // ==============================================================
// // _______                   __________________       ________             _____                  ______
// // ___    |______ ______________  /__(_)__  __/____  ____  __ \______________  /_____________________  /
// // __  /| |_  __ `__ \__  __ \_  /__  /__  /_ __  / / /_  /_/ /_  ___/  __ \  __/  __ \  ___/  __ \_  / 
// // _  ___ |  / / / / /_  /_/ /  / _  / _  __/ _  /_/ /_  ____/_  /   / /_/ / /_ / /_/ / /__ / /_/ /  /  
// // /_/  |_/_/ /_/ /_/_  .___//_/  /_/  /_/    _\__, / /_/     /_/    \____/\__/ \____/\___/ \____//_/   
// //                   /_/                      /____/                                                    
// // ==============================================================
// // ======================= RouteFactory =========================
// // ==============================================================
// // Amplify Protocol: https://github.com/AmplifyProtocol

// // ==============================================================

// import {BaseRouteFactory, IDataStore} from "../BaseRouteFactory.sol";

// import {Route} from "./Route.sol";

// /// @title RouteFactory
// /// @author johnnyonline
// /// @notice This contract extends the ```BaseRouteFactory``` and is modified to fit GMX V1
// contract RouteFactory is BaseRouteFactory {

//     /// @inheritdoc BaseRouteFactory
//     function registerRoute(IDataStore _dataStore, bytes32 _routeTypeKey) override external returns (address _route) {
//         _route = address(new Route(_dataStore));

//         emit RegisterRoute(msg.sender, _route, address(_dataStore), _routeTypeKey);
//     }
// }