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
// ====================== VestingEscrow ========================
// ==============================================================
// Amplify Protocol: https://github.com/AmplifyProtocol

// ==============================================================

import {Auth, Authority} from "@solmate/auth/Auth.sol";

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Simple Vesting Escrow
/// @author Curve Finance
/// @author johnnyonline
/// @notice Modified fork from Curve Finance: https://github.com/curvefi
/// @notice Vests `ERC20CRV` tokens for a single address
/// @dev Intended to be deployed many times via `VotingEscrowFactory`
contract VestingEscrow is Auth, ReentrancyGuard {

    using SafeERC20 for IERC20;

    address public token;

    uint256 public startTime;
    uint256 public endTime;

    mapping(address => uint256) public initialLocked;
    mapping(address => uint256) public totalClaimed;

    uint256 public initialLockedSupply;

    bool public canDisable;
    bool public isInitialized;

    mapping(address => uint256) public disabledAt;

    uint256 public constant MINIMUM_DURATION = 365 days;

    // ============================================================================================
    // Constructor
    // ============================================================================================

    /// @notice Contract constructor
    /// @param _authority Authority contract for this VestingEscrow
    constructor(Authority _authority) Auth(address(0), _authority) {
        // ensure that the original contract cannot be initialized
    }

    // ============================================================================================
    // External functions
    // ============================================================================================

    // view functions

    /// @notice Get the total number of tokens which have vested, that are held by this contract
    function vestedSupply() external view returns (uint256) {
        return _totalVested();
    }

    /// @notice Get the total number of tokens which are still locked (have not yet vested)
    function lockedSupply() external view returns (uint256) {
        return initialLockedSupply - _totalVested();
    }

    /// @notice Get the number of tokens which have vested for a given address
    /// @param _recipient address to check
    function vestedOf(address _recipient) external view returns (uint256) {
        return _totalVestedOf(_recipient, block.timestamp);
    }

    /// @notice Get the number of unclaimed, vested tokens for a given address
    /// @param _recipient address to check
    function balanceOf(address _recipient) external view returns (uint256) {
        return _totalVestedOf(_recipient, block.timestamp) - totalClaimed[_recipient];
    }

    /// @notice Get the number of locked tokens for a given address
    /// @param _recipient address to check
    function lockedOf(address _recipient) external view returns (uint256) {
        return initialLocked[_recipient] - _totalVestedOf(_recipient, block.timestamp);
    }

    // mutated functions

    /// @notice Initialize the contract.
    /// @dev This function is seperate from `__init__` because of the factory pattern
    ///      used in `VestingEscrowFactory.deploy_vesting_contract`. It may be called
    ///      once per deployment.
    /// @param _token Address of the ERC20 token being distributed
    /// @param _recipient Address to vest tokens for
    /// @param _amount Amount of tokens being vested for `_recipient`
    /// @param _startTime Epoch time at which token distribution starts
    /// @param _endTime Time until everything should be vested
    /// @param _canDisable Can admin disable recipient's ability to claim tokens?
    function initialize(
        address _token,
        address _recipient,
        uint256 _amount,
        uint256 _startTime,
        uint256 _endTime,
        bool _canDisable
    ) nonReentrant requiresAuth external returns (bool) {
        if (isInitialized) revert AlreadyInitialized();
        if (_token == address(0)) revert ZeroAddress();
        if (_recipient == address(0)) revert ZeroAddress();
        if (_amount == 0) revert ZeroAmount();
        if (_startTime >= _endTime) revert InvalidTimeRange();
        if (_endTime < block.timestamp + MINIMUM_DURATION) revert InvalidTimeRange();

        isInitialized = true;

        token = _token;
        startTime = _startTime;
        endTime = _endTime;
        canDisable = _canDisable;

        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        initialLocked[_recipient] = _amount;
        initialLockedSupply = _amount;
        emit Fund(_recipient, _amount);

        return true;
    }

    /// @notice Disable or re-enable a vested address's ability to claim tokens
    /// @dev When disabled, the address is only unable to claim tokens which are still
    ///      locked at the time of this call. It is not possible to block the claim
    ///      of tokens which have already vested.
    /// @param _recipient Address to disable or enable
    function toggleDisable(address _recipient) requiresAuth external returns (bool) {
        if (!canDisable) revert CannotDisable();

        bool _isDisabled = disabledAt[_recipient] == 0;
        if (_isDisabled) {
            disabledAt[_recipient] = block.timestamp;
        } else {
            disabledAt[_recipient] = 0;
        }

        emit ToggleDisable(_recipient, _isDisabled);
        return true;
    }

    /// @notice Disable the ability to call `toggleDisable`
    function disableCanDisable() requiresAuth external returns (bool) {
        canDisable = false;
        return true;
    }

    /// @notice Claim tokens which have vested
    /// @param _recipient Address to claim tokens for
    function claim(address _recipient) nonReentrant external {
        uint256 _t = disabledAt[_recipient];
        if (_t == 0) {
            _t = block.timestamp;
        }

        uint256 _claimable = _totalVestedOf(_recipient, _t) - totalClaimed[_recipient];
        totalClaimed[_recipient] += _claimable;

        IERC20(token).safeTransfer(_recipient, _claimable);

        emit Claim(_recipient, _claimable);
    }

    // ============================================================================================
    // Internal functions
    // ============================================================================================

    function _totalVestedOf(address _recipient, uint256 _time) internal view returns (uint256) {
        uint256 _start = startTime;
        uint256 _end = endTime;
        uint256 _locked = initialLocked[_recipient];
        if (_time < _start) {
            return 0;
        }
        return _min((_locked * (_time - _start)) / (_end - _start), _locked);
    }

    function _totalVested() internal view returns (uint256) {
        uint256 _start = startTime;
        uint256 _end = endTime;
        uint256 _locked = initialLockedSupply;
        if (block.timestamp < _start) {
            return 0;
        }
        return _min((_locked * (block.timestamp - _start)) / (_end - _start), _locked);
    }

    function _min(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return _a <= _b ? _a : _b;
    }

    // ============================================================================================
    // Events
    // ============================================================================================

    event Fund(address indexed recipient, uint256 amount);
    event Claim(address indexed recipient, uint256 claimed);
    event ToggleDisable(address indexed recipient, bool disabled);

    // ============================================================================================
    // Errors
    // ============================================================================================

    error CannotDisable();
    error ZeroAddress();
    error ZeroAmount();
    error InvalidTimeRange();
    error AlreadyInitialized();
}