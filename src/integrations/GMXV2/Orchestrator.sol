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
// ======================== Orchestrator ========================
// ==============================================================
// Amplify Protocol: https://github.com/AmplifyProtocol

// ==============================================================

import {GMXV2OrchestratorHelper} from "./libraries/GMXV2OrchestratorHelper.sol";

import {IGMXV2Route} from "./interfaces/IGMXV2Route.sol";

import {Authority, BaseOrchestrator, IDataStore, CommonHelper} from "../BaseOrchestrator.sol";

/// @title Orchestrator
/// @author johnnyonline
/// @notice This contract extends the ```BaseOrchestrator``` and is modified to fit GMX V2
contract Orchestrator is BaseOrchestrator {

    // ============================================================================================
    // Constructor
    // ============================================================================================

    /// @notice The ```constructor``` function is called on deployment
    /// @param _authority The Authority contract instance
    /// @param _dataStore The dataStore contract instance
    constructor(Authority _authority, IDataStore _dataStore) BaseOrchestrator(_authority, _dataStore) {}

    // ============================================================================================
    // Mutated Functions
    // ============================================================================================

    function claimFundingFees(address _route, address[] memory _markets, address[] memory _tokens) external {
        if (msg.sender != CommonHelper.trader(dataStore, _route)) revert OnlyTrader();
        IGMXV2Route(_route).claimFundingFees(_markets, _tokens);
    }

    function updateDexAddresses(bytes memory _data) override external requiresAuth {
        GMXV2OrchestratorHelper.updateGMXAddresses(dataStore, _data);
    }

    // ============================================================================================
    // View Functions
    // ============================================================================================

    function positionKey(address _route) override public view returns (bytes32) {
        return GMXV2OrchestratorHelper.positionKey(dataStore, _route);
    }

    function positionAmounts(address _route) override external view returns (uint256, uint256) {
        return GMXV2OrchestratorHelper.positionAmounts(dataStore, _route);
    }

    function getPrice(address _token) override external view returns (uint256) {
        return GMXV2OrchestratorHelper.getPrice(dataStore, _token);
    }

    function isWaitingForCallback(bytes32 _routeKey) override external view returns (bool) {
        return GMXV2OrchestratorHelper.isWaitingForCallback(dataStore, _routeKey);
    }

    // ============================================================================================
    // Internal Mutated Functions
    // ============================================================================================

    function _initialize(bytes memory _data) internal override {
        GMXV2OrchestratorHelper.updateGMXAddresses(dataStore, _data);
    }

    // ============================================================================================
    // Errors
    // ============================================================================================

    error OnlyTrader();
}