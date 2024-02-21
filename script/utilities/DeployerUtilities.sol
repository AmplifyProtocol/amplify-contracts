// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Governor} from "../../src/utilities/Governor.sol";

import "forge-std/Script.sol";
import "forge-std/console.sol";

contract DeployerUtilities is Script {

    // ============================================================================================
    // Variables
    // ============================================================================================

    // deployer
    uint256 internal _deployerPrivateKey = vm.envUint("GBC_DEPLOYER_PRIVATE_KEY");
    address internal _deployer = vm.envAddress("GBC_DEPLOYER_ADDRESS");

    // GMXV1
    address internal _gmxV1Router = 0xaBBc5F99639c9B6bCb58544ddf04EFA6802F4064;
    address internal _gmxV1Vault = 0x489ee077994B6658eAfA855C308275EAd8097C4A;
    address internal _gmxV1PositionRouter = 0xb87a436B93fFE9D75c5cFA7bAcFff96430b09868;
    address internal _gmxV1VaultPriceFeed = 0x2d68011bcA022ed0E474264145F46CC4de96a002;
    address internal _gmxV1PositionRouterKeeper = 0x11D62807dAE812a0F1571243460Bf94325F43BB7;

    // GMXV2
    address internal _gmxV2ExchangeRouter = address(0x7C68C7866A64FA2160F78EEaE12217FFbf871fa8);
    address internal _gmxV2Router = address(0x7452c558d45f8afC8c83dAe62C3f8A5BE19c71f6);
    address internal _gmxV2OrderVault = address(0x31eF83a530Fde1B38EE9A18093A333D8Bbbc40D5);
    address internal _gmxV2Reader = address(0x38d91ED96283d62182Fc6d990C24097A918a4d9b);
    address internal _gmxV2DataStore = address(0xFD70de6b91282D8017aA4E741e9Ae325CAb992d8);
    address internal _gmxV2OrderHandler = address(0x352f684ab9e97a6321a13CF03A61316B681D9fD2);
    address internal _gmxV2OrderKeeper = address(0xC539cB358a58aC67185BaAD4d5E3f7fCfc903700); // [[0xE47b36382DC50b90bCF6176Ddb159C4b9333A7AB] [0xC539cB358a58aC67185BaAD4d5E3f7fCfc903700] [0xf1e1B2F4796d984CCb8485d43db0c64B83C1FA6d]]
    address internal _gmxV2Controller = address(0x9d44B89Eb6FB382b712C562DfaFD8825829b422e); // [0x9d44B89Eb6FB382b712C562DfaFD8825829b422e] [0xA8AF9B86fC47deAde1bc66B12673706615E2B011] [0xB665B6dBB45ceAf3b126cec98aDB1E611b6a6aea]
    address internal _gmxV2Oracle = address(0x9f5982374e63e5B011317451a424bE9E1275a03f);
    address internal _gmxV2PositionRouter = address(0xb87a436B93fFE9D75c5cFA7bAcFff96430b09868);
    address internal _gmxV2RoleStore = address(0x3c3d99FD298f679DBC2CEcd132b4eC4d0F5e6e72);

    uint256 internal _minExecutionFeeGMXV2 = 180000000000000;

    // tokens
    address internal _eth = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    address internal _weth = address(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    address internal _frax = address(0x17FC002b466eEc40DaE837Fc4bE5c67993ddBd6F);
    address internal _usdc = address(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
    address internal _usdcOld = address(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
    address internal _dai = address(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);

    address internal _keeperAddr = address(0);
    address internal _governorAddr = 0xA12a6281c1773F267C274c3BE1B71DB2BACE06Cb;
    address internal _routeFactoryAddr = 0xF72042137F5a1b07E683E55AF8701CEBfA051cf4;
    address payable internal _orchestratorAddr = payable(0x9212c5a9e49B4E502F2A6E0358DEBe038707D6AC);
    address internal _dataStoreAddr = 0x75236b405F460245999F70bc06978AB2B4116920;
    address internal _decreaseSizeResolverAddr = 0x10144160575b90f8F322c584D19445f931825987;

    bytes32 internal _referralCode = 0x424c554542455252590000000000000000000000000000000000000000000000;

    // gelato

    address payable internal _gelatoAutomationArbi = payable(0x2A6C106ae13B558BB9E2Ec64Bd2f1f7BEFF3A5E0);
    address internal _gelatoAutomationCallerArbi = address(0x4775aF8FEf4809fE10bf05867d2b038a4b5B2146); // caller of IAutomate
    address internal _gelatoFunctionCallerArbi = address(0xDdF7Ff0e49a45960EAC2B9a24C7e7014c3c1908F); // caller of Orchestrator
    address internal _gelatoFunctionCallerArbi1 = address(0x75511b79B603855cA1e52D61eeDF813F868B42C8); // caller of Orchestrator
    address internal _gelatoFunctionCallerArbi2 = address(0xEf315d51760f7DA4A6B4fCb49D95A312F6a1156f); // caller of Orchestrator

    address internal _gelatoAutomationPolygon = address(0x2A6C106ae13B558BB9E2Ec64Bd2f1f7BEFF3A5E0);

    // polygon

    address internal _polygonUSDC = address(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);

    // ============================================================================================
    // Authority Functions
    // ============================================================================================

    function _setRoleCapability(Governor _governor, uint8 role, address target, bytes4 functionSig, bool enabled) internal {
        _governor.setRoleCapability(role, target, functionSig, enabled);
    }

    function _setUserRole(Governor _governor, address user, uint8 role, bool enabled) internal {
        _governor.setUserRole(user, role, enabled);
    }
}