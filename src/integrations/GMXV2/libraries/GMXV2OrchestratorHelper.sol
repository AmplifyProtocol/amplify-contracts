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
// ================== GMXV2OrchestratorHelper ===================
// ==============================================================
// Amplify Protocol: https://github.com/AmplifyProtocol

// ==============================================================

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {CommonHelper} from "../../libraries/CommonHelper.sol";

import {GMXV2Keys} from "./GMXV2Keys.sol";

import {IDataStore} from "../../utilities/interfaces/IDataStore.sol";

import {IBaseOrchestrator} from "../../interfaces/IBaseOrchestrator.sol";

import {IPriceFeed} from "../interfaces/IPriceFeed.sol";
import {IGMXDataStore} from "../interfaces/IGMXDataStore.sol";
import {IGMXPosition} from "../interfaces/IGMXPosition.sol";
import {IGMXReader} from "../interfaces/IGMXReader.sol";

/// @title GMXV2OrchestratorHelper
/// @author johnnyonline
/// @notice Helper functions for Orchestrator GMX V2 integration
library GMXV2OrchestratorHelper {

    using SafeCast for int256;

    uint256 private constant _DECIMALS = 30;

    // ============================================================================================
    // View Functions
    // ============================================================================================

    // global

    function positionKey(IDataStore _dataStore, address _route) public view returns (bytes32) {
        return keccak256(
            abi.encode(
                _route,
                gmxMarketToken(_dataStore, _route),
                CommonHelper.collateralToken(_dataStore, _route),
                CommonHelper.isLong(_dataStore, _route)
            ));
    }

    function getPrice(IDataStore _dataStore, address _token) external view returns (uint256) {
        bytes32 _priceFeedKey = keccak256(abi.encode(keccak256(abi.encode("PRICE_FEED")), _token));
        address _priceFeedAddress = IGMXDataStore(gmxDataStore(_dataStore)).getAddress(_priceFeedKey);
        if (_priceFeedAddress == address(0)) revert PriceFeedNotSet();

        IPriceFeed _priceFeed = IPriceFeed(_priceFeedAddress);

        (
            /* uint80 roundID */,
            int256 _price,
            /* uint256 startedAt */,
            uint256 _timestamp,
            /* uint80 answeredInRound */
        ) = _priceFeed.latestRoundData();

        if (_price <= 0) revert InvalidPrice();
        if (_timestamp == 0 || block.timestamp - _timestamp > 36 hours) revert StalePrice();

        return _price.toUint256() * 10 ** (_DECIMALS - _priceFeed.decimals());
    }

    // gmx contract addresses

    function gmxReader(IDataStore _dataStore) public view returns (IGMXReader) {
        return IGMXReader(_dataStore.getAddress(GMXV2Keys.GMX_READER));
    }

    function gmxDataStore(IDataStore _dataStore) public view returns (IGMXDataStore) {
        return IGMXDataStore(_dataStore.getAddress(GMXV2Keys.GMX_DATA_STORE));
    }

    function gmxMarketToken(IDataStore _dataStore, address _route) public view returns (address) {
        return _dataStore.getAddress(GMXV2Keys.routeMarketToken(_route));
    }

    // gmx data

    function positionAmounts(IDataStore _dataStore, address _route) external view returns (uint256 _size, uint256 _collateral) {
        IGMXPosition.Props memory _position = gmxReader(_dataStore).getPosition(
                address(gmxDataStore(_dataStore)), positionKey(_dataStore, _route)
        );

        _size = _position.numbers.sizeInUsd; // already in USD with 30 decimals

        address _collateralToken = CommonHelper.collateralToken(_dataStore, _route);
        uint256 _collateralTokenPrice = IBaseOrchestrator(CommonHelper.orchestrator(_dataStore)).getPrice(_collateralToken);
        _collateral = _collateralTokenPrice * _position.numbers.collateralAmount / CommonHelper.collateralTokenDecimals(_dataStore, _collateralToken);
    }

    // route

    function isWaitingForCallback(IDataStore _dataStore, bytes32 _routeKey) external view returns (bool) {
        bytes32 _orderListKey = keccak256(
            abi.encode(keccak256(abi.encode("ACCOUNT_ORDER_LIST")),
            CommonHelper.routeAddress(_dataStore, _routeKey))
        );
        return gmxDataStore(_dataStore).getBytes32Count(_orderListKey) > 0;
    }

    // ============================================================================================
    // Mutated functions
    // ============================================================================================

    function updateGMXAddresses(IDataStore _dataStore, bytes memory _data) external {
        (
            address _router,
            address _exchangeRouter,
            address _orderVault,
            address _orderHandler,
            address _reader,
            address _gmxDataStore
        ) = abi.decode(_data, (address, address, address, address, address, address));

        _dataStore.setAddress(GMXV2Keys.ROUTER, _router);
        _dataStore.setAddress(GMXV2Keys.EXCHANGE_ROUTER, _exchangeRouter);
        _dataStore.setAddress(GMXV2Keys.ORDER_VAULT, _orderVault);
        _dataStore.setAddress(GMXV2Keys.ORDER_HANDLER, _orderHandler);
        _dataStore.setAddress(GMXV2Keys.GMX_READER, _reader);
        _dataStore.setAddress(GMXV2Keys.GMX_DATA_STORE, _gmxDataStore);
    }

    // ============================================================================================
    // Errors
    // ============================================================================================

    error PriceFeedNotSet();
    error InvalidPrice();
    error StalePrice();
}