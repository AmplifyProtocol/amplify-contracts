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
// ======================== RouteReader =========================
// ==============================================================
// Amplify Protocol: https://github.com/AmplifyProtocol

// ==============================================================

import {SharesHelper} from "../libraries/SharesHelper.sol";
import {Keys} from "../libraries/Keys.sol";

import {CommonHelper} from "./CommonHelper.sol";

import {IDataStore} from "../utilities/interfaces/IDataStore.sol";
import {IBaseOrchestrator} from "../interfaces/IBaseOrchestrator.sol";
import {IBaseRoute} from "../interfaces/IBaseRoute.sol";

/// @title RouteReader
/// @author johnnyonline
/// @notice Helper functions for reading Route data
library RouteReader {

    struct PuppetAdditionalAmountContext {
        uint256 increaseRatio;
        uint256 traderAmountIn;
        bool isOI;
        bytes32 routeKey;
    }

    struct PuppetRequest {
        uint256 additionalAmount;
        uint256 additionalShares;
        bool isAdjustmentRequired;
        bool updateLastPositionOpenedTimestamp;
    }

    // ============================================================================================
    // External Functions
    // ============================================================================================

    function orchestrator(IDataStore _dataStore) public view returns (address) {
        return _dataStore.getAddress(Keys.ORCHESTRATOR);
    }

    function positionIndex(IDataStore _dataStore) public view returns (uint256) {
        return _dataStore.getUint(Keys.positionIndexKey(address(this)));
    }

    function puppetsInPosition(IDataStore _dataStore) public view returns (address[] memory) {
        return _dataStore.getAddressArray(Keys.positionPuppetsKey(positionIndex(_dataStore), address(this)));
    }

    function positionTotalSupply(IDataStore _dataStore) public view returns (uint256) {
        return _dataStore.getUint(Keys.positionTotalSupplyKey(positionIndex(_dataStore), address(this)));
    }

    function traderShares(IDataStore _dataStore) public view returns (uint256) {
        return _dataStore.getUint(Keys.positionTraderSharesKey(positionIndex(_dataStore), address(this)));
    }

    function puppetsShares(IDataStore _dataStore) public view returns (uint256[] memory) {
        return _dataStore.getUintArray(Keys.positionPuppetsSharesKey(positionIndex(_dataStore), address(this)));
    }

    function lastAmountIn(IDataStore _dataStore, address _participant, bytes32 _routeKey) public view returns (uint256) {
        uint256 _positionIndex = positionIndex(_dataStore); 
        address _trader = CommonHelper.trader(_dataStore, CommonHelper.routeAddress(_dataStore, _routeKey));
        if (_participant == _trader) return _dataStore.getUint(Keys.positionLastTraderAmountInKey(_positionIndex, address(this)));

        address[] memory _puppets = puppetsInPosition(_dataStore);
        uint256[] memory _lastPuppetsAmountsIn = _dataStore.getUintArray(Keys.positionLastPuppetsAmountsInKey(_positionIndex, address(this)));

        uint256 _puppetsLength = _puppets.length;
        for (uint256 i = 0; i < _puppetsLength; i++) {
            if (_participant == _puppets[i]) {
                return _lastPuppetsAmountsIn[i];
            }
        }

        return 0;
    }

    function isWaitingForKeeperAdjustment(IDataStore _dataStore, address _route) public view returns (bool) {
        return _dataStore.getBool(Keys.isWaitingForKeeperAdjustmentKey(_route));
    }

    function isWaitingForCallback(IDataStore _dataStore, address _route) public view returns (bool) {
        return _dataStore.getBool(Keys.isWaitingForCallbackKey(_route));
    }

    function isKeeperRequestKey(IDataStore _dataStore, bytes32 _requestKey) public view returns (bool) {
        return _dataStore.getBool(Keys.isKeeperRequestsKey(address(this), _requestKey));
    }

    function isAvailableShares(IDataStore _dataStore) external view returns (bool) {
        uint256 _positionIndex = positionIndex(_dataStore);
        uint256 _addCollateralRequestTotalSupply = _dataStore.getUint(Keys.addCollateralRequestTotalSupplyKey(_positionIndex, address(this)));
        return positionTotalSupply(_dataStore) > 0 || _addCollateralRequestTotalSupply > 0;
    }

    function puppetsRequestData(
        IDataStore _dataStore,
        uint256 _totalSupply,
        uint256 _totalAssets,
        address[] memory _puppets
    ) external view returns (
        IBaseRoute.PuppetsRequest memory _puppetsRequest,
        bool _isAdjustmentRequired
    ) {
        uint256 _puppetsLength = _puppets.length;
        _puppetsRequest.puppetsToUpdateTimestamp = new address[](_puppetsLength);
        _puppetsRequest.puppetsShares = new uint256[](_puppetsLength);
        _puppetsRequest.puppetsAmounts = new uint256[](_puppetsLength);

        _puppetsRequest.totalSupply = _totalSupply;
        _puppetsRequest.totalAssets = _totalAssets;

        uint256 _traderAmountIn = _totalAssets;
        bool _isPositionOpen = CommonHelper.isPositionOpen(_dataStore, address(this));
        bytes32 _routeKey = CommonHelper.routeKey(_dataStore, address(this));
        PuppetAdditionalAmountContext memory _context = PuppetAdditionalAmountContext({
            increaseRatio: _getTraderCollateralIncreaseRatio(_dataStore, _isPositionOpen, _traderAmountIn, _routeKey),
            traderAmountIn: _traderAmountIn,
            isOI: _isPositionOpen,
            routeKey: _routeKey
        });

        for (uint256 i = 0; i < _puppetsLength; i++) {
            PuppetRequest memory _puppetRequest = _getPuppetRequestData(
                _dataStore,
                _puppets[i],
                _puppetsRequest.totalSupply,
                _puppetsRequest.totalAssets,
                i,
                _context
            );

            if (_puppetRequest.isAdjustmentRequired) _isAdjustmentRequired = true;
            if (_puppetRequest.updateLastPositionOpenedTimestamp) _puppetsRequest.puppetsToUpdateTimestamp[i] = _puppets[i];

            if (_puppetRequest.additionalAmount > 0) {
                _puppetsRequest.puppetsAmountIn += _puppetRequest.additionalAmount;

                _puppetsRequest.totalSupply += _puppetRequest.additionalShares;
                _puppetsRequest.totalAssets += _puppetRequest.additionalAmount;

                _puppetsRequest.puppetsShares[i] = _puppetRequest.additionalShares;
                _puppetsRequest.puppetsAmounts[i] = _puppetRequest.additionalAmount;
            }
        }
    }

    function sharesData(
        IDataStore _dataStore,
        bool _isExecuted,
        uint256 _totalAssets
    ) external view returns (
        uint256 _puppetsTotalAssets,
        uint256 _traderAssets,
        uint256 _totalSupply,
        uint256[] memory _puppetsShares
    ) {
        uint256 _traderShares;
        if (_isExecuted) {
            _totalSupply = positionTotalSupply(_dataStore);
            _traderShares = traderShares(_dataStore);
            _puppetsShares = puppetsShares(_dataStore);
        } else {
            uint256 _positionIndex = positionIndex(_dataStore);
            _totalSupply = _dataStore.getUint(Keys.addCollateralRequestTotalSupplyKey(_positionIndex, address(this)));
            _traderShares = _dataStore.getUint(Keys.addCollateralRequestTraderSharesKey(_positionIndex, address(this)));
            _puppetsShares = _dataStore.getUintArray(Keys.addCollateralRequestPuppetsSharesKey(_positionIndex, address(this)));
        }

        _traderAssets = SharesHelper.convertToAssets(_totalAssets, _totalSupply, _traderShares);
        _puppetsTotalAssets = _totalAssets - _traderAssets;
        _totalSupply -= _traderShares;
    }

    function targetLeverage(
        IDataStore _dataStore,
        uint256 _sizeIncrease,
        uint256 _traderCollateralIncrease,
        uint256 _traderSharesIncrease,
        uint256 _totalSupplyIncrease
    ) external view returns (
        uint256 _targetLeverage,
        uint256 _currentLeverage
    ) {
        uint256 _traderPositionSize;
        uint256 _traderPositionCollateral;
        {
            (uint256 _positionSize, uint256 _positionCollateral) = IBaseOrchestrator(orchestrator(_dataStore)).positionAmounts(address(this));
            uint256 _positionTotalSupply = positionTotalSupply(_dataStore);
            uint256 _traderPositionShares = traderShares(_dataStore);
            _traderPositionSize = SharesHelper.convertToAssets(_positionSize, _positionTotalSupply, _traderPositionShares);
            _traderPositionCollateral = SharesHelper.convertToAssets(_positionCollateral, _positionTotalSupply, _traderPositionShares);
        }

        uint256 _traderSizeIncrease = 0;
        if (_sizeIncrease != 0) {
            _traderSizeIncrease = SharesHelper.convertToAssets(_sizeIncrease, _totalSupplyIncrease, _traderSharesIncrease);
        }

        {
            address _collateralToken = CommonHelper.collateralToken(_dataStore, address(this));
            _traderCollateralIncrease = IBaseOrchestrator(orchestrator(_dataStore)).getPrice(_collateralToken) *
            _traderCollateralIncrease /
            CommonHelper.collateralTokenDecimals(_dataStore, _collateralToken);
        }

        {
            uint256 _basisPointsDivisor = CommonHelper.basisPointsDivisor();
            _currentLeverage = _traderPositionSize * _basisPointsDivisor / _traderPositionCollateral;
            _targetLeverage = (_traderPositionSize + _traderSizeIncrease) *
            _basisPointsDivisor /
            (_traderPositionCollateral + _traderCollateralIncrease);
        }
    }

    function validateKeeperRequest(IDataStore _dataStore) external view {
        if (!isWaitingForKeeperAdjustment(_dataStore, address(this))) revert NotWaitingForKeeperAdjustment();
        if (!_dataStore.getBool(Keys.isKeeperAdjustmentEnabledKey(address(this)))) revert KeeperAdjustmentDisabled();
    }

    // ============================================================================================
    // Private Functions
    // ============================================================================================

    function _getTraderCollateralIncreaseRatio(
        IDataStore _dataStore,
        bool _isOI,
        uint256 _traderAmountIn,
        bytes32 _routeKey
    ) private view returns (uint256 _increaseRatio) {
        if (_isOI) {
            address _trader = CommonHelper.trader(_dataStore, address(this));
            _increaseRatio = _traderAmountIn * CommonHelper.precision() / lastAmountIn(_dataStore, _trader, _routeKey);
        }

        return _increaseRatio;
    }

    function _getPuppetRequestData(
        IDataStore _dataStore,
        address _puppet,
        uint256 _totalSupply,
        uint256 _totalAssets,
        uint256 _puppetIndex,
        PuppetAdditionalAmountContext memory _context
    ) private view returns (PuppetRequest memory _puppetRequest) {
        address _route = CommonHelper.routeAddress(_dataStore, _context.routeKey);
        address _collateralToken = CommonHelper.collateralToken(_dataStore, _route);
        uint256 _allowanceAmount = CommonHelper.puppetAccountBalance(_dataStore, _puppet, _collateralToken) * CommonHelper.puppetAllowancePercentage(_dataStore, _puppet, _route) / CommonHelper.basisPointsDivisor();
        bool _canPayFee = CommonHelper.canPuppetPayAmount(_dataStore, _puppet, _collateralToken, _allowanceAmount, false);
        if (_context.isOI) {
            uint256 _positionIndex = positionIndex(_dataStore);
            uint256 _puppetLastAmountsIn = _dataStore.getUintArrayAt(Keys.positionLastPuppetsAmountsInKey(_positionIndex, _route), _puppetIndex);
            uint256 _requiredAdditionalCollateral = _puppetLastAmountsIn * _context.increaseRatio / CommonHelper.precision();
            if (_requiredAdditionalCollateral != 0) {
                if (_allowanceAmount == 0 || !_canPayFee) {
                    _puppetRequest.isAdjustmentRequired = true;
                    return _puppetRequest;
                }
                if (_requiredAdditionalCollateral > _allowanceAmount) {
                    _puppetRequest.isAdjustmentRequired = true;
                    _puppetRequest.additionalAmount = _allowanceAmount;
                } else {
                    _puppetRequest.additionalAmount = _requiredAdditionalCollateral;
                }
                _puppetRequest.additionalShares = SharesHelper.convertToShares(
                    _totalAssets,
                    _totalSupply,
                    _puppetRequest.additionalAmount
                );
            }
        } else {
            bytes32 _routeTypeKey = CommonHelper.routeType(_dataStore, _route);
            if (
                _allowanceAmount > 0
                && _canPayFee
                && _isBelowThrottleLimit(_dataStore, _puppet, _routeTypeKey)
            ) {
                _puppetRequest.additionalAmount = _allowanceAmount > _context.traderAmountIn ? _context.traderAmountIn : _allowanceAmount;
                _puppetRequest.additionalShares = SharesHelper.convertToShares(
                    _totalAssets,
                    _totalSupply,
                    _puppetRequest.additionalAmount
                );
                _puppetRequest.updateLastPositionOpenedTimestamp = true;
            }
        }
    }

    function _isBelowThrottleLimit(IDataStore _dataStore, address _puppet, bytes32 _routeTypeKey) private view returns (bool) {
        return (
            block.timestamp - _dataStore.getUint(Keys.puppetLastPositionOpenedTimestampKey(_puppet, _routeTypeKey))
            >= _dataStore.getUint(Keys.puppetThrottleLimitKey(_puppet, _routeTypeKey))
        );
    }

    // ============================================================================================
    // Errors
    // ============================================================================================

    error NotWaitingForKeeperAdjustment();
    error KeeperAdjustmentDisabled();
}