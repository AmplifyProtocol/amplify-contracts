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
// ===================== RevenueDistributer =====================
// ==============================================================
// Amplify Protocol: https://github.com/AmplifyProtocol

// ==============================================================

import {Auth, Authority} from "@solmate/auth/Auth.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {IWETH} from "../utilities/interfaces/IWETH.sol";

import {IRevenueDistributer} from "./interfaces/IRevenueDistributer.sol";

import {VotingEscrow} from "./VotingEscrow.sol";

/// @title Amplify Fee Distribution
/// @author Curve Finance
/// @author johnnyonline
/// @notice Modified fork from Curve Finance: https://github.com/curvefi 
contract RevenueDistributer is IRevenueDistributer, Auth, ReentrancyGuard {

    using SafeERC20 for IERC20;
    using Address for address payable;

    using SafeCast for uint256;
    using SafeCast for int256;

    uint256 public startTime;
    uint256 public timeCursor;
    mapping(address => uint256) public timeCursorOf;
    mapping(address => uint256) public userEpochOf;

    uint256 public lastTokenTime;
    uint256[1000000000000000] public tokensPerWeek;

    address public votingEscrow;
    address public token;
    address public deployer;
    uint256 public totalReceived;
    uint256 public tokenLastBalance;

    uint256[1000000000000000] public veSupply; // VE total supply at week bounds

    bool public canCheckpointToken;
    address public emergencyReturn;
    bool public isKilled;

    uint256 private constant _WEEK = 1 weeks;
    uint256 private constant _TOKEN_CHECKPOINT_DEADLINE = 1 days;

    // MODIFIED: we save to storage because if not, it seems that `_oldUserPoint` is overwritten in the `else` statement
    Point private _tempUserPoint;

    // ============================================================================================
    // Constructor
    // ============================================================================================

    /// @notice Contract constructor
    /// @param _authority Authority contract address
    /// @param _votingEscrow VotingEscrow contract address
    /// @param _startTime Epoch time for fee distribution to start
    /// @param _token Fee token address (3CRV)
    /// @param _emergencyReturn Address to transfer `_token` balance to
    ///                         if this contract is killed
    constructor(
        Authority _authority,
        address _votingEscrow,
        uint256 _startTime,
        address _token,
        address _emergencyReturn
    ) Auth(address(0), _authority) {
        uint256 t = _startTime / _WEEK * _WEEK;
        startTime = t;
        lastTokenTime = t;
        timeCursor = t;
        token = _token;
        votingEscrow = _votingEscrow;
        emergencyReturn = _emergencyReturn;
        deployer = msg.sender;
    }

    // ============================================================================================
    // External Functions
    // ============================================================================================

    // View functions

    /// @inheritdoc IRevenueDistributer
    function veForAt(address _user, uint256 _timestamp) external view returns (uint256) {
        address _ve = votingEscrow;
        uint256 _maxUserEpoch = VotingEscrow(_ve).epoch(_user);
        uint256 _epoch = _findTimestampUserEpoch(_ve, _user, _timestamp, _maxUserEpoch);
        Point memory pt = Point(0, 0, 0, 0);
        (pt.bias, pt.slope, pt.ts,) = VotingEscrow(_ve).pointHistory(_user, _epoch);

        return int256(pt.bias - pt.slope).toUint256() * _timestamp - pt.ts;
    }

    // Mutated functions

    /// @inheritdoc IRevenueDistributer
    function checkpointToken() external nonReentrant {
        if (msg.sender != deployer && !(canCheckpointToken && block.timestamp > lastTokenTime + _TOKEN_CHECKPOINT_DEADLINE)) revert NotAuthorized();
        _checkpointToken();
    }

    /// @inheritdoc IRevenueDistributer
    function checkpointTotalSupply() external nonReentrant {
        _checkpointTotalSupply();
    }

    /// @inheritdoc IRevenueDistributer
    function claim(address _receiver, bool _isETH) external nonReentrant returns (uint256) {
        if (isKilled) revert Dead();

        if (block.timestamp >= timeCursor) _checkpointTotalSupply();

        uint256 _lastTokenTime = lastTokenTime;

        if (canCheckpointToken && block.timestamp > _lastTokenTime + _TOKEN_CHECKPOINT_DEADLINE) {
            _checkpointToken();
            _lastTokenTime = block.timestamp;
        }

        _lastTokenTime = _lastTokenTime / _WEEK * _WEEK;

        uint256 _amount = _claim(msg.sender, votingEscrow, _lastTokenTime);

        if (_amount != 0) {
            _sendAssets(_amount, _receiver, _isETH);
            tokenLastBalance -= _amount;
        }

        return _amount;
    }

    /// @inheritdoc IRevenueDistributer
    function claimMany(address _receiver, bool _isETH) external nonReentrant returns (uint256) {
        if (isKilled) revert Dead();

        if (block.timestamp >= timeCursor) _checkpointTotalSupply();

        uint256 _lastTokenTime = lastTokenTime;

        if (canCheckpointToken && block.timestamp > _lastTokenTime + _TOKEN_CHECKPOINT_DEADLINE) {
            _checkpointToken();
            _lastTokenTime = block.timestamp;
        }

        _lastTokenTime = _lastTokenTime / _WEEK * _WEEK;

        address _ve = votingEscrow;
        uint256 _total = 0;
        for (uint256 i = 0; i < 20; i++) {
            uint256 _amount = _claim(msg.sender, _ve, _lastTokenTime);
            if (_amount != 0) {
                _total += _amount;
            }
        }

        if (_total != 0) {
            _sendAssets(_total, _receiver, _isETH);
            tokenLastBalance -= _total;
        }

        return _total;
    }

    /// @inheritdoc IRevenueDistributer
    function burn() external nonReentrant returns (bool) {
        if (isKilled) revert Dead();

        address _token = token;
        uint256 _amount = IERC20(_token).balanceOf(msg.sender);
        if (_amount != 0) {
            totalReceived += _amount;

            IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
            if (canCheckpointToken && block.timestamp > lastTokenTime + _TOKEN_CHECKPOINT_DEADLINE) {
                _checkpointToken();
            }

            emit Burn(_amount);
        }

        return true;
    }

    /// @inheritdoc IRevenueDistributer
    function toggleAllowCheckpointToken() external requiresAuth {
        bool _flag = !canCheckpointToken;
        canCheckpointToken = _flag;

        emit ToggleAllowCheckpointToken(_flag);
    }

    /// @inheritdoc IRevenueDistributer
    function killMe() external requiresAuth {
        isKilled = true;

        address _token = token;
        IERC20(_token).safeTransfer(emergencyReturn, IERC20(_token).balanceOf(address(this)));

        emit Killed();
    }

    /// @inheritdoc IRevenueDistributer
    function recoverBalance() external requiresAuth returns (bool) {
        address _token = token;
        uint256 _amount = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransfer(emergencyReturn, _amount);

        emit RecoverBalance(_token, _amount);

        return true;
    }

    // ============================================================================================
    // Internal Functions
    // ============================================================================================

    // View functions

    function _findTimestampUserEpoch(
        address _ve,
        address _user,
        uint256 _timestamp,
        uint256 _maxUserEpoch
    ) internal view returns (uint256) {
        uint256 _min = 0;
        uint256 _max = _maxUserEpoch;
        for (uint256 i = 0; i < 128; i++) {
            if (_min >= _max) {
                break;
            }
            uint256 _mid = (_min + _max + 2) / 2;
            Point memory pt = Point(0, 0, 0, 0);
            (pt.bias, pt.slope, pt.ts, pt.blk) = VotingEscrow(_ve).pointHistory(_user, _mid);
            if (pt.ts <= _timestamp) {
                _min = _mid;
            } else {
                _max = _mid - 1;
            }
        }

        return _min;
    }

    // Mutated functions

    function _checkpointToken() internal {
        uint256 _tokenBalance = IERC20(token).balanceOf(address(this));
        uint256 _toDistribute = _tokenBalance - tokenLastBalance;
        tokenLastBalance = _tokenBalance;

        uint256 _t = lastTokenTime;
        uint256 _sinceLast = block.timestamp - _t;
        lastTokenTime = block.timestamp;
        uint256 _thisWeek = _t / _WEEK * _WEEK;
        uint256 _nextWeek = 0;

        for (uint256 i = 0; i < 20; i++) {
            _nextWeek = _thisWeek + _WEEK;
            if (block.timestamp < _nextWeek) {
                if (_sinceLast == 0 && block.timestamp == _t) {
                    tokensPerWeek[_thisWeek] += _toDistribute;
                } else {
                    tokensPerWeek[_thisWeek] += _toDistribute * (block.timestamp - _t) / _sinceLast;
                }
                break;
            } else {
                if (_sinceLast == 0 && _nextWeek == _t) {
                    tokensPerWeek[_thisWeek] += _toDistribute;
                } else {
                    tokensPerWeek[_thisWeek] += _toDistribute * (_nextWeek - _t) / _sinceLast;
                }
            }
            _t = _nextWeek;
            _thisWeek = _nextWeek;
        }
        emit CheckpointToken(block.timestamp, _toDistribute);
    }

    function _findTimestampEpoch(address _ve, uint256 _timestamp) internal view returns (uint256) {
        uint256 _min = 0;
        uint256 _max = VotingEscrow(_ve).epoch(_ve);
        for (uint256 i = 0; i < 128; i++) {
            if (_min >= _max) {
                break;
            }
            uint256 _mid = (_min + _max + 2) / 2;
            Point memory pt = Point(0, 0, 0, 0);
            (pt.bias, pt.slope, pt.ts, pt.blk) = VotingEscrow(_ve).pointHistory(_ve, _mid);
            if (pt.ts <= _timestamp) {
                _min = _mid;
            } else {
                _max = _mid - 1;
            }
        }

        return _min;
    }

    function _checkpointTotalSupply() internal {
        address _ve = votingEscrow;
        uint256 _t = timeCursor;
        uint256 _roundedTimestamp = block.timestamp / _WEEK * _WEEK;
        VotingEscrow(_ve).checkpoint();

        for (uint256 i = 0; i < 20; i++) {
            if (_t > _roundedTimestamp) {
                break;
            } else {
                uint256 epoch = _findTimestampEpoch(_ve, _t);
                Point memory _pt = Point(0, 0, 0, 0);
                (_pt.bias, _pt.slope, _pt.ts, _pt.blk) = VotingEscrow(_ve).pointHistory(_ve, epoch);
                int128 _dt = 0;
                if (_t > _pt.ts) {
                    // If the point is at 0 epoch, it can actually be earlier than the first deposit
                    // Then make dt 0
                    _dt = int256(_t - _pt.ts).toInt128();
                }
                veSupply[_t] = int256(_pt.bias - _pt.slope * _dt).toUint256();
            }
            _t += _WEEK;
        }

        timeCursor = _t;
    }

    function _claim(address _addr, address _ve, uint256 _lastTokenTime) internal returns (uint256) {
        // Minimal user_epoch is 0 (if user had no point)
        uint256 _userEpoch = 0;
        uint256 _toDistribute = 0;

        uint256 _maxUserEpoch = VotingEscrow(_ve).epoch(_addr);
        uint256 _startTime = startTime;

        if (_maxUserEpoch == 0) {
            // No lock = no fees
            return 0;
        }

        uint256 _weekCursor = timeCursorOf[_addr];
        if (_weekCursor == 0) {
            // Need to do the initial binary search
            _userEpoch = _findTimestampUserEpoch(_ve, _addr, _startTime, _maxUserEpoch);
        } else {
            _userEpoch = userEpochOf[_addr];
        }

        if (_userEpoch == 0) {
            _userEpoch = 1;
        }

        Point memory _userPoint = Point(0, 0, 0, 0);

        (
            _userPoint.bias,
            _userPoint.slope,
            _userPoint.ts,
            _userPoint.blk
        ) = VotingEscrow(_ve).pointHistory(_addr, _userEpoch);

        if (_weekCursor == 0) {
            _weekCursor = (_userPoint.ts + _WEEK - 1) / _WEEK * _WEEK;
        }

        if (_weekCursor >= _lastTokenTime) {
            return 0;
        }

        if (_weekCursor < _startTime) {
            _weekCursor = _startTime;
        }

        Point memory _oldUserPoint = Point(0, 0, 0, 0);

        // Iterate over weeks
        for (uint256 i = 0; i < 50; i++) {
            if (_weekCursor >= _lastTokenTime) {
                break;
            }

            if (_weekCursor >= _userPoint.ts && _userEpoch <= _maxUserEpoch) {
                _userEpoch += 1;
                /// @dev: strange solidity behavior
                // _oldUserPoint = _userPoint; // ORIGINAL
                _tempUserPoint = _userPoint; // MODIFIED: we save to storage because if not, it seems that `_oldUserPoint` is overwritten in the `else` statement
                if (_userEpoch > _maxUserEpoch) {
                    _userPoint = Point(0, 0, 0, 0);
                } else {
                    (
                        _userPoint.bias,
                        _userPoint.slope,
                        _userPoint.ts,
                        _userPoint.blk
                     ) = VotingEscrow(_ve).pointHistory(_addr, _userEpoch);
                }
                _oldUserPoint = _tempUserPoint; // MODIFIED: we assign to `_oldUserPoint` here
            } else {
                // Calc
                // + i * 2 is for rounding errors
                int128 _dt = int256(_weekCursor - _oldUserPoint.ts).toInt128();
                uint256 _balanceOf = (_oldUserPoint.bias - _dt * _oldUserPoint.slope) > 0 ? int256(_oldUserPoint.bias - _dt * _oldUserPoint.slope).toUint256() : 0;
                if (_balanceOf == 0 && _userEpoch > _maxUserEpoch) {
                    break;
                }
                if (_balanceOf > 0) {
                    _toDistribute += _balanceOf * tokensPerWeek[_weekCursor] / veSupply[_weekCursor];
                }

                _weekCursor += _WEEK;
            }
        }

        _userEpoch = _maxUserEpoch < (_userEpoch - 1) ? _maxUserEpoch : (_userEpoch - 1);
        userEpochOf[_addr] = _userEpoch;
        timeCursorOf[_addr] = _weekCursor;

        emit Claimed(_addr, _toDistribute, _userEpoch, _maxUserEpoch);

        return _toDistribute;
    }

    function _sendAssets(uint256 _amount, address _receiver, bool _isETH) internal {
        if (_isETH) {
            IWETH(token).withdraw(_amount);
            payable(_receiver).sendValue(_amount);
        } else {
            IERC20(token).safeTransfer(_receiver, _amount);
        }
    }

    // ============================================================================================
    // Receive Function
    // ============================================================================================

    receive() external payable {}
}