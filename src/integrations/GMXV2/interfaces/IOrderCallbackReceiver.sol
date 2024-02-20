// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.24;

import "./IGMXEventUtils.sol";
import "./IGMXOrder.sol";

interface IOrderCallbackReceiver {

    /// @dev called after an order execution
    /// @param key the key of the order
    /// @param order the order that was executed
    function afterOrderExecution(bytes32 key, IGMXOrder.Props memory order, IGMXEventUtils.EventLogData memory eventData) external;

    /// @dev called after an order cancellation
    /// @param key the key of the order
    /// @param order the order that was cancelled
    function afterOrderCancellation(bytes32 key, IGMXOrder.Props memory order, IGMXEventUtils.EventLogData memory eventData) external;

    /// @dev called after an order has been frozen, see OrderUtils.freezeOrder in OrderHandler for more info
    /// @param key the key of the order
    /// @param order the order that was frozen
    function afterOrderFrozen(bytes32 key, IGMXOrder.Props memory order, IGMXEventUtils.EventLogData memory eventData) external;
}