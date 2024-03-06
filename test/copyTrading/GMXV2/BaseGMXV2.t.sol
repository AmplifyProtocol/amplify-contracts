// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {GMXV2RouteHelper} from "../../../src/integrations/GMXV2/libraries/GMXV2RouteHelper.sol";
import {GMXV2OrchestratorHelper} from "../../../src/integrations/GMXV2/libraries/GMXV2OrchestratorHelper.sol";

import {IGMXMarket} from "../../../src/integrations/GMXV2/interfaces/IGMXMarket.sol";
import {IGMXReader} from "../../../src/integrations/GMXV2/interfaces/IGMXReader.sol";

import {IGMXPositionRouter} from "./utilities/interfaces/IGMXPositionRouter.sol";

import {RouteFactory} from "../../../src/integrations/GMXV2/RouteFactory.sol";
import {Orchestrator} from "../../../src/integrations/GMXV2/Orchestrator.sol";

import {RouterMock} from "./utilities/mocks/RouterMock.sol";
import {ExchangeRouterMock} from "./utilities/mocks/ExchangeRouterMock.sol";
import {OrderVaultMock} from "./utilities/mocks/OrderVaultMock.sol";
import {OrderHandlerMock} from "./utilities/mocks/OrderHandlerMock.sol";
import {ReaderMock} from "./utilities/mocks/ReaderMock.sol";
import {DataStoreMock} from "./utilities/mocks/DataStoreMock.sol";

import {PositionHandler} from "./utilities/helpers/PositionHandler.sol";

import "../shared/BaseCopyTrading.t.sol";

abstract contract BaseGMXV2 is BaseCopyTrading {

    // ============================================================================================
    // Variables
    // ============================================================================================

    address internal _ethMarket = address(0x70d95587d40A2caf56bd97485aB3Eec10Bee6336);

    bytes internal _ethLongMarketData;
    bytes internal _ethShortMarketData;

    // ============================================================================================
    // Mock Contracts
    // ============================================================================================

    RouterMock internal _gmxV2MockRouter;
    ExchangeRouterMock internal _gmxV2MockExchangeRouter;
    OrderVaultMock internal _gmxV2MockOrderVault;
    OrderHandlerMock internal _gmxV2MockOrderHandler;
    ReaderMock internal _gmxMockV2Reader;
    DataStoreMock internal _gmxMockV2DataStore;

    // ============================================================================================
    // Helper Contracts
    // ============================================================================================

    PositionHandler internal _positionHandler;

    // ============================================================================================
    // Setup Function
    // ============================================================================================

    function setUp() public virtual override {
        BaseCopyTrading.setUp();

        _deployMocks();

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

        vm.chainId(4216138);
    }

    // ============================================================================================
    // Helper Functions
    // ============================================================================================

    function _deployMocks() internal {
        _gmxV2MockRouter = new RouterMock();
        _gmxV2MockExchangeRouter = new ExchangeRouterMock(_gmxV2MockRouter);
        _gmxV2MockOrderVault = new OrderVaultMock();
        _gmxV2MockOrderHandler = new OrderHandlerMock();
        _gmxMockV2Reader = new ReaderMock();
        _gmxMockV2DataStore = new DataStoreMock(
            address(_gmxV2MockRouter),
            address(_gmxV2MockExchangeRouter),
            address(_gmxV2MockOrderVault),
            address(_gmxV2MockOrderHandler),
            address(_gmxMockV2Reader)
        );

        // label the contracts
        vm.label({ account: address(_gmxV2MockRouter), newLabel: "GMXV2MockRouter" });
        vm.label({ account: address(_gmxV2MockExchangeRouter), newLabel: "GMXV2MockExchangeRouter" });
        vm.label({ account: address(_gmxV2MockOrderVault), newLabel: "GMXV2MockOrderVault" });
        vm.label({ account: address(_gmxV2MockOrderHandler), newLabel: "GMXV2MockOrderHandler" });
        vm.label({ account: address(_gmxMockV2Reader), newLabel: "GMXMockV2Reader" });
        vm.label({ account: address(_gmxMockV2DataStore), newLabel: "GMXMockV2DataStore" });
    }

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

        bytes32 _marketType = bytes32(0x4bd5869a01440a9ac6d7bf7aa7004f402b52b845f20e2cec925101e13d84d075); // (https://arbiscan.io/tx/0x80ef8c8a10babfaad5c9b2c97d0f4b0f30f61ba6ceb201ea23f5c5737e46bc36)
        address _shortToken = _usdcOld;
        address _longToken = _weth;
        address _indexToken = _weth;

        address _ethLongMarketToken;
        address _ethShortMarketToken;
        {
            bytes32 _salt = keccak256(abi.encode("GMX_MARKET", _indexToken, _longToken, _shortToken, _marketType));
            IGMXMarket.Props memory _marketData = IGMXReader(_gmxV2Reader).getMarketBySalt(
                _gmxV2DataStore,
                _salt
            );

            if (_marketData.marketToken == address(0)) revert ("_deployContracts: InvalidMarketToken");
            if (_marketData.indexToken != _indexToken) revert ("_deployContracts: InvalidIndexToken");

            _ethLongMarketToken = _marketData.marketToken;
            _ethShortMarketToken = _marketData.marketToken;
        }

        _ethLongMarketData = abi.encode(_ethLongMarketToken);
        _ethShortMarketData = abi.encode(_ethShortMarketToken);

        uint256 _executionFee = IGMXPositionRouter(_gmxV2PositionRouter).minExecutionFee();
        require(_executionFee > 0, "_deployContracts: execution fee is 0");

        context = Context({
            users: users,
            expectations: expectations,
            forkIDs: forkIDs,
            orchestrator: IBaseOrchestrator(_orchestrator),
            dataStore: _dataStore,
            referralManager: _referralManager,
            decreaseSizeResolver: payable(_decreaseSizeResolver),
            wnt: _wnt,
            usdc: _usdcOld,
            executionFee: _executionFee,
            longETHRouteTypeKey: Keys.routeTypeKey(_weth, _weth, true, _ethLongMarketData),
            shortETHRouteTypeKey: Keys.routeTypeKey(_usdcOld, _weth, false, _ethShortMarketData)
        });
    }

    function _initializeOrchestrator() internal {
        vm.startPrank(users.owner);

        bytes memory _gmxMocksInfo = abi.encode(_gmxV2MockRouter, _gmxV2MockExchangeRouter, _gmxV2MockOrderVault, _gmxV2MockOrderHandler, _gmxMockV2Reader, _gmxMockV2DataStore);
        Orchestrator _orchestratorInstance = Orchestrator(payable(_orchestrator));
        _orchestratorInstance.initialize(context.executionFee, _weth, users.owner, _routeFactory, address(_scoreGauge), address(_referralManager), _gmxMocksInfo);
        _orchestratorInstance.setRouteType(_weth, _weth, true, _ethLongMarketData);
        _orchestratorInstance.setRouteType(_usdcOld, _weth, false, _ethShortMarketData);

        vm.expectRevert(bytes4(keccak256("AlreadyInitialized()")));
        _orchestratorInstance.initialize(context.executionFee, _weth, users.owner, _routeFactory, address(_scoreGauge), address(_referralManager), _gmxMocksInfo);

        IBaseOrchestrator(_orchestrator).depositExecutionFees{ value: 10 ether }();

        _orchestratorInstance.updatePuppetKeeperMinExecutionFee(context.executionFee);

        vm.stopPrank();
    }

    function _updateGMXAddress() internal {

        vm.startPrank(users.owner);
        _setRoleCapability(_governor, 0, address(context.orchestrator), context.orchestrator.updateDexAddresses.selector, true);

        bytes memory _gmxInfo = abi.encode(_gmxV2Router, _gmxV2ExchangeRouter, _gmxV2OrderVault, _gmxV2OrderHandler, _gmxV2Reader, _gmxV2DataStore);
        context.orchestrator.updateDexAddresses(_gmxInfo);
        vm.stopPrank();
    }
}