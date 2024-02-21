// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

// ==============================================================
// _______                   __________________       ________             _____                  ______
// ___    |______ ______________  /__(_)__  __/____  ____  __ \______________  /_____________________  /
// __  /| |_  __ `__ \__  __ \_  /__  /__  /_ __  / / /_  /_/ /_  ___/  __ \  __/  __ \  ___/  __ \_  / 
// _  ___ |  / / / / /_  /_/ /  / _  / _  __/ _  /_/ /_  ____/_  /   / /_/ / /_ / /_/ / /__ / /_/ /  /  
// /_/  |_/_/ /_/ /_/_  .___//_/  /_/  /_/    _\__, / /_/     /_/    \____/\__/ \____/\___/ \____//_/   
//                   /_/                      /____/                                                    
// ==============================================================
// ====================== BaseRouteFactory ======================
// ==============================================================
// Amplify Protocol: https://github.com/AmplifyProtocol

// ==============================================================

import {IBaseRouteFactory, IDataStore} from "./interfaces/IBaseRouteFactory.sol";

/// @title BaseRouteFactory
/// @author johnnyonline
/// @notice BaseRouteFactory is used by the Orchestrator to create new Route Accounts
abstract contract BaseRouteFactory is IBaseRouteFactory {

    /// @inheritdoc IBaseRouteFactory
    function registerRoute(IDataStore _dataStore, bytes32 _routeTypeKey) virtual external returns (address _route);
}