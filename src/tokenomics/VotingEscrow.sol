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
// ======================== VotingEscrow ========================
// ==============================================================
// Amplify Protocol: https://github.com/AmplifyProtocol

// ==============================================================

// Voting escrow to have time-weighted votes
// Votes have a weight depending on time, so that users are committed
// to the future of (whatever they are voting for).
// The weight in this implementation is linear, and lock cannot be more than maxtime:
// w ^
// 1 +        /
//   |      /
//   |    /
//   |  /
//   |/
// 0 +--------+------> time
//       maxtime (4 years?)

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IERC20, IVotingEscrow} from "./interfaces/IVotingEscrow.sol";

/// @title Voting Escrow
/// @author Curve Finance, Yearn Finance
/// @author johnnyonline
/// @notice Modified fork from Curve Finance: https://github.com/curvefi, Yearn Finance https://github.com/yearn
/// @notice Votes have a weight depending on time, so that users are committed to the future of (whatever they are voting for)
/// @dev The voting power is capped at 4 years, but the lock can exceed that duration.
///     Vote weight decays linearly over time.
///     A user can unlock funds early incurring a penalty.
contract VotingEscrow is IVotingEscrow {

    using SafeERC20 for IERC20;

    using SafeCast for uint256;
    using SafeCast for int256;
    using SafeCast for int128;

    uint256 public supply;

    mapping(address => LockedBalance) public locked;

    // history
    mapping(address => uint256) public epoch;
    mapping(address => mapping(uint256 => Point)) public pointHistory; // epoch -> unsigned point
    mapping(address => mapping(uint256 => int128)) public slopeChanges; // time -> signed slope change

    IERC20 private immutable _token;

    uint256 private constant _WEEK = 7 * 86400; // all future times are rounded by week
    //slither-disable-next-line divide-before-multiply
    uint256 private constant _MAX_LOCK_DURATION = 4 * 365 * 86400 / _WEEK * _WEEK; // 4 years
    uint256 private constant _SCALE = 10 ** 18;
    uint256 private constant _MAX_N_WEEKS = 522;

    // ============================================================================================
    // Constructor
    // ============================================================================================

    /// @notice Contract constructor
    /// @param __token AMPL token address
    constructor(IERC20 __token) {
        _token = __token;

        pointHistory[address(this)][0].blk = block.number;
        pointHistory[address(this)][0].ts = block.timestamp;

        emit Initialized(address(__token));
    }

    // ============================================================================================
    // External View Functions
    // ============================================================================================

    function token() external view returns (IERC20) {
        return _token;
    }

    function name() external pure returns (string memory) {
        return "Vote-escrowed AMPL";
    }

    function symbol() external pure returns (string memory) {
        return "veAMPL";
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function maxTime() external pure returns (uint256) {
        return _MAX_LOCK_DURATION;
    }

    /// @notice Get the most recently recorded point for a user
    /// @param _addr Address of the user wallet
    /// @return Last recorded point
    function getLastUserPoint(address _addr) external view returns (Point memory) {
        uint256 _epoch = epoch[_addr];
        return pointHistory[_addr][_epoch];
    }

    function getLastUserSlope(address _addr) external view returns (int128) {
        uint256 _epoch = epoch[_addr];
        return pointHistory[_addr][_epoch].slope;
    }

    function lockedEnd(address _addr) external view returns (uint256) {
        return locked[_addr].end;
    }

    function lockedAmount(address _addr) external view returns (uint256) {
        return locked[_addr].amount.toInt256().toUint256();
    }

    function findEpochByTimestamp(address _user, uint256 _ts) external view returns (uint256) {
        return _findEpochByBlock(_user, _ts, epoch[_user]);
    }

    /// @notice Get the current voting power for `user`
    /// @param _user User wallet address
    /// @param _ts Epoch time to return voting power at
    /// @return User voting power
    function balanceOf(address _user, uint256 _ts) external view returns (uint256) {
        return _balanceOf(_user, _ts);
    }

    /// @notice Measure voting power of `user` at block height `height`
    /// @dev 
    ///     Compatible with GovernorAlpha. 
    ///     `_user` can be self to get total supply at height.
    /// @param _user User's wallet address
    /// @param _height Block to calculate the voting power at
    /// @return Voting power
    function getPriorVotes(address _user, uint256 _height) external view returns (uint256) {
        require(_height <= block.number);

        uint256 _uepoch = epoch[_user];
        _uepoch = _findEpochByBlock(_user, _height, _uepoch);
        Point memory _upoint = pointHistory[_user][_uepoch];

        uint256 _maxEpoch = epoch[address(this)];
        uint256 _epoch = _findEpochByBlock(address(this), _height, _maxEpoch);
        Point memory _point0 = pointHistory[address(this)][_epoch];
        uint256 _dBlock = 0;
        uint256 _dt = 0;
        if (_epoch < _maxEpoch) {
            Point memory _point1 = pointHistory[address(this)][_epoch + 1];
            _dBlock = _point1.blk - _point0.blk;
            _dt = _point1.ts - _point0.ts;
        } else {
            _dBlock = block.number - _point0.blk;
            _dt = block.timestamp - _point0.ts;
        }
        uint256 _blockTime = _point0.ts;
        if (_dBlock != 0) {
            _blockTime += _dt * (_height - _point0.blk) / _dBlock;
        }

        _upoint = _replaySlopeChanges(_user, _upoint, _blockTime);

        return _upoint.bias.toUint256();
    }

    /// @notice Calculate total voting power
    /// @dev Adheres to the ERC20 `totalSupply` interface for Aragon compatibility
    /// @param _ts Epoch time to return voting power at
    /// @return Total voting power
    function totalSupply(uint256 _ts) external view returns (uint256) {
        return _balanceOf(address(this), _ts);
    }

    /// @notice Calculate total voting power at some point in the past
    /// @param _height Block to calculate the total voting power at
    /// @return Total voting power at `height`
    function totalSupplyAt(uint256 _height) external view returns (uint256) {
        require(_height <= block.number);

        uint256 _epoch = epoch[address(this)];
        uint256 _targetEpoch = _findEpochByBlock(address(this), _height, _epoch);

        Point memory _point = pointHistory[address(this)][_targetEpoch];

        uint256 _dt = 0;
        if (_targetEpoch < _epoch) {
            Point memory _pointNext = pointHistory[address(this)][_targetEpoch + 1];
            if (_point.blk != _pointNext.blk) {
                _dt = (_height - _point.blk) * (_pointNext.ts - _point.ts) / (_pointNext.blk - _point.blk);
            }
        } else {
            if (_point.blk != block.number) {
                _dt = (_height - _point.blk) * (block.timestamp - _point.ts) / (block.number - _point.blk);
            }
        }

        // Now dt contains info on how far are we beyond point
        _point = _replaySlopeChanges(address(this), _point, _point.ts + _dt);

        return _point.bias.toUint256();
    }

    // ============================================================================================
    // External Mutated Functions
    // ============================================================================================

    /// @notice Record global data to checkpoint
    function checkpoint() external {
        _checkpoint(address(0), LockedBalance(0, 0), LockedBalance(0, 0));
    }

    /// @notice Create or modify a lock for a user. Support deposits on behalf of a user.
    /// @dev
    ///     Minimum deposit to create a lock is 1 AMPL.
    ///     You can lock for longer than 4 years, but less than 10 years, the max voting power is capped at 4 years.
    ///     You can only increase lock duration if it has less than 4 years remaining.
    ///     You can decrease lock duration if it has more than 4 years remaining.
    /// @param _amount AMPL amount to add to a lock. 0 to not modify.
    /// @param _unlockTime Unix timestamp when the lock ends, must be in the future. 0 to not modify.
    /// @param _user A user to deposit to. If different from msg.sender, unlock_time has no effect
    function modifyLock(uint256 _amount, uint256 _unlockTime, address _user) external returns (LockedBalance memory) {
        LockedBalance memory _oldLock = locked[_user];
        LockedBalance memory _newLock = locked[_user];
        _newLock.amount += _amount;

        uint256 _unlockWeek = 0;
        if (msg.sender == _user) { // only a user can modify their own unlock time
            if (_unlockTime != 0) {
                _unlockWeek = _roundToWeek(_unlockTime); // locktime is rounded down to weeks
                require((_unlockWeek - _roundToWeek(block.timestamp)) / _WEEK < _MAX_N_WEEKS, "lock can't exceed 10 years");
                require(_unlockWeek > block.timestamp, "unlock time must be in the future");
                if (_unlockWeek - block.timestamp < _MAX_LOCK_DURATION) {
                    require(_unlockWeek > _oldLock.end, "can only increase lock duration");
                } else {
                    require(_unlockWeek > block.timestamp + _MAX_LOCK_DURATION, "can only decrease to >=4 years");
                }
                _newLock.end = _unlockWeek;
            }
        }

        // create lock
        if (_oldLock.amount == 0 && _oldLock.end == 0) {
            require(msg.sender == _user, "you can only create a lock for yourself");
            require(_amount >= 10 ** 18, "minimum amount is 1 AMPL");
            require(_unlockWeek != 0, "must specify unlock time in the future");
        } else {
            require(_oldLock.end > block.timestamp, "lock expired");
        }

        uint256 _supplyBefore = supply;
        supply = _supplyBefore + _amount;
        locked[_user] = _newLock;

        _checkpoint(_user, _oldLock, _newLock);

        emit Supply(_supplyBefore, _supplyBefore + _amount, block.timestamp);
        emit ModifyLock(msg.sender, _user, _newLock.amount, _newLock.end, block.timestamp);

        if (_amount > 0) _token.safeTransferFrom(msg.sender, address(this), _amount);

        return _newLock;
    }

    /// @notice Withdraw all tokens for `msg.sender`
    /// @dev Only possible if the lock has expired
    function withdraw() external {
        LockedBalance memory _locked = locked[msg.sender];

        require(_locked.amount > 0, "create a lock first to withdraw");
        require(_locked.end < block.timestamp, "lock expired");

        uint256 _value = _locked.amount.toInt256().toUint256();

        LockedBalance memory _oldLocked = locked[msg.sender];
        _locked.end = 0;
        _locked.amount = 0;
        locked[msg.sender] = _locked;

        uint256 _supplyBefore = supply;
        supply = _supplyBefore - _value;

        _checkpoint(msg.sender, _oldLocked, _locked);

        emit Withdraw(msg.sender, _value, block.timestamp);
        emit Supply(_supplyBefore, _supplyBefore - _value, block.timestamp);

        _token.safeTransfer(msg.sender, _value);
    }

    // ============================================================================================
    // Internal View Functions
    // ============================================================================================

    function _roundToWeek(uint256 _ts) internal pure returns (uint256) {
        //slither-disable-next-line divide-before-multiply
        return _ts / _WEEK * _WEEK;
    }

    function _lockToPoint(LockedBalance memory _lock) internal view returns (Point memory) {
        Point memory _point = Point(0, 0, block.timestamp, block.number);
        if (_lock.amount > 0) {
            int128 _slope = (_lock.amount / _MAX_LOCK_DURATION).toInt256().toInt128();
            if (_lock.end > block.timestamp + _MAX_LOCK_DURATION) { // the lock is longer than the max duration
                _point.slope = 0;
                _point.bias = _slope * _MAX_LOCK_DURATION.toInt256().toInt128();
            } else if (_lock.end > block.timestamp) { // the lock ends in the future but shorter than max duration
                _point.slope = _slope;
                _point.bias = _slope * (_lock.end - block.timestamp).toInt256().toInt128();
            }
        }

        return _point;
    }

    function _lockToKink(LockedBalance memory _lock) internal view returns (Kink memory) {
        Kink memory _kink = Kink(0, 0);
        if (_lock.amount > 0 && _lock.end > _roundToWeek(block.timestamp + _MAX_LOCK_DURATION)) { // the lock is longer than the max duration
            _kink.ts = _roundToWeek(_lock.end - _MAX_LOCK_DURATION);
            _kink.slope = (_lock.amount / _MAX_LOCK_DURATION).toInt256().toInt128();
        }

        return _kink;
    }

    /// @notice Binary search to estimate epoch height number
    /// @param _user User address
    /// @param _height Block to find
    /// @param _maxEpoch Don't go beyond this epoch
    /// @return _Epoch the block is in
    function _findEpochByBlock(address _user, uint256 _height, uint256 _maxEpoch) internal view returns (uint256) {
        uint256 __min = 0;
        uint256 __max = _maxEpoch;
        for (uint256 i = 0; i < 128; i++) { // Will be always enough for 128-bit numbers
            if (__min >= __max) {
                break;
            }
            uint256 _mid = (__min + __max + 1) / 2;
            if (pointHistory[_user][_mid].blk <= _height) {
                __min = _mid;
            } else {
                __max = _mid - 1;
            }
        }
        return __min;
    }

    /// @notice Binary search to estimate epoch timestamp
    /// @param _user User address
    /// @param _ts Timestamp to find
    /// @param _maxEpoch Don't go beyond this epoch
    /// @return Epoch the timestamp is in
    function _findEpochByTimestamp(address _user, uint256 _ts, uint256 _maxEpoch) internal view returns (uint256) {
        uint256 __min = 0;
        uint256 __max = _maxEpoch;
        for (uint256 i = 0; i < 128; i++) { // Will be always enough for 128-bit numbers
            if (__min >= __max) {
                break;
            }
            uint256 _mid = (__min + __max + 1) / 2;
            if (pointHistory[_user][_mid].ts <= _ts) {
                __min = _mid;
            } else {
                __max = _mid - 1;
            }
        }
        return __min;
    }

    /// @dev
    ///     If the `ts` is higher than MAX_N_WEEKS weeks ago, this function will return the 
    ///     balance at exactly MAX_N_WEEKS weeks instead of `ts`. 
    ///     MAX_N_WEEKS weeks is considered sufficient to cover the `MAX_LOCK_DURATION` period.
    function _replaySlopeChanges(address _user, Point memory _point, uint256 _ts) internal view returns (Point memory) {
        Point memory _upoint = _point;
        uint256 _ti = _roundToWeek(_upoint.ts);

        for (uint256 i = 0; i < _MAX_N_WEEKS; i++) {
            _ti += _WEEK;
            int128 _dSlope = 0;
            if (_ti > _ts) {
                _ti = _ts;
            } else {
                _dSlope = slopeChanges[_user][_ti];
            }
            _upoint.bias -= _upoint.slope * (_ti - _upoint.ts).toInt256().toInt128();
            if (_ti == _ts) {
                break;
            }
            _upoint.slope += _dSlope;
            _upoint.ts = _ti;
        }

        _upoint.bias = _max(0, _upoint.bias);

        return _upoint;
    }

    /// @notice Get the current voting power for `user`
    /// @param _user User wallet address
    /// @param _ts Epoch time to return voting power at
    /// @return User voting power
    function _balanceOf(address _user, uint256 _ts) internal view returns (uint256) {
        uint256 _epoch = epoch[_user];
        if (_epoch == 0) {
            return 0;
        }
        if (_ts != block.timestamp) {
            _epoch = _findEpochByTimestamp(_user, _ts, _epoch);
        }
        Point memory _upoint = pointHistory[_user][_epoch];
        
        _upoint = _replaySlopeChanges(_user, _upoint, _ts);

        return _upoint.bias.toUint256();
    }

    // ============================================================================================
    // Internal Mutated Functions
    // ============================================================================================

    function _checkpointUser(
        address _user,
        LockedBalance memory _oldLock,
        LockedBalance memory _newLock
    ) internal returns (Point[2] memory) {
        Point memory _oldPoint = _lockToPoint(_oldLock);
        Point memory _newPoint = _lockToPoint(_newLock);

        Kink memory _oldKink = _lockToKink(_oldLock);
        Kink memory _newKink = _lockToKink(_newLock);

        // schedule slope changes for the lock end
        if (_oldPoint.slope != 0 && _oldLock.end > block.timestamp) {
            slopeChanges[address(this)][_oldLock.end] += _oldPoint.slope;
            slopeChanges[_user][_oldLock.end] += _oldPoint.slope;
        }
        if (_newPoint.slope != 0 && _newLock.end > block.timestamp) {
            slopeChanges[address(this)][_newLock.end] -= _newPoint.slope;
            slopeChanges[_user][_newLock.end] -= _newPoint.slope;
        }

        // schedule kinks for locks longer than max duration
        if (_oldKink.slope != 0) {
            slopeChanges[address(this)][_oldKink.ts] -= _oldKink.slope;
            slopeChanges[_user][_oldKink.ts] -= _oldKink.slope;
            slopeChanges[address(this)][_oldLock.end] += _oldKink.slope;
            slopeChanges[_user][_oldLock.end] += _oldKink.slope;
        }
        if (_newKink.slope != 0) {
            slopeChanges[address(this)][_newKink.ts] += _newKink.slope;
            slopeChanges[_user][_newKink.ts] += _newKink.slope;
            slopeChanges[address(this)][_newLock.end] -= _newKink.slope;
            slopeChanges[_user][_newLock.end] -= _newKink.slope;
        }

        epoch[_user] += 1;
        pointHistory[_user][epoch[_user]] = _newPoint;

        return [_oldPoint, _newPoint];
    }

    function _checkpointGlobal() internal returns (Point memory) {
        Point memory _lastPoint = Point(0, 0, block.timestamp, block.number);
        uint256 _epoch = epoch[address(this)];
        if (_epoch > 0) {
            _lastPoint = pointHistory[address(this)][_epoch];
        }
        uint256 _lastCheckpoint = _lastPoint.ts;
        // initial_last_point is used for extrapolation to calculate block number
        Point memory _initialLastPoint = _lastPoint;
        uint256 _blockSlope = 0; // dblock/dt
        if (block.timestamp > _lastCheckpoint) {
            //slither-disable-next-line divide-before-multiply
            _blockSlope = _SCALE * (block.number - _lastPoint.blk) / (block.timestamp - _lastCheckpoint);
        }

        // apply weekly slope changes and record weekly global snapshots
        uint256 _ti = _roundToWeek(_lastCheckpoint);
        for (uint256 i = 0; i < 255; i++) {
            _ti = _min(_ti + _WEEK, block.timestamp);
            _lastPoint.bias -= _lastPoint.slope * (_ti - _lastCheckpoint).toInt256().toInt128();
            _lastPoint.slope += slopeChanges[address(this)][_ti]; // will read 0 if not aligned to week
            _lastPoint.bias = _max(0, _lastPoint.bias); // this can happen
            _lastPoint.slope = _max(0, _lastPoint.slope); // this shouldn't happen
            _lastCheckpoint = _ti;
            _lastPoint.ts = _ti;
            //slither-disable-next-line divide-before-multiply
            _lastPoint.blk = _initialLastPoint.blk + _blockSlope * (_ti - _initialLastPoint.ts) / _SCALE;
            _epoch += 1;
            if (_ti < block.timestamp) {
                pointHistory[address(this)][_epoch] = _lastPoint;
            } else { // skip last week
                _lastPoint.blk = block.number;
                break;
            }
        }

        epoch[address(this)] = _epoch;
        return _lastPoint; // todo -- here --> .bias && .slope always seem to be 0
    }

    /// @notice Record global and per-user data to checkpoint
    /// @param _user User's wallet address. No user checkpoint if 0x0
    /// @param _oldLock Pevious locked amount / end lock time for the user
    /// @param _newLock New locked amount / end lock time for the user
    function _checkpoint(address _user, LockedBalance memory _oldLock, LockedBalance memory _newLock) internal {
        Point[2] memory _userPoints = [Point(0, 0, 0, 0), Point(0, 0, 0, 0)];
        if (_user != address(0)) {
            _userPoints = _checkpointUser(_user, _oldLock, _newLock);
        }

        // fill pointHistory until t=now
        Point memory _lastPoint = _checkpointGlobal();

        // only affects the last checkpoint at t=now
        if (_user != address(0)) {
            // If last point was in this block, the slope change has been applied already
            // But in such case we have 0 slope(s)
            _lastPoint.slope += (_userPoints[1].slope - _userPoints[0].slope);
            _lastPoint.bias += (_userPoints[1].bias - _userPoints[0].bias);
            _lastPoint.slope = _max(0, _lastPoint.slope);
            _lastPoint.bias = _max(0, _lastPoint.bias);
        }

        // Record the changed point into history
        uint256 _epoch = epoch[address(this)];
        pointHistory[address(this)][_epoch] = _lastPoint;
    }

    function _max(int128 _a, int128 _b) internal pure returns (int128) {
        return _a > _b ? _a : _b;
    }

    function _min(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return _a < _b ? _a : _b;
    }
}