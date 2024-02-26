// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {IGMXPositionRouter} from "../../../src/integrations/GMXV1/interfaces/IGMXPositionRouter.sol";

import {RouteFactory} from "../../../src/integrations/GMXV1/RouteFactory.sol";
import {Orchestrator} from "../../../src/integrations/GMXV1/Orchestrator.sol";

import {PositionHandler} from "./utilities/helpers/PositionHandler.sol";

import "../shared/BaseCopyTrading.t.sol";

abstract contract BaseGMXV1 is BaseCopyTrading {

    // ============================================================================================
    // Helper Contracts
    // ============================================================================================

    PositionHandler internal _positionHandler;

    // ============================================================================================
    // Setup Function
    // ============================================================================================

    function setUp() public virtual override {
        BaseCopyTrading.setUp();

        _deployContracts();

        _setGovernorRoles();

        _initialize.dataStoreOwnershipBeforeInitializationTest(context);

        _initializeDataStore();

        _initialize.dataStoreOwnershipAfterInitializationTest(context);

        _initialize.pausedStateTest(context);

        _initializeOrchestrator();

        _initializeResolver();

        // deploy helper contracts
        _positionHandler = new PositionHandler();

        context.expectations.isGMXV1 = true;
    }

    // ============================================================================================
    // Helper Functions
    // ============================================================================================

    function _deployContracts() internal {
        vm.startPrank(users.owner);
        _orchestrator = address(new Orchestrator(_governor, _dataStore));
        _routeFactory = address(new RouteFactory());
        _decreaseSizeResolver = payable(address(new DecreaseSizeResolver(_governor, _dataStore, _gelatoAutomationArbi)));
        vm.stopPrank();

        // label the contracts
        vm.label({ account: _orchestrator, newLabel: "Orchestrator" });
        vm.label({ account: _routeFactory, newLabel: "RouteFactory" });
        vm.label({ account: _decreaseSizeResolver, newLabel: "DecreaseSizeResolver" });

        uint256 _executionFee = IGMXPositionRouter(_gmxV1PositionRouter).minExecutionFee();
        require(_executionFee > 0, "_deployContracts: execution fee is 0");

        context = Context({
            users: users,
            expectations: expectations,
            forkIDs: forkIDs,
            orchestrator: IBaseOrchestrator(_orchestrator),
            dataStore: _dataStore,
            decreaseSizeResolver: payable(_decreaseSizeResolver),
            wnt: _wnt,
            usdc: _usdc,
            executionFee: _executionFee,
            longETHRouteTypeKey: Keys.routeTypeKey(_weth, _weth, true, _emptyBytes),
            shortETHRouteTypeKey: Keys.routeTypeKey(_usdc, _weth, false, _emptyBytes)
        });
    }

    function _initializeOrchestrator() internal {
        vm.startPrank(users.owner);

        bytes memory _gmxInfo = abi.encode(_gmxV1VaultPriceFeed, _gmxV1Router, _gmxV1Vault, _gmxV1PositionRouter);
        Orchestrator _orchestratorInstance = Orchestrator(payable(_orchestrator));
        _orchestratorInstance.initialize(context.executionFee, _weth, users.owner, _routeFactory, address(_scoreGauge), _gmxInfo);
        _orchestratorInstance.setRouteType(_weth, _weth, true, _emptyBytes);
        _orchestratorInstance.setRouteType(_usdc, _weth, false, _emptyBytes);

        vm.expectRevert(bytes4(keccak256("AlreadyInitialized()")));
        _orchestratorInstance.initialize(context.executionFee, _weth, users.owner, _routeFactory, address(_scoreGauge), _gmxInfo);

        IBaseOrchestrator(_orchestrator).depositExecutionFees{ value: 10 ether }();

        _orchestratorInstance.updatePuppetKeeperMinExecutionFee(context.executionFee);

        vm.stopPrank();
    }
}