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
// ===================== IGaugeController =======================
// ==============================================================
// Amplify Protocol: https://github.com/AmplifyProtocol

// ==============================================================

interface IGaugeController {

        struct Point {
                uint256 bias;
                uint256 slope;
        }

        struct VotedSlope {
                uint256 slope;
                uint256 power;
                uint256 end;
        }

        struct EpochData {
                uint256 startTime;
                uint256 endTime;
                bool hasEnded;
                mapping(address => uint256) gaugeWeights; // gauge_addr -> weight
        }

        // view functions
    
        /// @notice Get current weight for the profit metric, used for calculating reward distribution
        /// @return _profitWeight The uint256 value of the profit weight, must be less than 10_000
        function profitWeight() external view returns (uint256 _profitWeight);

        /// @notice Get current weight for the volume metric, used for calculating reward distribution
        /// @return _volumeWeight The uint256 value of the volume weight, must be less than 10_000
        function volumeWeight() external view returns (uint256 _volumeWeight);

        /// @notice Get current gauge weight
        /// @param _gauge Gauge address
        /// @return _weight Gauge weight
        function getGaugeWeight(address _gauge) external view returns (uint256 _weight);

        /// @notice Get current type weight
        /// @param _typeID Type id
        /// @return _weight Type weight
        function getTypeWeight(int128 _typeID) external view returns (uint256 _weight);

        /// @notice Get current total (type-weighted) weight
        /// @return _totalWeight Total weight
        function getTotalWeight() external view returns (uint256 _totalWeight);

        /// @notice Get sum of gauge weights per type
        /// @param _typeID Type id
        /// @return _sum Sum of gauge weights per type
        function getWeightsSumPerType(int128 _typeID) external view returns (uint256 _sum);

        /// @notice Get gauge type for address
        /// @param _gauge Gauge address
        /// @return _type Gauge type
        function gaugeTypes(address _gauge) external view returns (int128 _type);

        /// @notice Get Gauge relative weight (not more than 1.0) normalized to 1e18
        //          (e.g. 1.0 == 1e18). Inflation which will be received by it is
        //          inflation_rate * relative_weight / 1e18
        /// @param _gauge Gauge address
        /// @param _time Relative weight at the specified timestamp in the past or present
        /// @return _relativeWeight Value of relative weight normalized to 1e18
        function gaugeRelativeWeight(address _gauge, uint256 _time) external view returns (uint256 _relativeWeight);

        /// @notice Get the current rewards epoch
        /// @return _currentEpoch The current rewards epoch
        function epoch() external view returns (uint256 _currentEpoch);

        /// @notice Get the start and end time for the specified epoch
        /// @param _epoch The epoch to get the start and end time for
        /// @return _startTime The start time for the specified epoch
        /// @return _endTime The end time for the specified epoch
        function epochTimeframe(uint256 _epoch) external view returns (uint256 _startTime, uint256 _endTime);

        /// @notice Get relative gauge weight for the specified epoch
        /// @param _epoch The epoch to get the relative gauge weight for
        /// @param _gauge Gauge address
        /// @return _weight Relative gauge weight for the specified epoch
        function gaugeWeightForEpoch(uint256 _epoch, address _gauge) external view returns (uint256 _weight);

        /// @notice Get whether the specified epoch has ended
        /// @param _epoch The epoch to check if it has ended
        /// @return _hasEnded Whether the specified epoch has ended
        function hasEpochEnded(uint256 _epoch) external view returns (bool _hasEnded);

        // mutated functions

        /// @notice Get gauge weight normalized to 1e18 and also fill all the unfilled values for type and gauge records
        /// @dev Any address can call, however nothing is recorded if the values are filled already
        /// @param _gauge Gauge address
        /// @param _time Relative weight at the specified timestamp in the past or present
        /// @return _relativeWeight Value of relative weight normalized to 1e18
        function gaugeRelativeWeightWrite(address _gauge, uint256 _time) external returns (uint256 _relativeWeight);

        /// @notice Checkpoint to fill data common for all gauges
        function checkpoint() external;

        /// @notice Checkpoint to fill data for both a specific gauge and common for all gauges
        /// @param _gauge Gauge address
        function checkpointGauge(address _gauge) external;

        /// @notice Add gauge `_gauge` of type `_gaugeType` with weight `_weight`
        /// @param _gauge Gauge address
        /// @param _gaugeType Gauge type
        /// @param _weight Gauge weight
        function addGauge(address _gauge, int128 _gaugeType, uint256 _weight) external;

        /// @notice Add gauge type with name `_name` and weight `_weight`
        /// @param _name Name of gauge type
        /// @param _weight Weight of gauge type
        function addType(string memory _name, uint256 _weight) external;

        /// @notice Change gauge type `_typeID` weight to `_weight`
        /// @param _typeID Gauge type id
        /// @param _weight New Gauge weight
        function changeTypeWeight(int128 _typeID, uint256 _weight) external;

        /// @notice Change weight of gauge `_gauge` to `_weight`
        /// @param _gauge `GaugeController` contract address
        /// @param _weight New Gauge weight
        function changeGaugeWeight(address _gauge, uint256 _weight) external;

        /// @notice Allocate voting power for changing pool weights
        /// @param _gauge Gauge which `msg.sender` votes for
        /// @param _userWeight Weight for a gauge in bps (units of 0.01%). Minimal is 0.01%. Ignored if 0
        function voteForGaugeWeights(address _gauge, uint256 _userWeight) external;

        /// @notice Initialize the first rewards epoch and update the mining parameters
        function initializeEpoch() external;

        /// @notice Advance to the next rewards epoch
        function advanceEpoch() external;

        /// @notice Set weights for profit and volume. Sum of weights must be 100% (10_000)
        /// @param _profit Profit weight
        /// @param _volume Volume weight
        function setWeights(uint256 _profit, uint256 _volume) external;

        // ============================================================================================
        // Events
        // ============================================================================================

        event AddType(string name, int128 typeID);
        event NewTypeWeight(int128 typeID, uint256 time, uint256 weight, uint256 totalWeight);
        event NewGaugeWeight(address gauge, uint256 time, uint256 weight, uint256 totalWeight);
        event VoteForGauge(uint256 time, address user, address gauge, uint256 weight);
        event NewGauge(address addr, int128 gaugeType, uint256 weight);
        event InitializeEpoch(uint256 timestamp);
        event AdvanceEpoch(uint256 currentEpoch);
        event SetWeights(uint256 profitWeight, uint256 volumeWeight);

        // ============================================================================================
        // Errors
        // ============================================================================================

        error TooMuchPowerUsed();
        error InvalidWeights();
        error EpochNotEnded();
        error EpochNotSet();
        error AlreadyInitialized();
        error GaugeNotAdded();
        error TokenLockExpiresTooSoon();
        error AlreadyVoted();
        error InvalidUserWeight();
        error GaugeAlreadyAdded();
        error InvalidGaugeType();
        error GaugeTypeNotSet();
        error ZeroAddress();
}