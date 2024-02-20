// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.24;

// ==============================================================
// _______                   __________________       ________             _____                  ______
// ___    |______ ______________  /__(_)__  __/____  ____  __ \______________  /_____________________  /
// __  /| |_  __ `__ \__  __ \_  /__  /__  /_ __  / / /_  /_/ /_  ___/  __ \  __/  __ \  ___/  __ \_  / 
// _  ___ |  / / / / /_  /_/ /  / _  / _  __/ _  /_/ /_  ____/_  /   / /_/ / /_ / /_/ / /__ / /_/ /  /  
// /_/  |_/_/ /_/ /_/_  .___//_/  /_/  /_/    _\__, / /_/     /_/    \____/\__/ \____/\___/ \____//_/   
//                   /_/                      /____/                                                    
// ==============================================================
// ====================== IBaseRouteFactory =====================
// ==============================================================
// Amplify Protocol: https://github.com/AmplifyProtocol

// ==============================================================

import {IDataStore} from "../utilities/interfaces/IDataStore.sol";

interface IBaseRouteFactory {

    // ============================================================================================
    // External Functions
    // ============================================================================================

    /// @notice The ```registerRoute``` function deploys a new Route Account contract
    /// @param _dataStore The dataStore contract address
    /// @param _routeTypeKey The routeTypeKey
    /// @return _route The address of the new Route
    function registerRoute(IDataStore _dataStore, bytes32 _routeTypeKey) external returns (address _route);

    // ============================================================================================
    // Events
    // ============================================================================================

    event RegisterRoute(address indexed caller, address route, address dataStore, bytes32 routeTypeKey);
}