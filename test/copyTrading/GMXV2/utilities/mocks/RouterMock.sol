// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./BaseMock.sol";

contract RouterMock is BaseMock {

    using SafeERC20 for IERC20;

    function sendTokens(address _sender, address _token, address _receiver, uint256 _amount) external payable {
        IERC20(_token).safeTransferFrom(_sender, _receiver, _amount);
    }
}