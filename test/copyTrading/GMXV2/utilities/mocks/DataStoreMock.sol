// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {GMXV2Keys} from "../../../../../src/integrations/GMXV2/libraries/GMXV2Keys.sol";

import {IGMXDataStore} from "../../../../../src/integrations/GMXV2/interfaces/IGMXDataStore.sol";

import "./BaseMock.sol";

contract DataStoreMock is BaseMock, IGMXDataStore {

    using EnumerableSet for EnumerableSet.Bytes32Set;

    // store for address values
    mapping(bytes32 => address) public addressValues;

    // store for uint values
    mapping(bytes32 => uint256) public uintValues;

    // store for bytes32 sets
    mapping(bytes32 => EnumerableSet.Bytes32Set) internal _bytes32Sets;

    constructor(address _router, address _exchangeRouter, address _orderVault, address _orderHandler, address _reader) {
        addressValues[GMXV2Keys.ROUTER] = _router;
        addressValues[GMXV2Keys.EXCHANGE_ROUTER] = _exchangeRouter;
        addressValues[GMXV2Keys.ORDER_VAULT] = _orderVault;
        addressValues[GMXV2Keys.ORDER_HANDLER] = _orderHandler;
        addressValues[GMXV2Keys.GMX_READER] = _reader;

        bytes32 _priceFeedKey = keccak256(abi.encode("PRICE_FEED"));
        bytes32 _wethPriceFeedKey = keccak256(abi.encode(_priceFeedKey, _weth));
        bytes32 _usdcPriceFeedKey = keccak256(abi.encode(_priceFeedKey, _usdc));
        bytes32 _usdcOldPriceFeedKey = keccak256(abi.encode(_priceFeedKey, _usdcOld));
        addressValues[_wethPriceFeedKey] = IGMXDataStore(_gmxV2DataStore).getAddress(_wethPriceFeedKey);
        addressValues[_usdcPriceFeedKey] = IGMXDataStore(_gmxV2DataStore).getAddress(_usdcPriceFeedKey);
        addressValues[_usdcOldPriceFeedKey] = IGMXDataStore(_gmxV2DataStore).getAddress(_usdcOldPriceFeedKey);
    }

    function getAddress(bytes32 _key) external view override returns (address) {
        return addressValues[_key];
    }

    function getUint(bytes32 _key) external view override returns (uint256) {
        return uintValues[_key];
    }

    function getBytes32Count(bytes32 _setKey) external view returns (uint256) {
        return _bytes32Sets[_setKey].length();
    }

    function addBytes32(bytes32 _setKey, bytes32 _value) external {
        _bytes32Sets[_setKey].add(_value);
    }

    function removeBytes32(bytes32 _setKey, bytes32 _value) external {
        _bytes32Sets[_setKey].remove(_value);
    }
}