// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {IDataStore} from "../../src/integrations/utilities/interfaces/IDataStore.sol";

import {IBaseOrchestrator} from "../../src/integrations/interfaces/IBaseOrchestrator.sol";

struct Users {
    // default owner for all contracts
    address payable owner;
    // Puppet Treasury
    address payable treasury;
    // random Trader
    address payable trader;
    // the address that is allowed to adjust the position when target leverage is not met
    address payable keeper;
    // random Puppet #1
    address payable alice;
    // random Puppet #2
    address payable bob;
    // random Puppet #3
    address payable yossi;
}

struct Expectations {
    // if true, then we're using GMX V1
    bool isGMXV1;
    // if true, then some Puppets don't have enough funds fully pay the required additional collateral
    bool isExpectingAdjustment;
    // if true, then there are subscriptions to the route
    bool isPuppetsSubscribed;
    // if true, then we are expecting a successful execution
    bool isSuccessfulExecution;
    // if true, then we are expecting the position to be closed
    bool isPositionClosed;
    // if true, then we are expecting the puppets subscription to be expired
    bool isPuppetsExpiryExpected;
    // if true, then we are expecting that a performance fee is payed
    bool isExpectingPerformanceFee;
    // if true, then we artificially executed the request, and the underlying DEX will not return the expected values
    bool isArtificialExecution;
    // if true, then we are using mocks
    bool isUsingMocks;
    // if true, then we are expecting the Route balance to be non-zero
    bool isExpectingNonZeroBalance;
    // if true, then we cancelled the order
    bool isOrderCancelled;
    // a request key to execute
    bytes32 requestKeyToExecute;
    // puppets that are subscribed to the route
    address[] subscribedPuppets;
}

struct ForkIDs {
    // the fork id for Polygon
    uint256 polygon;
    // the fork id for Arbitrum
    uint256 arbitrum;
}

struct Context {
    Users users;
    Expectations expectations;
    ForkIDs forkIDs;
    IBaseOrchestrator orchestrator;
    IDataStore dataStore;
    address payable decreaseSizeResolver;
    address wnt;
    address usdc;
    uint256 executionFee;
    bytes32 longETHRouteTypeKey;
    bytes32 shortETHRouteTypeKey;
}