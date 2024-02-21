// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {OrderUtils, IGMXExchangeRouter} from "../../../../../src/integrations/GMXV2/interfaces/IGMXExchangeRouter.sol";

import {RouterMock} from "./RouterMock.sol";

import "./BaseMock.sol";

contract ExchangeRouterMock is BaseMock, IGMXExchangeRouter {

    uint256 private _pendingRequestKeySalt;

    RouterMock internal _router;

    constructor(RouterMock _routerMock) {
        _router = _routerMock;
    }

    function createOrder(OrderUtils.CreateOrderParams calldata) external payable override returns (bytes32 _requestKey) {
        _pendingRequestKeySalt += 1;
        _requestKey = keccak256(abi.encodePacked(_pendingRequestKeySalt));
    }

    function sendTokens(address _token, address _receiver, uint256 _amount) external payable override {
        _router.sendTokens(msg.sender, _token, _receiver, _amount);
    }

    function cancelOrder(bytes32 key) external payable override {}

    function claimFundingFees(address[] memory markets, address[] memory tokens, address receiver) external payable returns (uint256[] memory) {}
}