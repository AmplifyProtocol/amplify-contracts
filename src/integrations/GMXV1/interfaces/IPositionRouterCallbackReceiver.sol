// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

interface IPositionRouterCallbackReceiver {

    /// @notice The ```gmxPositionCallback``` is called on by GMX keepers after a position request is executed
    /// @param positionKey The position key
    /// @param isExecuted The boolean indicating if the position was executed
    /// @param isIncrease The boolean indicating if the position was increased
    function gmxPositionCallback(bytes32 positionKey, bool isExecuted, bool isIncrease) external;
}