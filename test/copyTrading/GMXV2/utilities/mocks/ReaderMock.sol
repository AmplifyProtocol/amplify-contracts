// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {GMXV2Keys} from "../../../../../src/integrations/GMXV2/libraries/GMXV2Keys.sol";

import {IGMXReader, IGMXDataStore, IGMXMarket, IGMXPosition} from "../../../../../src/integrations/GMXV2/interfaces/IGMXReader.sol";

import "./BaseMock.sol";

contract ReaderMock is BaseMock, IGMXReader {

    uint256 public size;
    uint256 public collateral;

    function getMarketBySalt(address, bytes32 _salt) external view returns (IGMXMarket.Props memory) {
        return IGMXReader(_gmxV2Reader).getMarketBySalt(_gmxV2DataStore, _salt);
    }

    function getPosition(IGMXDataStore, bytes32) external view override returns (IGMXPosition.Props memory _position) {
        _position.numbers.sizeInUsd = size;
        _position.numbers.collateralAmount = collateral;
    }

    function increasePositionAmounts(uint256 _size, uint256 _collateral) external {
        size += _size;
        collateral += _collateral;
    }

    function decreasePositionAmounts(uint256 _size, uint256 _collateral) external {
        size -= _size;
        collateral -= _collateral;
    }

    function resetPositionAmounts() external {
        size = 0;
        collateral = 0;
    }
}