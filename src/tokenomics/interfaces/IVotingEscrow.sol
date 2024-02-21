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
// ======================= IVotingEscrow ========================
// ==============================================================
// Amplify Protocol: https://github.com/AmplifyProtocol

// ==============================================================

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IVotingEscrow {

        struct Point {
                int128 bias;
                int128 slope; // - dweight / dt
                uint256 ts;
                uint256 blk; // block
        }

        struct LockedBalance {
                uint256 amount;
                uint256 end;
        }

        struct Kink {
                int128 slope;
                uint256 ts;
        }

        struct Withdrawn {
                uint256 amount;
                uint256 penalty;
        }
    
        // ============================================================================================
        // External functions
        // ============================================================================================

        // view functions

        function token() external view returns (IERC20);
        function name() external pure returns (string memory);
        function symbol() external pure returns (string memory);
        function decimals() external pure returns (uint8);
        function maxTime() external pure returns (uint256);
        function getLastUserPoint(address _addr) external view returns (Point memory);
        function getLastUserSlope(address _addr) external view returns (int128);
        function lockedEnd(address _addr) external view returns (uint256);
        function lockedAmount(address _addr) external view returns (uint256);
        function findEpochByTimestamp(address _user, uint256 _ts) external view returns (uint256);
        function balanceOf(address _user, uint256 _ts) external view returns (uint256);
        function getPriorVotes(address _user, uint256 _height) external view returns (uint256);
        function totalSupply(uint256 _ts) external view returns (uint256);
        function totalSupplyAt(uint256 _height) external view returns (uint256);

        // mutated functions

        function checkpoint() external;
        function modifyLock(uint256 _amount, uint256 _unlockTime, address _user) external returns (LockedBalance memory);
        function withdraw() external;

        // ============================================================================================
        // Events
        // ============================================================================================

        event ModifyLock(address indexed sender, address indexed user, uint256 amount, uint256 locktime, uint256 ts);
        event Withdraw(address indexed user, uint256 amount, uint256 ts);
        event Penalty(address indexed user, uint256 amount, uint256 ts);
        event Supply(uint256 oldSupply, uint256 newSupply, uint256 ts);
        event Initialized(address token);
}