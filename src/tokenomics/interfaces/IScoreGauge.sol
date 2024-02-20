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
// ========================= IScoreGauge ========================
// ==============================================================
// Amplify Protocol: https://github.com/AmplifyProtocol

// ==============================================================

interface IScoreGauge {

    struct EpochInfo {
        uint256 profitRewards;
        uint256 volumeRewards;
        uint256 totalProfit;
        uint256 totalVolume;
        uint256 profitWeight;
        uint256 volumeWeight;
        mapping(address => bool) claimed;
        mapping(address => UserPerformance) userPerformance;
    }

    struct UserPerformance {
        uint256 volume;
        uint256 profit;
    }

    /// @notice The ```claimableRewards``` returns the amount of rewards claimable by a user for a given epoch
    /// @param _epoch The uint256 value of the epoch
    /// @param _user The address of the user
    /// @return _userReward The uint256 value of the claimable rewards, with 18 decimals
    function claimableRewards(uint256 _epoch, address _user) external view returns (uint256 _userReward);

    /// @notice The ```userPerformance``` function returns the performance of a user for a given epoch
    /// @param _epoch The uint256 value of the epoch
    /// @param _user The address of the user
    /// @return _volume The uint256 value of the volume generated by the user, USD denominated, with 30 decimals
    /// @return _profit The uint256 value of the profit generated by the user, USD denominated, with 30 decimals
    function userPerformance(uint256 _epoch, address _user) external view returns (uint256 _volume, uint256 _profit);

    /// @notice The ```hasClaimed``` function returns whether a user has claimed rewards for a given epoch
    /// @param _epoch The uint256 value of the epoch
    /// @param _user The address of the user
    /// @return _hasClaimed The bool value of whether the user has claimed rewards or not
    function hasClaimed(uint256 _epoch, address _user) external view returns (bool _hasClaimed);

    /// @notice The ```isKilled``` function returns whether the ScoreGauge is killed or not
    /// @return _isKilled The bool value of the gauge status
    function isKilled() external view returns (bool _isKilled);

    /// @notice The ```claim``` function allows a user to claim rewards for a given epoch
    /// @param _epoch The uint256 value of the epoch
    /// @param _receiver The address of the receiver of rewards
    /// @return _rewards The uint256 value of the claimable rewards, with 18 decimals
    /// @return _id The uint256 value of the newly minted oPuppet id
    function claim(uint256 _epoch, address _receiver) external returns (uint256 _rewards, uint256 _id);

    /// @notice The ```claimMany``` function allows a user to claim rewards for multiple epochs
    /// @param _epochs The uint256[] value of the epochs
    /// @param _receiver The address of the receiver of rewards
    /// @return _rewards The uint256 value of the claimable rewards, with 18 decimals
    /// @return _ids The uint256[] value of the newly minted oPuppet ids
    function claimMany(uint256[] calldata _epochs, address _receiver) external returns (uint256 _rewards, uint256[] memory _ids);

    /// @notice The ```claimAndExcercise``` function allows a user to claim rewards for a given epoch and exercise the oPuppet in the same transaction
    /// @param _epoch The uint256 value of the epoch
    /// @param _receiver The address of the receiver of rewards
    /// @param _useFlashLoan The bool value of whether to use flash loan or not
    /// @return _rewards The uint256 value of the claimable rewards, with 18 decimals
    /// @return _id The uint256 value of the newly minted (and exercised) oPuppet id
    function claimAndExcercise(uint256 _epoch, address _receiver, bool _useFlashLoan) external returns (uint256 _rewards, uint256 _id);

    /// @notice The ```claimAndExcerciseMany``` function allows a user to claim rewards for multiple epochs and exercise the oPuppet in the same transaction
    /// @param _epochs The uint256[] value of the epochs
    /// @param _receiver The address of the receiver of rewards
    /// @param _useFlashLoan The bool value of whether to use flash loan or not
    /// @return _rewards The uint256 value of the claimable rewards, with 18 decimals
    /// @return _ids The uint256[] value of the newly minted (and exercised) oPuppet ids
    function claimAndExcerciseMany(uint256[] calldata _epochs, address _receiver, bool _useFlashLoan) external returns (uint256 _rewards, uint256[] memory _ids);

    /// @notice The ```claimExcerciseAndLock``` function allows a user to claim rewards for a given epoch, exercise the oPuppet and lock the rewards in the Voting Escrow the same transaction
    /// @param _epoch The uint256 value of the epoch
    /// @param _unlockTime The uint256 value of the unlock time. Used only if there's no existing lock
    /// @param _useFlashLoan The bool value of whether to use flash loan or not
    /// @return _rewards The uint256 value of the claimable rewards, with 18 decimals
    /// @return _id The uint256 value of the newly minted (and locked) oPuppet id
    function claimExcerciseAndLock(uint256 _epoch, uint256 _unlockTime, bool _useFlashLoan) external returns (uint256 _rewards, uint256 _id);

    /// @notice The ```claimExcerciseAndLockMany``` function allows a user to claim rewards for multiple epochs, exercise the oPuppet and lock the rewards in the Voting Escrow the same transaction
    /// @param _epochs The uint256[] value of the epochs
    /// @param _unlockTime The uint256 value of the unlock time. Used only if there's no existing lock
    /// @param _useFlashLoan The bool value of whether to use flash loan or not
    /// @return _rewards The uint256 value of the claimable rewards, with 18 decimals
    /// @return _ids The uint256[] value of the newly minted (and locked) oPuppet ids
    function claimExcerciseAndLockMany(uint256[] memory _epochs, uint256 _unlockTime, bool _useFlashLoan) external returns (uint256 _rewards, uint256[] memory _ids);

    /// @notice The ```addRewards``` function allows the Minter to mint rewards for the specified epoch and update the accounting
    /// @param _epoch The uint256 value of the epoch
    /// @param _amount The uint256 value of the amount of minted rewards, with 18 decimals
    function addRewards(uint256 _epoch, uint256 _amount) external;

    /// @notice The ```updateUserScore``` is called by a Route Account when a trade is settled, for each user (Trader/Puppet)
    /// @param _route The address of the route
    function updateUsersScore(address _route) external;

    /// @notice The ```updateUserScore``` is callable by a Route Account when a trade is settled, for each user (Trader/Puppet)
    /// @dev This is used for testing purposes
    /// @param _volume The uint256 value of the volume generated by the user, USD denominated, with 30 decimals
    /// @param _profit The uint256 value of the profit generated by the user, USD denominated, with 30 decimals
    /// @param _user The address of the user
    function updateUserScore(uint256 _volume, uint256 _profit, address _user) external;

    /// @notice The ```killMe``` is called by the admin to kill the gauge
    function killMe() external;

    // ============================================================================================
    // Events
    // ============================================================================================

    event DepositRewards(uint256 amount);
    event Claim(uint256 indexed epoch, uint256 userReward, address indexed user, address indexed receiver);
    event UserScoreUpdate(address indexed user, uint256 volume, uint256 profit);
    event WeightsUpdate(uint256 profitWeight, uint256 volumeWeight);

    // ============================================================================================
    // Errors
    // ============================================================================================

    error NotMinter();
    error InvalidEpoch();
    error AlreadyClaimed();
    error NotRoute();
    error InvalidWeights();
    error NoRewards();
    error ZeroAddress();
    error NotOption();
    error NoLock();
}