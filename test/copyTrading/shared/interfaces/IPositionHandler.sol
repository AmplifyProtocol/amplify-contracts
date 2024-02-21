// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {IBaseRoute} from "../../../../src/integrations/interfaces/IBaseRoute.sol";

import {Context} from "../../../utilities/Types.sol";

import {RequestPosition} from "../trader/RequestPosition.sol";

import {CallbackAsserts} from "../global/CallbackAsserts.sol";

interface IPositionHandler {

    function increasePosition(Context memory _context, RequestPosition _requestPosition, IBaseRoute.OrderType _orderType, address _trader, address _collateralToken, address _indexToken, bool _isLong) external returns (bytes32 _requestKey);
    function decreasePosition(Context memory _context, RequestPosition _requestPosition, IBaseRoute.OrderType _orderType, bool _isClose, bytes32 _routeKey) external returns (bytes32 _requestKey);
    function executeRequest(Context memory _context, CallbackAsserts _callbackAsserts, address _trader, bool _isIncrease, bytes32 _routeKey) external;
}