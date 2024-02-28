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
// ====================== ReferralManager =======================
// ==============================================================
// Amplify Protocol: https://github.com/AmplifyProtocol

// ==============================================================

import {Auth, Authority} from "@solmate/auth/Auth.sol";

import {IVotingEscrow} from "../tokenomics/interfaces/IVotingEscrow.sol";

import {IReferralManager} from "./interfaces/IReferralManager.sol";

/// @title ReferralManager
/// @author johnnyonline
/// @notice Manages the referral system
contract ReferralManager is IReferralManager, Auth {

    mapping(bytes32 => address) private _codeOwners;
    mapping(address => bytes32) private _userCodes;

    IVotingEscrow public votingEscrow;

    uint256 public constant TIERS = 4;
    uint256 public constant ULTRA_BOOST = 5000; // 50%
    uint256 public constant MAX_BOOST = 2500; // 25%
    uint256 public constant MID_BOOST = 1000; // 10%
    uint256 public constant LOW_BOOST = 500; // 5%
    uint256 public constant ULTRA_TIER = 1_000_000 * 1e18; // 10% of total supply
    uint256 public constant MAX_TIER = 100_000 * 1e18; // 1% of total supply
    uint256 public constant MID_TIER = 10_000 * 1e18; // 0.1% of total supply
    uint256 public constant LOW_TIER = 1000 * 1e18; // 0.01% of total supply

    // ============================================================================================
    // Constructor
    // ============================================================================================

    constructor(Authority _authority, IVotingEscrow _votingEscrow) Auth(address(0), _authority) {
        votingEscrow = _votingEscrow;
    }

    // ============================================================================================
    // View Functions
    // ============================================================================================

    /// @inheritdoc IReferralManager
    function getCodeTier(bytes32 _code) public view returns (uint256) {
        uint256 _veBalance = votingEscrow.balanceOf(_codeOwners[_code], block.timestamp);
        if (_veBalance >= ULTRA_TIER) {
            return TIERS;
        } else if (_veBalance >= MAX_TIER) {
            return TIERS - 1;
        } else if (_veBalance >= MID_TIER) {
            return TIERS - 2;
        } else if (_veBalance >= LOW_TIER) {
            return TIERS - 3;
        } else {
            return 0;
        }
    }

    /// @inheritdoc IReferralManager
    function getCodeBoost(bytes32 _code) external view returns (uint256) {
        uint256 _tier = getCodeTier(_code);
        if (_tier == TIERS) {
            return ULTRA_BOOST;
        } else if (_tier == TIERS - 1) {
            return MAX_BOOST;
        } else if (_tier == TIERS - 2) {
            return MID_BOOST;
        } else if (_tier == TIERS - 3) {
            return LOW_BOOST;
        } else {
            return 0;
        }
    }

    /// @inheritdoc IReferralManager
    function getCodeOwner(bytes32 _code) external view returns (address) {
        return _codeOwners[_code];
    }

    /// @inheritdoc IReferralManager
    function getUserCode(address _user) external view returns (bytes32) {
        return _userCodes[_user];
    }

    // ============================================================================================
    // Mutated Functions
    // ============================================================================================

    /// @inheritdoc IReferralManager
    function registerCode(bytes32 _code) external {
        if (_code == bytes32(0)) revert InvalidCode();
        if (_codeOwners[_code] != address(0)) revert CodeAlreadyExists();

        _codeOwners[_code] = msg.sender;

        emit RegisterCode(msg.sender, _code);
    }

    /// @inheritdoc IReferralManager
    function transferCodeOwnership(bytes32 _code, address _newOwner) external {
        if (_code == bytes32(0)) revert InvalidCode();
        if (_codeOwners[_code] != msg.sender) revert NotCodeOwner();

        _codeOwners[_code] = _newOwner;

        emit TransferCodeOwnership(msg.sender, _newOwner, _code);
    }

    /// @inheritdoc IReferralManager
    function useCode(bytes32 _code) external {
        if (_code == bytes32(0)) revert InvalidCode();
        if (_codeOwners[_code] == address(0)) revert CodeDoesNotExist();

        _userCodes[msg.sender] = _code;

        emit UseCode(msg.sender, _code);
    }
}