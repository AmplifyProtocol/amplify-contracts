// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {Keys} from "../../libraries/Keys.sol";

import {Market} from "../libraries/Market.sol";
import {MarketUtils, Price} from "../libraries/MarketUtils.sol";
import {ReaderUtils} from "../libraries/ReaderUtils.sol";

import {IBaseOrchestrator} from "../../interfaces/IBaseOrchestrator.sol";

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

    function getMarketFees(bytes32 _routeTypeKey) override external view returns (MarketFees memory _fees) {

        ReaderUtils.MarketInfo memory _marketInfo = _getMarketInfo(_routeTypeKey);

        _fees.fundingFee = FundingFee({
            longsPayShorts: _marketInfo.nextFunding.longsPayShorts,
            amount: _marketInfo.nextFunding.fundingFactorPerSecond
        });

        _fees.borrowFee = dataStore.getBool(Keys.routeTypeIsLongKey(_routeTypeKey))
        ? _marketInfo.borrowingFactorPerSecondForLongs
        : _marketInfo.borrowingFactorPerSecondForShorts;

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

    function _getMarketInfo(bytes32 _routeTypeKey) internal view returns (ReaderUtils.MarketInfo memory _marketInfo) {
        address _marketKey = _getMarketKey(_routeTypeKey);
        Market.Props memory _marketProps = gmxReader.getMarket(address(gmxDataStore), _marketKey);
        MarketUtils.MarketPrices memory _prices = MarketUtils.MarketPrices({
            indexTokenPrice: _getPrice(_marketProps.indexToken),
            longTokenPrice: _getPrice(_marketProps.longToken),
            shortTokenPrice: _getPrice(_marketProps.shortToken)
        });

        _marketInfo = gmxReader.getMarketInfo(
            address(gmxDataStore),
            _prices,
            _marketKey
        );
    }

    function _getMarketKey(bytes32 _routeTypeKey) internal view returns (address _marketKey) {
        _marketKey = gmxDataStore.getAddress(
            keccak256(
                abi.encode(
                    keccak256(abi.encode("MARKET_SALT")),
                    salts[_routeTypeKey]
                )
            )
        );
    }

    function _getPrice(address _token) internal view returns (Price.Props memory _priceProps) {
        uint256 _stablePrice = gmxDataStore.getUint(keccak256(abi.encode(keccak256(abi.encode("STABLE_PRICE")), _token)));
        uint256 _price = IBaseOrchestrator(CommonHelper.orchestrator(dataStore)).getPrice(_token);
        if (_stablePrice > 0) {
            _priceProps.min = _price < _stablePrice ? _price : _stablePrice;
            _priceProps.max = _price < _stablePrice ? _stablePrice : _price;
        } else {
            _priceProps.min = _price;
            _priceProps.max = _price;
        }
    }
}