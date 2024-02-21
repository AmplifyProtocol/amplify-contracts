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
// ====================== IFlashLoanHandler =====================
// ==============================================================
// Amplify Protocol: https://github.com/AmplifyProtocol

// ==============================================================

interface IFlashLoanHandler {

    // ============================================================================================
    // External Functions
    // ============================================================================================

    /// @notice Swaps just enough PUPPET to USD, sends USD to the Treasury and the remaining PUPPET to the `_receiver`
    /// @param _amount The amount of USD flash loaned
    /// @param _token The address of the token flash loaned
    /// @param _treasury The address of the Treasury
    /// @param _receiver The address of the receiver
    function execute(uint256 _amount, address _token, address _treasury, address _receiver) external;

    // ============================================================================================
    // Errors
    // ============================================================================================

    error NotVault();
}