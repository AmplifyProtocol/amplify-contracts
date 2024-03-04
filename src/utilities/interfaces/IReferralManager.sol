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
// ===================== IReferralManager =======================
// ==============================================================
// Amplify Protocol: https://github.com/AmplifyProtocol

// ==============================================================

interface IReferralManager {

    // ============================================================================================
    // View Functions
    // ============================================================================================

    /// @notice The ```codeTier``` function returns the tier of a given code
    /// @param _code The code
    /// @return _tier The tier
    function codeTier(bytes32 _code) external view returns (uint256 _tier);

    /// @notice The ```referrerShare``` function returns the percentage of volume/profit that the referrer earns
    /// @return _share The share percentage
    function referrerShare() external view returns (uint256 _share);

    /// @notice The ```codeBoost``` function returns the boost of a given code
    /// @param _code The code
    /// @return _boost The boost
    function codeBoost(bytes32 _code) external view returns (uint256 _boost);

    /// @notice The ```codeOwner``` function returns the owner of a given code
    /// @param _code The code
    /// @return _owner The owner
    function codeOwner(bytes32 _code) external view returns (address _owner);

    /// @notice The ```userCode``` function returns the code of a given user
    /// @param _user The user
    /// @return _code The code
    function userCode(address _user) external view returns (bytes32 _code);

    // ============================================================================================
    // Mutated Functions
    // ============================================================================================

    /// @notice The ```registerCode``` function registers a new code for the caller
    function registerCode(bytes32 _code) external;

    /// @notice The ```transferCodeOwnership``` function transfers the ownership of a given code to a new owner
    /// @param _code The code
    /// @param _newOwner The new owner
    function transferCodeOwnership(bytes32 _code, address _newOwner) external;

    /// @notice The ```useCode``` function allows a user to use a given code
    /// @param _code The code to use
    function useCode(bytes32 _code) external;

    // ============================================================================================
    // Events
    // ============================================================================================

    event RegisterCode(address indexed owner, bytes32 code);
    event TransferCodeOwnership(address indexed oldOwner, address indexed newOwner, bytes32 code);
    event UseCode(address indexed user, bytes32 code);

    // ============================================================================================
    // Errors
    // ============================================================================================

    error InvalidCode();
    error CodeAlreadyExists();
    error NotCodeOwner();
    error CodeDoesNotExist();
}