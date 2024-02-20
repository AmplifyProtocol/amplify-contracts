// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.24;

import {IGMXDataStore} from "./IGMXDataStore.sol";
import {IGMXMarket} from "./IGMXMarket.sol";
import {IGMXPosition} from "./IGMXPosition.sol";

interface IGMXReader {
    function getMarketBySalt(address dataStore, bytes32 salt) external view returns (IGMXMarket.Props memory);
    function getPosition(IGMXDataStore dataStore, bytes32 key) external view returns (IGMXPosition.Props memory);
}