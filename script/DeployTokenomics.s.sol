// // SPDX-License-Identifier: AGPL-3.0-only
// pragma solidity 0.8.23;

// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// import {PuppetPriceOracle} from "src/tokenomics/utilities/PuppetPriceOracle.sol";
// import {FlashLoanHandler} from "src/tokenomics/utilities/FlashLoanHandler.sol";

// import {ScoreGaugeV1} from "src/tokenomics/ScoreGaugeV1.sol";
// import {Puppet} from "src/tokenomics/Puppet.sol";
// import {oPuppet} from "src/tokenomics/oPuppet.sol";
// import {VotingEscrow} from "src/tokenomics/VotingEscrow.sol";
// import {GaugeController} from "src/tokenomics/GaugeController.sol";
// import {Minter} from "src/tokenomics/Minter.sol";

// import {Orchestrator} from "src/integrations/GMXV2/Orchestrator.sol";

// import "./utilities/DeployerUtilities.sol";

// // ---- Usage ----
// // NOTICE: run this script ONLY AFTER updating contract addresses in DeployerUtilities.sol
// // forge script script/DeployTokenomics.s.sol:DeployTokenomics --verify --legacy --rpc-url $RPC_URL --broadcast

// contract DeployTokenomics is DeployerUtilities {

//     PuppetPriceOracle private _priceOracle;
//     FlashLoanHandler private _flashLoanHandler;

//     ScoreGaugeV1 private _scoreGaugeV1;
//     Puppet private _puppetERC20;
//     oPuppet private _oPuppet;
//     VotingEscrow private _votingEscrow;
//     GaugeController private _gaugeController;
//     Minter private _minter;
//     Orchestrator private _orchestrator;

//     Dictator private _dictator;

//     function run() public {
//         vm.startBroadcast(_deployerPrivateKey);

//         _deployContracts();

//         _setDictatorRolesAndInit();

//         _printAddresses();

//         vm.stopBroadcast();
//     }

//     function _deployContracts() internal {
//         _dictator = Dictator(_dictatorAddr);
//         _orchestrator = Orchestrator(_orchestratorAddr);

//         _puppetERC20 = new Puppet(_dictator, "Puppet Finance Token - TEST", "PUPPETtest", 18);

//         _priceOracle = new PuppetPriceOracle();
//         _flashLoanHandler = new FlashLoanHandler();

//         address _treasury = _deployer;
//         _oPuppet = new oPuppet(_dictator, IERC20(address(_puppetERC20)), IERC20(_usdcOld), address(_priceOracle), address(_flashLoanHandler), _treasury, "Puppet Options - TEST", "oPUPPETtest");
//         _votingEscrow = new VotingEscrow(_dictator, address(_puppetERC20), "Vote-escrowed PUPPET - TEST", "vePUPPETtest", "1.0.0");
//         _gaugeController = new GaugeController(_dictator, address(_puppetERC20), address(_votingEscrow));
//         _minter = new Minter(address(_puppetERC20), address(_oPuppet), address(_gaugeController));
//         _scoreGaugeV1 = new ScoreGaugeV1(_dictator, address(_votingEscrow), address(_minter), _dataStoreAddr, address(_oPuppet), address(_puppetERC20));
//     }

//     function _setDictatorRolesAndInit() internal {
//         bytes4 _setMinterSigPuppet = _puppetERC20.setMinter.selector;
//         _setRoleCapability(_dictator, 0, address(_puppetERC20), _setMinterSigPuppet, true);
//         _puppetERC20.setMinter(address(_minter));

//         bytes4 _setMinterSigoPuppet = _oPuppet.setMinter.selector;
//         _setRoleCapability(_dictator, 0, address(_oPuppet), _setMinterSigoPuppet, true);
//         _oPuppet.setMinter(address(_minter));

//         bytes4 _addToWhitelistSig = _votingEscrow.addToWhitelist.selector;
//         _setRoleCapability(_dictator, 0, address(_votingEscrow), _addToWhitelistSig, true);

//         bytes4 _setScoreGaugeSig = _oPuppet.setScoreGauge.selector;
//         _setRoleCapability(_dictator, 0, address(_oPuppet), _setScoreGaugeSig, true);
//         _oPuppet.setScoreGauge(address(_scoreGaugeV1), true);

//         bytes4 _updateScoreGaugeSig = _orchestrator.updateScoreGauge.selector;
//         _setRoleCapability(_dictator, 0, address(_orchestrator), _updateScoreGaugeSig, true);
//         _orchestrator.updateScoreGauge(address(_scoreGaugeV1));

//         bytes4 _addTypeSig = _gaugeController.addType.selector;
//         _setRoleCapability(_dictator, 0, address(_gaugeController), _addTypeSig, true);
//         _gaugeController.addType("Arbitrum", 1000000000000000000);

//         bytes4 _addGaugeSig = _gaugeController.addGauge.selector;
//         _setRoleCapability(_dictator, 0, address(_gaugeController), _addGaugeSig, true);
//         _gaugeController.addGauge(address(_scoreGaugeV1), 0, 1);

//         bytes4 _initializeEpochSig = _gaugeController.initializeEpoch.selector;
//         _setRoleCapability(_dictator, 0, address(_gaugeController), _initializeEpochSig, true);
//         // TODO - manually initialize epoch
//     }

//     function _printAddresses() internal view {
//         console.log("Deployed Addresses");
//         console.log("==============================================");
//         console.log("==============================================");
//         console.log("puppetERC20: %s", address(_puppetERC20));
//         console.log("oPuppet: %s", address(_oPuppet));
//         console.log("votingEscrow: %s", address(_votingEscrow));
//         console.log("gaugeController: %s", address(_gaugeController));
//         console.log("minterContract: %s", address(_minter));
//         console.log("scoreGauge1V1: %s", address(_scoreGaugeV1));
//         console.log("priceOracle: %s", address(_priceOracle));
//         console.log("flashLoanHandler: %s", address(_flashLoanHandler));
//         console.log("==============================================");
//         console.log("==============================================");
//     }
// }

// //   puppetERC20: 0xAde170A4C11574Aa3732e9EBA994D891F99Ab33E
// //   oPuppet: 0xD4062F781c0A5255886a4666576584b2d1D5aE69
// //   votingEscrow: 0xFcdc2af1b2cA1581CD0f4995F459DD774257f5C8
// //   gaugeController: 0x6287778122A449c825D66d2d28ADAb7ce8595e16
// //   minterContract: 0xa70A55470c16529f6ED8B7b7fAe701cB039B593f
// //   scoreGauge1V1: 0x00e930320A64273Ff0a544c57b58ebA8C8b3E35E
// //   priceOracle: 0x50D709b4edd179B0d81404a64d01454083F13d8a
// //   flashLoanHandler: 0xE85389C50CBa4953174236be6C864901BB2dCA61