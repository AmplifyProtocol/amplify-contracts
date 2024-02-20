// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.24;

interface IGMXV2Orchestrator {

    /// @notice The ```gmxRouter``` function returns the address of the GMX Router contract
    /// @return _router The address of the GMX Router contract
    function gmxRouter() external view returns (address _router);

    /// @notice The ```gmxPositionRouter``` function returns the address of the GMX Position Router contract
    /// @return _positionRouter The address of the GMX Position Router contract
    function gmxPositionRouter() external view returns (address _positionRouter);

    /// @notice The ```gmxVault``` function returns the address of the GMX Vault contract
    /// @return _vault The address of the GMX Vault contract
    function gmxVault() external view returns (address _vault);

    /// @notice The ```gmxReader``` function returns the address of the GMX Reader contract
    /// @return _reader The address of the GMX Reader contract
    function gmxReader() external view returns (address _reader);

    /// @notice The ```gmxDataStore``` function returns the address of the GMX Data Store contract
    /// @return _dataStore The address of the GMX Data Store contract
    function gmxDataStore() external view returns (address _dataStore);
}