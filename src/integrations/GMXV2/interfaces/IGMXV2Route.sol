// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

interface IGMXV2Route {
    function claimFundingFees(address[] memory _markets, address[] memory _tokens) external;
}