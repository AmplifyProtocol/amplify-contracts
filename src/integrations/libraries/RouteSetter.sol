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
// ======================== RouteSetter =========================
// ==============================================================
// Amplify Protocol: https://github.com/AmplifyProtocol

// ==============================================================

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {CommonHelper, Keys, RouteReader, SharesHelper, IBaseOrchestrator, IBaseRoute, IDataStore} from "./RouteReader.sol";

/// @title RouteSetter
/// @author johnnyonline
/// @notice Helper functions for setting Route data
library RouteSetter {

    using SafeCast for int256;
    using SafeCast for uint256;

    using Address for address payable;

    // ============================================================================================
    // External Functions
    // ============================================================================================

    function storeKeeperRequest(IDataStore _dataStore, bytes32 _requestKey) external {
        _dataStore.setBool(Keys.isKeeperAdjustmentEnabledKey(address(this)), false);
        _dataStore.setBool(Keys.isKeeperRequestsKey(address(this), _requestKey), true);
    }

    function onCallback(IDataStore _dataStore, bool _isExecuted, bool _isIncrease, bytes32 _requestKey) external {
        uint256 _positionIndex = RouteReader.positionIndex(_dataStore);
        if (_isExecuted && _isIncrease) {
            _dataStore.incrementUint(
                Keys.cumulativeVolumeGeneratedKey(_positionIndex, address(this)),
                _dataStore.getUint(Keys.pendingSizeDeltaKey(_positionIndex, address(this)))
            );

            _allocateShares(_dataStore, _requestKey);
        }

        _dataStore.setBool(Keys.isWaitingForCallbackKey(address(this)), false);
        _dataStore.removeBytes32(Keys.pendingRequestKey(_positionIndex, address(this)));
    }

    function storeNewAddCollateralRequest(
        IDataStore _dataStore,
        uint256 _traderAmountIn,
        uint256 _traderShares,
        address[] memory _puppets
    ) external returns (uint256 _puppetsAmountIn, uint256 _totalSupply) {
        // get puppets assets and allocate request shares
        IBaseRoute.PuppetsRequest memory _puppetsRequest = _getPuppetsAssets(
            _dataStore,
            _traderShares,
            _traderAmountIn,
            _puppets
        );

        _totalSupply = _puppetsRequest.totalSupply;
        _puppetsAmountIn = _puppetsRequest.puppetsAmountIn;

        // store request data
        uint256 _positionIndex = RouteReader.positionIndex(_dataStore);
        _dataStore.setUint(Keys.addCollateralRequestPuppetsAmountInKey(_positionIndex, address(this)), _puppetsAmountIn);
        _dataStore.setUint(Keys.addCollateralRequestTraderAmountInKey(_positionIndex, address(this)), _traderAmountIn);
        _dataStore.setUint(Keys.addCollateralRequestTraderSharesKey(_positionIndex, address(this)), _traderShares);
        _dataStore.setUint(Keys.addCollateralRequestTotalSupplyKey(_positionIndex, address(this)), _totalSupply);
        _dataStore.setUintArray(Keys.addCollateralRequestPuppetsSharesKey(_positionIndex, address(this)), _puppetsRequest.puppetsShares);
        _dataStore.setUintArray(Keys.addCollateralRequestPuppetsAmountsKey(_positionIndex, address(this)), _puppetsRequest.puppetsAmounts);
    }

    function storePositionRequest(IDataStore _dataStore, uint256 _sizeDelta, bytes32 _requestKey) external {
        uint256 _positionIndex = RouteReader.positionIndex(_dataStore);
        _dataStore.setUint(Keys.pendingSizeDeltaKey(_positionIndex, address(this)), _sizeDelta);
        _dataStore.setBool(Keys.isWaitingForCallbackKey(address(this)), true);
        _dataStore.setBytes32(Keys.pendingRequestKey(_positionIndex, address(this)), _requestKey);
    }

    function setTargetLeverage(
        IDataStore _dataStore,
        uint256 _executionFee,
        uint256 _sizeIncrease,
        uint256 _traderCollateralIncrease,
        uint256 _traderSharesIncrease,
        uint256 _totalSupplyIncrease
    ) external {
        if (RouteReader.isWaitingForKeeperAdjustment(_dataStore, address(this))) {
            (uint256 _targetLeverage, uint256 _currentLeverage) = RouteReader.targetLeverage(
                _dataStore,
                _sizeIncrease,
                _traderCollateralIncrease,
                _traderSharesIncrease,
                _totalSupplyIncrease
            );

            if (_targetLeverage >= _currentLeverage) {
                _dataStore.setBool(Keys.isWaitingForKeeperAdjustmentKey(address(this)), false);
            } else {
                _dataStore.setUint(Keys.targetLeverageKey(address(this)), _targetLeverage);

                uint256 _puppetKeeperMinExecutionFee = _dataStore.getUint(Keys.PUPPET_KEEPER_MIN_EXECUTION_FEE);
                if (_puppetKeeperMinExecutionFee > 0) {
                    if (
                        _executionFee < _puppetKeeperMinExecutionFee ||
                        address(this).balance < _executionFee
                    ) revert InsufficientExecutionFee();
                    payable(RouteReader.orchestrator(_dataStore)).functionCallWithValue(
                        abi.encodeWithSignature("depositExecutionFees()"), 
                        _executionFee
                    );
                }
            }
        }
    }

    function resetRoute(IDataStore _dataStore) external {
        _dataStore.setBool(Keys.isPositionOpenKey(address(this)), false);
        _dataStore.setBool(Keys.isWaitingForCallbackKey(address(this)), false);
        _dataStore.incrementUint(Keys.positionIndexKey(address(this)), 1);
    }

    function setAdjustmentFlags(IDataStore _dataStore, bool _isExecuted, bool _isKeeperRequest) external {
        bool _isWaitingForKeeperAdjustment = RouteReader.isWaitingForKeeperAdjustment(_dataStore, address(this));
        if ((!_isExecuted && _isWaitingForKeeperAdjustment) || (_isExecuted && _isKeeperRequest)) {
            _dataStore.setBool(Keys.isWaitingForKeeperAdjustmentKey(address(this)), false);
            _dataStore.setBool(Keys.isKeeperAdjustmentEnabledKey(address(this)), false);
            _dataStore.setUint(Keys.targetLeverageKey(address(this)), 0);
        } else if ((_isExecuted && _isWaitingForKeeperAdjustment) || (!_isExecuted && _isKeeperRequest)) {
            _dataStore.setBool(Keys.isKeeperAdjustmentEnabledKey(address(this)), true);
        }
    }

    function repayBalanceData(IDataStore _dataStore, uint256 _totalAssets, bool _isExecuted, bool _isIncrease) external returns (
        uint256[] memory _puppetsAssets,
        uint256 _puppetsTotalAssets,
        uint256 _traderAssets,
        uint256 _performanceFeePaid
    ) {
        uint256 _totalSupply;
        uint256[] memory _puppetsShares;
        (
            _puppetsTotalAssets,
            _traderAssets,
            _totalSupply,
            _puppetsShares
        ) = RouteReader.sharesData(_dataStore, _isExecuted, _totalAssets);

        uint256 _positionIndex = RouteReader.positionIndex(_dataStore);

        if (_isExecuted && !_isIncrease) {
            _dataStore.decrementInt(Keys.traderPnLKey(_positionIndex, address(this)), _traderAssets.toInt256());

            uint256 _performanceFeePercentage = _dataStore.getUint(Keys.PERFORMANCE_FEE);
            int256 _puppetsPnL = _dataStore.getInt(Keys.puppetsPnLKey(_positionIndex, address(this))) - _puppetsTotalAssets.toInt256();
            if (_puppetsPnL < 0 && _performanceFeePercentage > 0) {
                _performanceFeePaid = (_puppetsPnL * -1).toUint256() * _performanceFeePercentage / CommonHelper.basisPointsDivisor();
                _puppetsTotalAssets -= _performanceFeePaid;
                _traderAssets += _performanceFeePaid;
                
                _dataStore.incrementUint(Keys.performanceFeePaidKey(_positionIndex, address(this)), _performanceFeePaid);
            }

            _dataStore.setInt(Keys.puppetsPnLKey(_positionIndex, address(this)), _puppetsPnL);
        }

        uint256 _puppetsLength = _puppetsShares.length;
        _puppetsAssets = new uint256[](_puppetsLength);

        uint256 _puppetsTotalAssetsLeft = _puppetsTotalAssets;
        for (uint256 i = 0; i < _puppetsLength; i++) {
            uint256 _puppetShares = _puppetsShares[i];
            if (_puppetShares > 0) {
                uint256 _puppetAssets = SharesHelper.convertToAssets(_puppetsTotalAssetsLeft, _totalSupply, _puppetShares);

                _puppetsAssets[i] = _puppetAssets;

                _totalSupply -= _puppetShares;
                _puppetsTotalAssetsLeft -= _puppetAssets;
            }
        }
    }

    // ============================================================================================
    // Private Functions
    // ============================================================================================

    function _addPuppetsShares(IDataStore _dataStore) private returns (uint256 _totalSupply, uint256 _totalAssets) {
        uint256 _positionIndex = RouteReader.positionIndex(_dataStore);
        _totalSupply = RouteReader.positionTotalSupply(_dataStore);
        _totalAssets = _dataStore.getUint(Keys.positionTotalAssetsKey(_positionIndex, address(this)));

        uint256[] memory _puppetsAmounts = _dataStore.getUintArray(Keys.addCollateralRequestPuppetsAmountsKey(
                _positionIndex,
                address(this)
            )
        );

        uint256 _puppetsLength = _puppetsAmounts.length;
        for (uint256 i = 0; i < _puppetsLength; i++) {
            uint256 _puppetAmountIn = _puppetsAmounts[i];
            if (_puppetAmountIn > 0) {
                uint256 _newPuppetShares = SharesHelper.convertToShares(_totalAssets, _totalSupply, _puppetAmountIn);

                _dataStore.incrementUintArrayAt(Keys.positionPuppetsSharesKey(_positionIndex, address(this)), i, _newPuppetShares);
                _dataStore.setUintArrayAt(Keys.positionLastPuppetsAmountsInKey(_positionIndex, address(this)), i, _puppetAmountIn);
                _dataStore.incrementInt(Keys.puppetsPnLKey(_positionIndex, address(this)), _puppetAmountIn.toInt256());

                _totalSupply += _newPuppetShares;
                _totalAssets += _puppetAmountIn;
            }
        }

        return (_totalSupply, _totalAssets);
    }

    function _allocateShares(IDataStore _dataStore, bytes32 _requestKey) private {
        uint256 _positionIndex = RouteReader.positionIndex(_dataStore);
        uint256 _traderAmountIn = _dataStore.getUint(Keys.addCollateralRequestTraderAmountInKey(_positionIndex, address(this)));
        if (_traderAmountIn > 0) {
            (uint256 _totalSupply, uint256 _totalAssets) = _addPuppetsShares(_dataStore);

            uint256 _newTraderShares = SharesHelper.convertToShares(_totalAssets, _totalSupply, _traderAmountIn); 
            _dataStore.incrementInt(Keys.traderPnLKey(_positionIndex, address(this)), _traderAmountIn.toInt256());
            _dataStore.incrementUint(Keys.positionTraderSharesKey(_positionIndex, address(this)), _newTraderShares);
            _dataStore.setUint(Keys.positionLastTraderAmountInKey(_positionIndex, address(this)), _traderAmountIn);

            _totalSupply += _newTraderShares;
            _totalAssets += _traderAmountIn;

            _dataStore.setBool(Keys.isPositionOpenKey(address(this)), true);
            _dataStore.setUint(Keys.positionTotalSupplyKey(_positionIndex, address(this)), _totalSupply);
            _dataStore.setUint(Keys.positionTotalAssetsKey(_positionIndex, address(this)), _totalAssets);

            IBaseOrchestrator(RouteReader.orchestrator(_dataStore)).emitSharesIncrease(
                RouteReader.puppetsShares(_dataStore),
                RouteReader.traderShares(_dataStore),
                _totalSupply,
                _requestKey
            );
        }
    }

    function _getPuppetsAssets(
        IDataStore _dataStore,
        uint256 _totalSupply,
        uint256 _totalAssets,
        address[] memory _puppets
    ) private returns (IBaseRoute.PuppetsRequest memory _puppetsRequest) {
        if (CommonHelper.isPositionOpen(_dataStore, address(this))) {
            // use existing position puppets
            _puppets = RouteReader.puppetsInPosition(_dataStore);
        } else {
            // initialize position puppets
            uint256 _puppetsLength = _puppets.length;
            uint256 _positionIndex = RouteReader.positionIndex(_dataStore);
            _dataStore.setAddressArray(Keys.positionPuppetsKey(_positionIndex, address(this)), _puppets);
            _dataStore.setUintArray(Keys.positionPuppetsSharesKey(_positionIndex, address(this)), new uint256[](_puppetsLength));
            _dataStore.setUintArray(Keys.positionLastPuppetsAmountsInKey(_positionIndex, address(this)), new uint256[](_puppetsLength));
        }

        bool _isAdjustmentRequired;
        (_puppetsRequest, _isAdjustmentRequired) = RouteReader.puppetsRequestData(_dataStore, _totalSupply, _totalAssets, _puppets);

        if (_isAdjustmentRequired) _dataStore.setBool(Keys.isWaitingForKeeperAdjustmentKey(address(this)), true);

        IBaseOrchestrator _orchestrator = IBaseOrchestrator(RouteReader.orchestrator(_dataStore));
        _orchestrator.debitAccounts(
            _puppetsRequest.puppetsAmounts,
            _puppets,
            CommonHelper.collateralToken(_dataStore, address(this))
        );

        _orchestrator.updateLastPositionOpenedTimestamp(_puppetsRequest.puppetsToUpdateTimestamp);
    }

    // ============================================================================================
    // Errors
    // ============================================================================================

    error PuppetsArrayChangedWithoutExecution();
    error InsufficientExecutionFee();
}