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
// =========================== IMinter ==========================
// ==============================================================
// Amplify Protocol: https://github.com/AmplifyProtocol

// ==============================================================

interface IMinter {

    /// @notice Returns the address of the controller
    /// @return _controller The address of the controller
    function controller() external view returns (address _controller);

    /// @notice Mint everything which belongs to `_gauge` and send to it
    /// @param _gauge `ScoreGauge` address to mint for
    function mint(address _gauge) external;

    /// @notice Mint for multiple gauges
    /// @param _gauges List of `ScoreGauge` addresses
    function mintMany(address[] memory _gauges) external;

    // ============================================================================================
    // Events
    // ============================================================================================

    event Minted(address indexed gauge, uint256 minted, uint256 epoch);

    // ============================================================================================
    // Errors
    // ============================================================================================

    error GaugeIsKilled();
    error GaugeNotAdded();
    error EpochNotEnded();
    error AlreadyMinted();
}