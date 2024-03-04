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
// ========================== Governor ==========================
// ==============================================================
// Amplify Protocol: https://github.com/AmplifyProtocol

// ==============================================================

import {GMXV2Keys} from "../../../../../src/integrations/GMXV2/libraries/GMXV2Keys.sol";
import {IGMXReader, IGMXDataStore, IGMXMarket, IGMXPosition} from "../../../../../src/integrations/GMXV2/interfaces/IGMXReader.sol";
import {Keys} from "src/integrations/libraries/Keys.sol";
import {IDataStore} from "src/integrations/utilities/interfaces/IDataStore.sol";
import {CommonHelper, GMXV2OrchestratorHelper} from "src/integrations/GMXV2/libraries/GMXV2OrchestratorHelper.sol";

contract Reader {
    address gmxV2Reader = address(0x38d91ED96283d62182Fc6d990C24097A918a4d9b);
    address gmxV2DataStore =address(0xFD70de6b91282D8017aA4E741e9Ae325CAb992d8);
    // address gmxV2GasUtils = address(0x6205489A49459bDD6B14CdC80D9E7991B829D48B);

    IDataStore _dataStore = IDataStore(gmxV2DataStore);

    struct ExecutionFees {
        uint256 minExecutionFees;
        uint256 minPuppetExecutionFee;
        uint256 managmentFee;
        uint256 withdrawalFee;
        uint256 performanceFee;
    }

    function getPosition(
        bytes32 _routeTypeKey,
        address _trader
    ) external view returns (uint256 _size, uint256 _collateral) {
        (, address _route) = _getRoute(_routeTypeKey, _trader);
        return GMXV2OrchestratorHelper.positionAmounts(_dataStore, _route);
    }

    function getFees()
        external
        view
        returns (ExecutionFees memory _executionFees)
    {
        _executionFees = ExecutionFees({
            minExecutionFees: _dataStore.getUint(Keys.MIN_EXECUTION_FEE),
            minPuppetExecutionFee: _dataStore.getUint(Keys.PUPPET_KEEPER_MIN_EXECUTION_FEE),
            managmentFee: _dataStore.getUint(Keys.MANAGEMENT_FEE),
            withdrawalFee: _dataStore.getUint(Keys.WITHDRAWAL_FEE),
            performanceFee: _dataStore.getUint(Keys.PERFORMANCE_FEE)
        });
    }

    function getPrice(address _token) external view returns (uint256 _price) {
        return _price = GMXV2OrchestratorHelper.getPrice(_dataStore, _token);
    }

    function getPendingRoute(
        bytes32 _routeTypeKey,
        address _trader
    ) external view returns (address _router) {
        (bytes32 _routeKey, address _route) = _getRoute(_routeTypeKey, _trader);

        if (
            GMXV2OrchestratorHelper.isWaitingForCallback(_dataStore, _routeKey)
        ) {
            return _route;
        }
    }

    function _getRoute(
        bytes32 _routeTypeKey,
        address _trader
    ) internal view returns (bytes32 _routeKey, address _route) {
        address _collateralToken = _dataStore.getAddress(Keys.routeTypeCollateralTokenKey(_routeTypeKey));
        address _indexToken = _dataStore.getAddress(Keys.routeTypeIndexTokenKey(_routeTypeKey));
        bool _isLong = _dataStore.getBool(Keys.routeTypeIsLongKey(_routeTypeKey));
        _routeKey = keccak256(abi.encode(_trader, _collateralToken, _indexToken, _isLong));
        _route = _dataStore.getAddress(Keys.routeAddressKey(_routeKey));

        return (_routeKey, _route);
    }
}

// TODO:
// function getAvailableLiquidity(bytes32 _routeTypeKey) external returns (uint256 x) {}
// function getEstRewards() internal {}
// function getOpenInterest() external returns(){}

// (Via SUBGRAPH) get24HChange(address token) external returns uint256
// (Via SUBGRAPH) get24HHigh(address token) external returns uint256
// (Via SUBGRAPH) get24HLow(address token) external returns uint256

// getLiquidationPrice(bytes32 _routeTypeKey, uint256 acceptablePrice, uint256 triggerPrice) external returns (uint256 price) {}

// (Via SUBGRAPH) ** getRoutes(address _trader) - returns all Routes owned by a trader
// ** getTraderPendingRequests(address _trader) - address[] bytes32
// ** getRoutePendingRequests(bytes32 _routeTypeKey, address _trader) - address[] bytes32
// getSwapMinAmount(address[] _path) - returns uint256

// getBestPuppets(address[] _puppets)
// getSizeDelta(address[] _puppets, uint256 _traderSizeDelta)
// getDecreaseCollateralDelta(address[] _puppets, uint256 _traderDecreaseCollagteralDelta)
