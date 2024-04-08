// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {MarketUtils, Prices} from "../libraries/MarketUtils.sol";

import {IGMXDataStore} from "../interfaces/IGMXDataStore.sol";
import {IGMXReader} from "../interfaces/IGMXReader.sol";

import {BaseReader, CommonHelper} from "../../utilities/BaseReader.sol";

contract GMXV2Reader is BaseReader, Ownable {

    mapping(bytes32 => bytes32) public salts; // routeTypeKey => marketSalt

    IGMXDataStore public immutable gmxDataStore;
    IGMXReader public immutable gmxReader;

    // https://github.com/gmx-io/gmx-synthetics/blob/main/contracts/market/MarketFactory.sol#L62
    bytes32 public constant MARKET_TYPE = 0x4bd5869a01440a9ac6d7bf7aa7004f402b52b845f20e2cec925101e13d84d075;

    constructor(address _dataStore, address _gmxDataStore) BaseReader(_dataStore) Ownable(msg.sender) {
        gmxDataStore = IGMXDataStore(_gmxDataStore);
    }

    // ============================================================================================
    // View Functions
    // ============================================================================================

    function getFees(bytes32 _routeTypeKey) override external view returns (Fees memory _fees) {
        // uint256 dexExecutionFee;
        // uint256 amplifyExecutionFee;
        // uint256 fundingFee;
        // uint256 borrowFee;
        // uint256 priceImpact;
        // uint256 openFee;
        // uint256 closeFee;

        _fees.dexExecutionFee = CommonHelper.minExecutionFee(dataStore);
        _fees.amplifyExecutionFee = CommonHelper.minPuppetExecutionFee(dataStore);
    }

    // function getAvailableLiquidity(bytes32 _routeTypeKey) virtual public view returns (uint256 _availableLiquidity);
    // function getOpenInterest(bytes32 _routeTypeKey) virtual public view returns (uint256 _longIO, uint256 _shortIO);
    // function getPrice(address _token) virtual public view returns (uint256 _price);

    // ============================================================================================
    // Mutated Functions
    // ============================================================================================

    function updateMarketSalt(bytes32 _routeTypeKey, bytes32 _salt) onlyOwner external {
        salts[_routeTypeKey] = _salt;
    }

    // ============================================================================================
    // Internal Functions
    // ============================================================================================

    function _getMarketInfo() internal {
        Price.Props memory _indexTokenPrice = Price.Props({
            min: 0,
            max: 0
        });

        Price.Props memory _longTokenPrice = Price.Props({
            min: 0,
            max: 0
        });

        Price.Props memory _shortTokenPrice = Price.Props({
            min: 0,
            max: 0
        });

        MarketUtils.MarketPrices memory _prices = MarketUtils.MarketPrices({
            _indexTokenPrice,
            _longTokenPrice,
            _shortTokenPrice
        });

        ReaderUtils.MarketInfo memory _marketInfo = gmxReader.getMarketInfo(
            address(gmxDataStore),
            _prices,
            _getMarketKey()
        );
    }

    function _getMarketKey(bytes32 _routeTypeKey) internal view returns (address _marketKey) {
        bytes32 _salt = salts[_routeTypeKey];
        _marketKey = gmxDataStore.getAddress(
            keccak256(
                abi.encode(
                    keccak256(abi.encode("MARKET_SALT")),
                    salts[_routeTypeKey]
                )
            )
        );
    }
}