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
// ====================== GaugeController =======================
// ==============================================================
// Amplify Protocol: https://github.com/AmplifyProtocol

// ==============================================================

import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {IGaugeController} from "./interfaces/IGaugeController.sol";
import {IVotingEscrow} from "./interfaces/IVotingEscrow.sol";
import {IScoreGauge} from "./interfaces/IScoreGauge.sol";
import {IAmplify} from "./interfaces/IAmplify.sol";

/// @title Gauge Controller
/// @author Curve Finance
/// @author johnnyonline
/// @notice Modified fork from Curve Finance: https://github.com/curvefi
/// @notice Controls liquidity gauges and the issuance of coins through the gauges
contract GaugeController is Auth, IGaugeController {

    using SafeCast for int256;

    // settings

    address public immutable token;
    address public immutable votingEscrow;

    uint256 public currentEpochEndTime;

    uint256 private _currentEpoch;
    uint256 private _profitWeight;
    uint256 private _volumeWeight;

    // Gauge parameters
    // All numbers are "fixed point" on the basis of 1e18
    int128 public numberGaugeTypes;
    int128 public numberGauges;
    mapping(int128 => string) public gaugeTypeNames;

    // Needed for enumeration
    address[1000000000] public gauges;

    // we increment values by 1 prior to storing them here so we can rely on a value
    // of zero as meaning the gauge has not been set
    mapping(address => int128) public gaugeTypes_;
    mapping(address => uint256) public voteUserPower; // Total vote power used by user
    mapping(address => mapping(address => VotedSlope)) public voteUserSlopes; // user -> gauge_addr -> VotedSlope
    mapping(address => mapping(address => uint256)) public lastUserVote; // Last user vote's timestamp for each gauge address

    // Past and scheduled points for gauge weight, sum of weights per type, total weight
    // Point is for bias+slope
    // changes_* are for changes in slope
    // time_* are for the last change timestamp
    // timestamps are rounded to whole weeks

    mapping(address => mapping(uint256 => Point)) public pointsWeight; // gauge_addr -> time -> Point
    mapping(address => mapping(uint256 => uint256)) public changesWeight; // gauge_addr -> time -> slope
    mapping(address => uint256) public timeWeight; // gauge_addr -> last scheduled time (next week)

    mapping(int128 => mapping(uint256 => Point)) public pointsSum; // type_id -> time -> Point
    mapping(int128 => mapping(uint256 => uint256)) public changesSum; // type_id -> time -> slope
    uint256[1000000000] public timeSum; // type_id -> last scheduled time (next week)

    mapping(uint256 => uint256) public pointsTotal; // time -> total weight
    uint256 public timeTotal; // last scheduled time

    mapping(int128 => mapping(uint256 => uint256)) public pointsTypeWeight; // type_id -> time -> type weight
    uint256[1000000000] public timeTypeWeight; // type_id -> last scheduled time (next week)

    mapping(uint256 => EpochData) public epochData; // epoch -> EpochData

    // constants
    uint256 private constant _WEEK = 1 weeks;
    uint256 private constant _MULTIPLIER = 1e18;

    // ============================================================================================
    // Constructor
    // ============================================================================================

    /// @notice Contract constructor
    /// @param _authority `Authority` contract address
    /// @param _token `ERC20PUPPET` contract address
    /// @param _votingEscrow `VotingEscrow` contract address
    constructor(Authority _authority, address _token, address _votingEscrow) Auth(address(0), _authority) {
        if (_token == address(0)) revert ZeroAddress();
        if (_votingEscrow == address(0)) revert ZeroAddress();

        token = _token;
        votingEscrow = _votingEscrow;
        timeTotal = block.timestamp / _WEEK * _WEEK;

        _profitWeight = 2000; // 20%
        _volumeWeight = 8000; // 80%
    }

    // ============================================================================================
    // External functions
    // ============================================================================================

    // view functions

    /// @inheritdoc IGaugeController
    function profitWeight() external view returns (uint256) {
        return _profitWeight;
    }

    /// @inheritdoc IGaugeController
    function volumeWeight() external view returns (uint256) {
        return _volumeWeight;
    }

    /// @inheritdoc IGaugeController
    function getGaugeWeight(address _gauge) external view returns (uint256) {
        return pointsWeight[_gauge][timeWeight[_gauge]].bias;
    }

    /// @inheritdoc IGaugeController
    function getTypeWeight(int128 _typeID) external view returns (uint256) {
        return pointsTypeWeight[_typeID][timeTypeWeight[int256(_typeID).toUint256()]];
    }

    /// @inheritdoc IGaugeController
    function getTotalWeight() external view returns (uint256) {
        return pointsTotal[timeTotal];
    }

    /// @inheritdoc IGaugeController
    function getWeightsSumPerType(int128 _typeID) external view returns (uint256) {
        return pointsSum[_typeID][timeSum[uint256(int256(_typeID))]].bias;
    }

    /// @inheritdoc IGaugeController
    function gaugeTypes(address _gauge) external view returns (int128) {
        int128 _gaugeType = gaugeTypes_[_gauge];
        if (_gaugeType == 0) revert GaugeTypeNotSet();

        return _gaugeType - 1;
    }

    /// @inheritdoc IGaugeController
    function gaugeRelativeWeight(address _gauge, uint256 _time) external view returns (uint256) {
        return _gaugeRelativeWeight(_gauge, _time);
    }

    /// @inheritdoc IGaugeController
    function epoch() external view returns (uint256) {
        return _currentEpoch;
    }

    /// @inheritdoc IGaugeController
    function epochTimeframe(uint256 _epoch) external view returns (uint256, uint256) {
        return (epochData[_epoch].startTime, epochData[_epoch].endTime);
    }

    /// @inheritdoc IGaugeController
    function gaugeWeightForEpoch(uint256 _epoch, address _gauge) external view returns (uint256) {
        return epochData[_epoch].gaugeWeights[_gauge];
    }

    /// @inheritdoc IGaugeController
    function hasEpochEnded(uint256 _epoch) external view returns (bool) {
        return epochData[_epoch].hasEnded;
    }

    // mutated functions

    /// @inheritdoc IGaugeController
    function gaugeRelativeWeightWrite(address addr, uint256 time) external returns (uint256) {
        _getWeight(addr);
        _getTotal(); // Also calculates get_sum
        return _gaugeRelativeWeight(addr, time);
    }

    /// @inheritdoc IGaugeController
    function checkpoint() external {
        _getTotal();
    }

    /// @inheritdoc IGaugeController
    function checkpointGauge(address _gauge) external {
        _getWeight(_gauge);
        _getTotal();
    }

    /// @inheritdoc IGaugeController
    function addGauge(address _gauge, int128 _gaugeType, uint256 _weight) external requiresAuth {
        if (_gaugeType < 0 || _gaugeType >= numberGaugeTypes) revert InvalidGaugeType();
        if (gaugeTypes_[_gauge] != 0) revert GaugeAlreadyAdded();

        int128 n = numberGauges;
        numberGauges = n + 1;
        gauges[int256(n).toUint256()] = _gauge;

        gaugeTypes_[_gauge] = _gaugeType + 1;
        uint256 _nextTime = (block.timestamp + _WEEK) / _WEEK * _WEEK;

        if (_weight > 0) {
            uint256 _typeWeight = _getTypeWeight(_gaugeType);
            uint256 _oldSum = _getSum(_gaugeType);
            uint256 _oldTotal = _getTotal();

            pointsSum[_gaugeType][_nextTime].bias = _weight + _oldSum;
            timeSum[int256(_gaugeType).toUint256()] = _nextTime;
            pointsTotal[_nextTime] = _oldTotal + _typeWeight * _weight;
            timeTotal = _nextTime;

            pointsWeight[_gauge][_nextTime].bias = _weight;
        }

        if (timeSum[int256(_gaugeType).toUint256()] == 0) {
            timeSum[int256(_gaugeType).toUint256()] = _nextTime;
        }
        timeWeight[_gauge] = _nextTime;

        emit NewGauge(_gauge, _gaugeType, _weight);
    }

    /// @inheritdoc IGaugeController
    function addType(string memory _name, uint256 _weight) external requiresAuth {
        int128 _typeID = numberGaugeTypes;
        gaugeTypeNames[_typeID] = _name;
        numberGaugeTypes = _typeID + 1;
        if (_weight != 0) {
            _changeTypeWeight(_typeID, _weight);
            emit AddType(_name, _typeID);
        }
    }

    /// @inheritdoc IGaugeController
    function changeTypeWeight(int128 _typeID, uint256 _weight) external requiresAuth {
        _changeTypeWeight(_typeID, _weight);
    }

    /// @inheritdoc IGaugeController
    function changeGaugeWeight(address _gauge, uint256 _weight) external requiresAuth {
        _changeGaugeWeight(_gauge, _weight);
    }

    /// @inheritdoc IGaugeController
    function voteForGaugeWeights(address _gauge, uint256 _userWeight) external {
        if (_userWeight > 10000) revert InvalidUserWeight();
        if (_currentEpoch == 0) revert EpochNotSet();
        if (lastUserVote[msg.sender][_gauge] >= _currentEpoch) revert AlreadyVoted();

        uint256 _lockEnd = IVotingEscrow(votingEscrow).lockedEnd(msg.sender);
        uint256 _nextTime = (block.timestamp + _WEEK) / _WEEK * _WEEK;
        if (_lockEnd <= _nextTime) revert TokenLockExpiresTooSoon();

        int128 _gaugeType = gaugeTypes_[_gauge] - 1;
        if (_gaugeType < 0) revert GaugeNotAdded();

        VotedSlope memory _oldSlope = voteUserSlopes[msg.sender][_gauge];
        uint256 _oldBias = _oldSlope.slope * _oldDT(_oldSlope.end, _nextTime);
        VotedSlope memory _newSlope = _createNewSlope(_userWeight, _lockEnd);

        _updatePowerUsed(_newSlope.power, _oldSlope.power);
        _updateSlopes(_gauge, _gaugeType, _oldSlope, _newSlope, _nextTime, _oldBias, _lockEnd);
        _getTotal();

        voteUserSlopes[msg.sender][_gauge] = _newSlope;

        lastUserVote[msg.sender][_gauge] = _currentEpoch;

        emit VoteForGauge(block.timestamp, msg.sender, _gauge, _userWeight);
    }

    /// @inheritdoc IGaugeController
    function initializeEpoch() external requiresAuth {
        if (_currentEpoch != 0) revert AlreadyInitialized();

        _currentEpoch = 1;
        currentEpochEndTime = block.timestamp + _WEEK;

        IAmplify(token).updateMiningParameters();

        emit InitializeEpoch(block.timestamp);
    }

    /// @inheritdoc IGaugeController
    function advanceEpoch() external {
        if (_currentEpoch == 0) revert EpochNotSet();
        if (block.timestamp < currentEpochEndTime) revert EpochNotEnded();

        uint256 _numberGauges = int256(numberGauges).toUint256();
        for (uint256 i = 0; i < _numberGauges; i++) {
            _getWeight(gauges[i]);
            _getTotal();
        }

        EpochData storage _epochData = epochData[_currentEpoch];
        for (uint256 i = 0; i < _numberGauges; i++) {
            address _gauge = gauges[i];
            if (IScoreGauge(_gauge).isKilled()) continue;

            _epochData.gaugeWeights[_gauge] = _gaugeRelativeWeight(_gauge, currentEpochEndTime);
        }

        _epochData.startTime = currentEpochEndTime - _WEEK;
        _epochData.endTime = currentEpochEndTime;
        _epochData.hasEnded = true;

        _currentEpoch += 1;
        currentEpochEndTime += _WEEK;

        emit AdvanceEpoch(_currentEpoch);
    }

    /// @inheritdoc IGaugeController
    function setWeights(uint256 _profit, uint256 _volume) external requiresAuth {
        if (_profit + _volume != 10000) revert InvalidWeights();

        _profitWeight = _profit;
        _volumeWeight = _volume;

        emit SetWeights(_profit, _volume);
    }

    // ============================================================================================
    // Internal functions
    // ============================================================================================

    // mutated functions

    /// @notice Fill historic type weights week-over-week for missed checkins and return the type weight for the future week
    /// @param _gaugeType Gauge type id
    /// @return Type weight
    function _getTypeWeight(int128 _gaugeType) internal returns (uint256) {
        uint256 t = timeTypeWeight[int256(_gaugeType).toUint256()];
        if (t > 0) {
            uint256 w = pointsTypeWeight[_gaugeType][t];
            for (uint256 i = 0; i < 500; i++) {
                if (t > block.timestamp) {
                    break;
                }
                t += _WEEK;
                pointsTypeWeight[_gaugeType][t] = w;
                if (t > block.timestamp) {
                    timeTypeWeight[int256(_gaugeType).toUint256()] = t;
                }
            }
            return w;
        } else {
            return 0;
        }
    }

    /// @notice Fill sum of gauge weights for the same type week-over-week for missed checkins and return the sum for the future week
    /// @param _gaugeType Gauge type id
    /// @return Sum of weights
    function _getSum(int128 _gaugeType) internal returns (uint256) {
        uint256 t = timeSum[int256(_gaugeType).toUint256()];
        if (t > 0) {
            Point memory pt = pointsSum[_gaugeType][t];
            for (uint256 i = 0; i < 500; i++) {
                if (t > block.timestamp) {
                    break;
                }
                t += _WEEK;
                uint256 _dBias = pt.slope * _WEEK;
                if (pt.bias > _dBias) {
                    pt.bias -= _dBias;
                    uint256 _dSlope = changesSum[_gaugeType][t];
                    pt.slope -= _dSlope;
                } else {
                    pt.bias = 0;
                    pt.slope = 0;
                }
                pointsSum[_gaugeType][t] = pt;
                if (t > block.timestamp) {
                    timeSum[int256(_gaugeType).toUint256()] = t;
                }
            }
            return pt.bias;
        } else {
            return 0;
        }
    }

    /// @notice Fill historic total weights week-over-week for missed checkins and return the total for the future week
    /// @return Total weight
    function _getTotal() internal returns (uint256) {
        uint256 t = timeTotal;
        int128 _numberGaugeTypes = numberGaugeTypes;
        if (t > block.timestamp) {
            // If we have already checkpointed - still need to change the value
            t -= _WEEK;
        }
        uint256 pt = pointsTotal[t];

        for (int128 _gaugeType = 0; _gaugeType < 100; _gaugeType++) {
            if (_gaugeType == _numberGaugeTypes) {
                break;
            }
            _getSum(_gaugeType);
            _getTypeWeight(_gaugeType);
        }

        for (uint256 i = 0; i < 500; i++) {
            if (t > block.timestamp) {
                break;
            }
            t += _WEEK;
            pt = 0;
            // Scales as n_types * n_unchecked_weeks (hopefully 1 at most)
            for (int128 _gaugeType = 0; _gaugeType < 100; _gaugeType++) {
                if (_gaugeType == _numberGaugeTypes) {
                    break;
                }
                uint256 _typeSum = pointsSum[_gaugeType][t].bias;
                uint256 _typeWeight = pointsTypeWeight[_gaugeType][t];
                pt += _typeSum * _typeWeight;
            }
            pointsTotal[t] = pt;

            if (t > block.timestamp) {
                timeTotal = t;
            }
        }
        return pt;
    }

    /// @notice Fill historic gauge weights week-over-week for missed checkins and return the total for the future week
    /// @param _gauge Address of the gauge
    /// @return Gauge weight
    function _getWeight(address _gauge) internal returns (uint256) {
        uint256 t = timeWeight[_gauge];
        if (t > 0) {
            Point memory pt = pointsWeight[_gauge][t];
            for (uint256 i = 0; i < 500; i++) {
                if (t > block.timestamp) {
                    break;
                }
                t += _WEEK;
                uint256 _dBias = pt.slope * _WEEK;
                if (pt.bias > _dBias) {
                    pt.bias -= _dBias;
                    uint256 _dSlope = changesWeight[_gauge][t];
                    pt.slope -= _dSlope;
                } else {
                    pt.bias = 0;
                    pt.slope = 0;
                }
                pointsWeight[_gauge][t] = pt;
                if (t > block.timestamp) {
                    timeWeight[_gauge] = t;
                }
            }
            return pt.bias;
        } else {
            return 0;
        }
    }

    /// @notice Get Gauge relative weight (not more than 1.0) normalized to 1e18
    //          (e.g. 1.0 == 1e18). Inflation which will be received by it is
    //          inflation_rate * relative_weight / 1e18
    /// @param addr Gauge address
    /// @param time Relative weight at the specified timestamp in the past or present
    /// @return Value of relative weight normalized to 1e18
    function _gaugeRelativeWeight(address addr, uint256 time) internal view returns (uint256) {
        uint256 t = time / _WEEK * _WEEK;
        uint256 _totalWeight = pointsTotal[t];

        if (_totalWeight > 0) {
            int128 _gaugeType = gaugeTypes_[addr] - 1;
            uint256 _typeWeight = pointsTypeWeight[_gaugeType][t];
            uint256 _gaugeWeight = pointsWeight[addr][t].bias;
            return _MULTIPLIER * _typeWeight * _gaugeWeight / _totalWeight;
        } else {
            return 0;
        }
    }

    /// @notice Change type weight
    /// @param _typeID Type id
    /// @param weight New type weight
    function _changeTypeWeight(int128 _typeID, uint256 weight) internal {
        uint256 _oldWeight = _getTypeWeight(_typeID);
        uint256 _oldSum = _getSum(_typeID);
        uint256 _totalWeight = _getTotal();
        uint256 _nextTime = (block.timestamp + _WEEK) / _WEEK * _WEEK;

        _totalWeight = _totalWeight + _oldSum * weight - _oldSum * _oldWeight;
        pointsTotal[_nextTime] = _totalWeight;
        pointsTypeWeight[_typeID][_nextTime] = weight;
        timeTotal = _nextTime;
        timeTypeWeight[int256(_typeID).toUint256()] = _nextTime;

        emit NewTypeWeight(_typeID, _nextTime, weight, _totalWeight);
    }

    function _changeGaugeWeight(address addr, uint256 weight) internal {
        // Change gauge weight
        // Only needed when testing in reality
        int128 _gaugeType = gaugeTypes_[addr] - 1;
        uint256 _oldGaugeWeight = _getWeight(addr);
        uint256 _typeWeight = _getTypeWeight(_gaugeType);
        uint256 _oldSum = _getSum(_gaugeType);
        uint256 _totalWeight = _getTotal();
        uint256 _nextTime = (block.timestamp + _WEEK) / _WEEK * _WEEK;

        pointsWeight[addr][_nextTime].bias = weight;
        timeWeight[addr] = _nextTime;

        uint256 _newSum = _oldSum + weight - _oldGaugeWeight;
        pointsSum[_gaugeType][_nextTime].bias = _newSum;
        timeSum[int256(_gaugeType).toUint256()] = _nextTime;

        _totalWeight = _totalWeight + _newSum * _typeWeight - _oldSum * _typeWeight;
        pointsTotal[_nextTime] = _totalWeight;
        timeTotal = _nextTime;

        emit NewGaugeWeight(addr, block.timestamp, weight, _totalWeight);
    }

    function _oldDT(uint256 _oldSlopeEnd, uint256 _nextTime) internal pure returns (uint256) {
        if (_oldSlopeEnd > _nextTime) {
            return _oldSlopeEnd - _nextTime;
        } else {
            return 0;
        }
    }

    function _createNewSlope(uint256 _userWeight, uint256 _lockEnd) internal view returns (VotedSlope memory) {
        return VotedSlope({
            slope: uint256(int256(IVotingEscrow(votingEscrow).getLastUserSlope(msg.sender))) * _userWeight / 10000,
            end: _lockEnd,
            power: _userWeight
        });
    }

    function _updatePowerUsed(uint256 _newSlopePower, uint256 _oldSlopePower) internal {
        uint256 _powerUsed = voteUserPower[msg.sender];
        _powerUsed = _powerUsed + _newSlopePower - _oldSlopePower;
        voteUserPower[msg.sender] = _powerUsed;
        if (_powerUsed > 10000) revert TooMuchPowerUsed();
    }

    function _updateSlopes(
        address _gauge,
        int128 _gaugeType,
        VotedSlope memory _oldSlope,
        VotedSlope memory _newSlope,
        uint256 _nextTime,
        uint256 _oldBias,
        uint256 _lockEnd
    ) internal {
        uint256 _newDT = _lockEnd - _nextTime; // dev: raises when expired
        uint256 _newBias = _newSlope.slope * _newDT;

        // Remove old and schedule new slope changes
        // Remove slope changes for old slopes
        // Schedule recording of initial slope for _nextTime
        uint256 _oldWeightBias = _getWeight(_gauge);
        uint256 _oldWeightSlope = pointsWeight[_gauge][_nextTime].slope;
        uint256 _oldSumBias = _getSum(_gaugeType);
        uint256 _oldSumSlope = pointsSum[_gaugeType][_nextTime].slope;

        pointsWeight[_gauge][_nextTime].bias = _max(_oldWeightBias + _newBias, _oldBias) - _oldBias;
        pointsSum[_gaugeType][_nextTime].bias = _max(_oldSumBias + _newBias, _oldBias) - _oldBias;
        if (_oldSlope.end > _nextTime) {
            pointsWeight[_gauge][_nextTime].slope = _max(_oldWeightSlope + _newSlope.slope, _oldSlope.slope) - _oldSlope.slope;

            pointsSum[_gaugeType][_nextTime].slope = _max(_oldSumSlope + _newSlope.slope, _oldSlope.slope) - _oldSlope.slope;
        } else {
            pointsWeight[_gauge][_nextTime].slope += _newSlope.slope;
            pointsSum[_gaugeType][_nextTime].slope += _newSlope.slope;
        }
        if (_oldSlope.end > block.timestamp) {
            // Cancel old slope changes if they still didn't happen
            changesWeight[_gauge][_oldSlope.end] -= _oldSlope.slope;
            changesSum[_gaugeType][_oldSlope.end] -= _oldSlope.slope;
        }
        // Add slope changes for new slopes
        changesWeight[_gauge][_newSlope.end] += _newSlope.slope;
        changesSum[_gaugeType][_newSlope.end] += _newSlope.slope;
    }

    function _max(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return _a >= _b ? _a : _b;
    }
}