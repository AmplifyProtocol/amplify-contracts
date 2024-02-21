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
// ========================== GMXKeys ===========================
// ==============================================================
// Amplify Protocol: https://github.com/AmplifyProtocol

// ==============================================================

/// @title GMXKeys
/// @author johnnyonline
/// @notice Keys for values in the DataStore
library GMXKeys {
    /// @dev key for GMX's Vault price feed
    bytes32 public constant VAULT_PRICE_FEED = keccak256(abi.encode("GMX_VAULT_PRICE_FEED"));
    /// @dev key for GMX's Router
    bytes32 public constant ROUTER = keccak256(abi.encode("GMX_ROUTER"));
    /// @dev key for GMX's Vault
    bytes32 public constant VAULT = keccak256(abi.encode("GMX_VAULT"));
    /// @dev key for GMX's Position Router
    bytes32 public constant POSITION_ROUTER = keccak256(abi.encode("GMX_POSITION_ROUTER"));
}