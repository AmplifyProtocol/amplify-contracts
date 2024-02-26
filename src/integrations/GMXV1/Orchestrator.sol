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
// ======================== Orchestrator ========================
// ==============================================================
// Amplify Protocol: https://github.com/AmplifyProtocol

// ==============================================================

import {GMXKeys} from "./libraries/GMXKeys.sol";
import {GMXHelper, CommonHelper} from "./libraries/GMXHelper.sol";

import {IGMXVaultPriceFeed} from "./interfaces/IGMXVaultPriceFeed.sol";

import {Authority, BaseOrchestrator, IDataStore} from "../BaseOrchestrator.sol";

/// @title Orchestrator
/// @author johnnyonline
/// @notice This contract extends the ```BaseOrchestrator``` and is modified to fit GMX V1
contract Orchestrator is BaseOrchestrator {

    // ============================================================================================
    // Constructor
    // ============================================================================================

    /// @notice The ```constructor``` function is called on deployment
    /// @param _authority The Authority contract instance
    /// @param _dataStore The dataStore contract address
    constructor(Authority _authority, IDataStore _dataStore) BaseOrchestrator(_authority, _dataStore) {}

    // ============================================================================================
    // View Functions
    // ============================================================================================

    function positionKey(address _route) override public view returns (bytes32) {
        IDataStore _dataStore = dataStore;
        return keccak256(
            abi.encodePacked(
                _route,
                CommonHelper.collateralToken(_dataStore, _route),
                CommonHelper.indexToken(_dataStore, _route),
                CommonHelper.isLong(_dataStore, _route)
            ));
    }

    function positionAmounts(address _route) override external view returns (uint256, uint256) {
        return GMXHelper.positionAmounts(dataStore, _route);
    }

    function getPrice(address _token) override external view returns (uint256) {
        return IGMXVaultPriceFeed(GMXHelper.gmxVaultPriceFeed(dataStore)).getPrice(_token, false, false, false);
    }

    function isWaitingForCallback(bytes32 _routeKey) override external view returns (bool) {
        return GMXHelper.isWaitingForCallback(dataStore, _routeKey);
    }

    // ============================================================================================
    // Mutated Functions
    // ============================================================================================

    function updateDexAddresses(bytes memory _data) override external requiresAuth {
        GMXHelper.updateGMXAddresses(dataStore, _data);
    }

    // ============================================================================================
    // Internal Functions
    // ============================================================================================

    function _initialize(bytes memory _data) internal override {
        GMXHelper.updateGMXAddresses(dataStore, _data);
    }
}