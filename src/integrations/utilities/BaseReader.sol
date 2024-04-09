// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {CommonHelper} from "../libraries/CommonHelper.sol";

import {IReader} from "./interfaces/IReader.sol";

import {DataStore} from "./DataStore.sol";

abstract contract BaseReader is IReader {

    DataStore public immutable dataStore;

    constructor (address _dataStore) {
        dataStore = DataStore(_dataStore);
    }

    function getMarketFees(bytes32 _routeTypeKey) virtual external view returns (MarketFees memory _fees);
    // function getAvailableLiquidity(bytes32 _routeTypeKey) virtual external view returns (uint256 _availableLiquidity);
    // function getOpenInterest(bytes32 _routeTypeKey) virtual external view returns (uint256 _longIO, uint256 _shortIO);
    // function getPrice(address _token) virtual external view returns (uint256 _price);
    // function getPositionFees returns PositionFees

}