// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {IGMXDataStore} from "./IGMXDataStore.sol";
import {IGMXMarket} from "./IGMXMarket.sol";
import {IGMXPosition} from "./IGMXPosition.sol";

import {MarketUtils} from "../libraries/MarketUtils.sol";
import {ReaderUtils} from "../libraries/ReaderUtils.sol";

interface IGMXReader {
    function getMarketBySalt(address dataStore, bytes32 salt) external view returns (IGMXMarket.Props memory);
    function getPosition(address dataStore, bytes32 key) external view returns (IGMXPosition.Props memory);
    function getMarketInfo(address dataStore, MarketUtils.MarketPrices memory prices, address marketKey) external view returns (ReaderUtils.MarketInfo memory);
}