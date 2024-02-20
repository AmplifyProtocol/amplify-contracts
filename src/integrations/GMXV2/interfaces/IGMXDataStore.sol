// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.24;

interface IGMXDataStore {
    function getUint(bytes32 key) external view returns (uint256);
    function getAddress(bytes32 key) external view returns (address);
    function getBytes32Count(bytes32 key) external view returns (uint256);
    function addBytes32(bytes32 _setKey, bytes32 _value) external;
    function removeBytes32(bytes32 _setKey, bytes32 _value) external;
}