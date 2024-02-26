// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {IGMXMarket} from "../src/integrations/GMXV2/interfaces/IGMXMarket.sol";
import {IGMXReader} from "../src/integrations/GMXV2/interfaces/IGMXReader.sol";

import {IBaseOrchestrator} from "../src/integrations/interfaces/IBaseOrchestrator.sol";

import {IDataStore} from "../src/integrations/utilities/interfaces/IDataStore.sol";

import {DataStore} from "../src/integrations/utilities/DataStore.sol";
import {DecreaseSizeResolver} from "../src/integrations/utilities/DecreaseSizeResolver.sol";

import {Orchestrator} from "../src/integrations/GMXV2/Orchestrator.sol";
import {RouteFactory} from "../src/integrations/GMXV2/RouteFactory.sol";

import "./utilities/DeployerUtilities.sol";

// ---- Usage ----
// NOTICE: UPDATE ADDRESSES IN DeployerUtilities.sol AFTER DEPLOYMENT
// forge script --libraries ...... script/DeployGMXV2.s.sol:DeployGMXV2 --verify --legacy --rpc-url $RPC_URL --broadcast
// --constructor-args "000000000000000000000000a12a6281c1773f267c274c3be1b71db2bace06cb0000000000000000000000002a6c106ae13b558bb9e2ec64bd2f1f7beff3a5e000000000000000000000000075236b405f460245999f70bc06978ab2b4116920

contract DeployGMXV2 is DeployerUtilities {

    address private _dataStore;
    address private _orchestrator;
    address private _routeFactory;
    address private _decreaseSizeResolver;
    address private _scoreGauge;

    bytes private _ethLongMarketData;
    bytes private _ethShortMarketData;

    Governor private _governor;

    function run() public {
        vm.startBroadcast(_deployerPrivateKey);

        _deployContracts();

        _setAdditionalData();

        _setGovernorRoles();

        _initializeDataStore();

        _initializeOrchestrator();

        _initializeResolver();

        _printAddresses();

        vm.stopBroadcast();
    }

    function _deployContracts() internal {
        _governor = new Governor(_deployer);

        _dataStore = address(new DataStore(_deployer));

        _orchestrator = address(new Orchestrator(_governor, DataStore(_dataStore)));
        _routeFactory = address(new RouteFactory());
        _decreaseSizeResolver = payable(address(new DecreaseSizeResolver(_governor, IDataStore(_dataStore), _gelatoAutomationArbi)));
        _scoreGauge = address(0);
    }

    function _setAdditionalData() internal {
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

            if (_marketData.marketToken == address(0)) revert ("_setAdditionalData: InvalidMarketToken");
            if (_marketData.indexToken != _indexToken) revert ("_setAdditionalData: InvalidIndexToken");

            _ethLongMarketToken = _marketData.marketToken;
            _ethShortMarketToken = _marketData.marketToken;
        }

        _ethLongMarketData = abi.encode(_ethLongMarketToken);
        _ethShortMarketData = abi.encode(_ethShortMarketToken);
    }

    function _setGovernorRoles() internal {
        if (_orchestrator == address(0)) revert("_setDictatorRoles: ZERO_ADDRESS");

        Orchestrator _orchestratorInstance = Orchestrator(payable(_orchestrator));
        _setRoleCapability(_governor, 1, address(_orchestrator), _orchestratorInstance.decreaseSize.selector, true);
        _setRoleCapability(_governor, 0, address(_orchestrator), _orchestratorInstance.setRouteType.selector, true);
        _setRoleCapability(_governor, 0, address(_orchestrator), _orchestratorInstance.initialize.selector, true);
        _setRoleCapability(_governor, 0, address(_orchestrator), _orchestratorInstance.updateFees.selector, true);

        _setUserRole(_governor, _deployer, 0, true);
        _setUserRole(_governor, _deployer, 1, true);
    }

    function _initializeDataStore() internal {
        DataStore _dataStoreInstance = DataStore(_dataStore);
        _dataStoreInstance.updateOwnership(_orchestrator, true);
        _dataStoreInstance.updateOwnership(_routeFactory, true);
        _dataStoreInstance.updateOwnership(_deployer, false);
    }

    function _initializeOrchestrator() internal {
        Orchestrator _orchestratorInstance = Orchestrator(payable(_orchestrator));

        bytes memory _gmxInfo = abi.encode(_gmxV2Router, _gmxV2ExchangeRouter, _gmxV2OrderVault, _gmxV2OrderHandler, _gmxV2Reader, _gmxV2DataStore);
        _orchestratorInstance.initialize(_minExecutionFeeGMXV2, _weth, _deployer, _routeFactory, _scoreGauge, _gmxInfo);
        _orchestratorInstance.setRouteType(_weth, _weth, true, _ethLongMarketData);
        _orchestratorInstance.setRouteType(_usdcOld, _weth, false, _ethShortMarketData);

        uint256 _managementFee = 100; // 1% fee
        uint256 _withdrawalFee = 100; // 1% fee
        uint256 _performanceFee = 500; // 5% max fee
        _orchestratorInstance.updateFees(_managementFee, _withdrawalFee, _performanceFee);

        // IBaseOrchestrator(_orchestrator).depositExecutionFees{ value: 0.1 ether }();
    }

    function _initializeResolver() internal {
        // DecreaseSizeResolver(payable(_decreaseSizeResolver)).createTask(_orchestrator);

        // DepositFundsToGelato1Balance.s.sol // TODO -- run this script manually

        // _setUserRole(_dictator, _gelatoFunctionCallerArbi, 1, true); // TODO -- whitelist Gelato Function Caller
    }

    function _printAddresses() internal view {
        console.log("Deployed Addresses");
        console.log("==============================================");
        console.log("==============================================");
        console.log("DataStore: ", _dataStore);
        console.log("RouteFactory: ", _routeFactory);
        console.log("Orchestrator: ", _orchestrator);
        console.log("DecreaseSizeResolver: ", _decreaseSizeResolver);
        // console.log("ScoreGaugeV1: ", _scoreGaugeV1);
        console.log("==============================================");
        console.log("==============================================");
    }
}

// ------------------- Libraries -------------------

// src/integrations/libraries:
// Keys: // --libraries 'src/integrations/libraries/Keys.sol:Keys:0x2503e378fEE8da4a78eA0BE45e70DB286A069Ff8'
// CommonHelper: // --libraries 'src/integrations/libraries/CommonHelper.sol:CommonHelper:0x67bf4c18ecF000328857030a131009e9c44929F0'
// SharesHelper: // --libraries 'src/integrations/libraries/SharesHelper.sol:SharesHelper:0x5012b05F611f9498a3fC6A80013A9B6781F0bBBd'
// RouteReader: // --libraries 'src/integrations/libraries/RouteReader.sol:RouteReader:0xBA0a4ad8a635F3fE38EDbeAfdB53797a70D96DE9'
// RouteSetter: // --libraries 'src/integrations/libraries/RouteSetter.sol:RouteSetter:0x7dD08E239075A108b09b85671F6C8DaDFA740410'
// OrchestratorHelper: // --libraries 'src/integrations/libraries/OrchestratorHelper.sol:OrchestratorHelper:0x98fe47970e7C401244EeC8af39A3668BC2143E9B'

// src/integrations/GMXV2/libraries:
// GMXV2Keys: // --libraries 'src/integrations/GMXV2/libraries/GMXV2Keys.sol:GMXV2Keys:0xfcFE1B3417d4d6F6E8a95E05d0243a09D5993A08'
// GMXV2OrchestratorHelper: // --libraries 'src/integrations/GMXV2/libraries/GMXV2OrchestratorHelper.sol:GMXV2OrchestratorHelper:0xC2EE029E0fCA5f905B4D8C839f27E47c3EB5519E'
// OrderUtils: // --libraries 'src/integrations/GMXV2/libraries/OrderUtils.sol:OrderUtils:0x812386c417b79A5e79F614F661a5984b70249861'
// GMXV2RouteHelper: // --libraries 'src/integrations/GMXV2/libraries/GMXV2RouteHelper.sol:GMXV2RouteHelper:0x71256D7d96521Dd003A9299e233D254ca804d41a'

// ------------------- Contracts -------------------

// DataStore:  0xcf269C855fDa1e8Ea65Ce51bea2208B400Df03d5
// RouteFactory:  0xF32Eb83c6784bcFc0De75B2c393BC08e903EDdF6
// Orchestrator:  0x32F1469A9D8E63923C1d4a6eaCf7830142BAbfbb
// DecreaseSizeResolver:  0x92671d3599d7112641a8bbdE151e2414E305c1BD

// --libraries 'src/integrations/GMXV2/libraries/GMXV2RouteHelper.sol:GMXV2RouteHelper:0x71256D7d96521Dd003A9299e233D254ca804d41a' --libraries 'src/integrations/GMXV2/libraries/OrderUtils.sol:OrderUtils:0x812386c417b79A5e79F614F661a5984b70249861' --libraries 'src/integrations/GMXV2/libraries/GMXV2OrchestratorHelper.sol:GMXV2OrchestratorHelper:0xC2EE029E0fCA5f905B4D8C839f27E47c3EB5519E' --libraries 'src/integrations/GMXV2/libraries/GMXV2Keys.sol:GMXV2Keys:0xfcFE1B3417d4d6F6E8a95E05d0243a09D5993A08' --libraries 'src/integrations/libraries/OrchestratorHelper.sol:OrchestratorHelper:0x98fe47970e7C401244EeC8af39A3668BC2143E9B' --libraries 'src/integrations/libraries/RouteSetter.sol:RouteSetter:0x7dD08E239075A108b09b85671F6C8DaDFA740410' --libraries 'src/integrations/libraries/RouteReader.sol:RouteReader:0xBA0a4ad8a635F3fE38EDbeAfdB53797a70D96DE9' --libraries 'src/integrations/libraries/SharesHelper.sol:SharesHelper:0x5012b05F611f9498a3fC6A80013A9B6781F0bBBd' --libraries 'src/integrations/libraries/CommonHelper.sol:CommonHelper:0x67bf4c18ecF000328857030a131009e9c44929F0' --libraries 'src/integrations/libraries/Keys.sol:Keys:0x2503e378fEE8da4a78eA0BE45e70DB286A069Ff8'
// forge script script/DeployGMXV2.s.sol:DeployGMXV2 --verify --legacy --rpc-url $RPC_URL --broadcast