// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {IPositionHandler} from "./interfaces/IPositionHandler.sol";

import {Deposit} from "./puppet/Deposit.sol";
import {Subscribe} from "./puppet/Subscribe.sol";
import {ThrottleLimit} from "./puppet/ThrottleLimit.sol";
import {Withdraw} from "./puppet/Withdraw.sol";

import {RegisterRoute} from "./trader/RegisterRoute.sol";
import {RequestPosition} from "./trader/RequestPosition.sol";

import {Initialize} from "./global/Initialize.sol";
import {Fees} from "./global/Fees.sol";
import {CallbackAsserts} from "./global/CallbackAsserts.sol";

import {FuzzPuppetDeposit} from "./fuzz/puppet/Deposit.sol";
import {FuzzPuppetWithdraw} from "./fuzz/puppet/Withdraw.sol";
import {FuzzPuppetSubscribe} from "./fuzz/puppet/Subscribe.sol";

import "../../Base.t.sol";

abstract contract BaseCopyTrading is Base {

    // ============================================================================================
    // Contracts
    // ============================================================================================

    address internal _routeFactory;
    address internal _orchestrator;
    address payable internal _decreaseSizeResolver;

    // ============================================================================================
    // Test Helpers
    // ============================================================================================

    Deposit internal _deposit;
    RegisterRoute internal _registerRoute;
    Initialize internal _initialize;
    Subscribe internal _subscribe;
    ThrottleLimit internal _throttleLimit;
    Withdraw internal _withdraw;
    Fees internal _fees;
    RequestPosition internal _requestPosition;
    CallbackAsserts internal _callbackAsserts;

    FuzzPuppetDeposit internal _fuzz_PuppetDeposit;
    FuzzPuppetWithdraw internal _fuzz_PuppetWithdraw;
    FuzzPuppetSubscribe internal _fuzz_PuppetSubscribe;

    // ============================================================================================
    // Setup Function
    // ============================================================================================

    function setUp() public virtual override {
        Base.setUp();

        _deposit = new Deposit();
        _registerRoute = new RegisterRoute();
        _initialize = new Initialize();
        _subscribe = new Subscribe();
        _throttleLimit = new ThrottleLimit();
        _withdraw = new Withdraw();
        _fees = new Fees();
        _requestPosition = new RequestPosition();
        _callbackAsserts = new CallbackAsserts();

        _fuzz_PuppetDeposit = new FuzzPuppetDeposit();
        _fuzz_PuppetWithdraw = new FuzzPuppetWithdraw();
        _fuzz_PuppetSubscribe = new FuzzPuppetSubscribe();
    }

    // ============================================================================================
    // Helper Functions
    // ============================================================================================

    function _setGovernorRoles() internal {
        if (_orchestrator == address(0)) revert("_setGovernorRoles: ZERO_ADDRESS");

        vm.startPrank(users.owner);
        IBaseOrchestrator _orchestratorInstance = IBaseOrchestrator(_orchestrator);
        _setRoleCapability(_governor, 1, address(_orchestrator), _orchestratorInstance.decreaseSize.selector, true);
        _setRoleCapability(_governor, 0, address(_orchestrator), _orchestratorInstance.updatePuppetKeeperMinExecutionFee.selector, true);
        _setRoleCapability(_governor, 0, address(_orchestrator), _orchestratorInstance.setRouteType.selector, true);
        _setRoleCapability(_governor, 0, address(_orchestrator), _orchestratorInstance.initialize.selector, true);
        _setRoleCapability(_governor, 0, address(_orchestrator), _orchestratorInstance.updateFees.selector, true);

        vm.stopPrank();
    }

    function _initializeDataStore() internal {
        vm.startPrank(users.owner);
        _dataStore.updateOwnership(_orchestrator, true);
        _dataStore.updateOwnership(_routeFactory, true);
        _dataStore.updateOwnership(users.owner, false);
        vm.stopPrank();
    }

    function _initializeResolver() internal {

        _depositFundsToGelato1Balance();

        vm.startPrank(users.owner);

        _setRoleCapability(_governor, 0, _decreaseSizeResolver, DecreaseSizeResolver(_decreaseSizeResolver).createTask.selector, true);

        _setUserRole(_governor, _gelatoFunctionCallerArbi, 1, true);
        _setUserRole(_governor, _gelatoFunctionCallerArbi1, 1, true);
        _setUserRole(_governor, _gelatoFunctionCallerArbi2, 1, true);

        DecreaseSizeResolver(_decreaseSizeResolver).createTask(_orchestrator);

        vm.stopPrank();
    }
}