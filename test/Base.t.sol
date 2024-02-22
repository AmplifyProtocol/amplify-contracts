// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IBaseRoute} from "../src/integrations/interfaces/IBaseRoute.sol";
import {IBaseOrchestrator} from "../src/integrations/interfaces/IBaseOrchestrator.sol";

import {CommonHelper, Keys, RouteReader} from "../src/integrations/libraries/RouteSetter.sol";

import {DataStore} from "../src/integrations/utilities/DataStore.sol";
import {DecreaseSizeResolver} from "../src/integrations/utilities/DecreaseSizeResolver.sol";

import {FlashLoanHandler} from "../src/tokenomics/utilities/FlashLoanHandler.sol";
import {AmplifyPriceOracle} from "../src/tokenomics/utilities/AmplifyPriceOracle.sol";

import {Amplify} from "../src/tokenomics/Amplify.sol";
import {DiscountedAmplify} from "../src/tokenomics/DiscountedAmplify.sol";
import {VotingEscrow} from "../src/tokenomics/VotingEscrow.sol";
import {GaugeController} from "../src/tokenomics/GaugeController.sol";
import {Minter} from "../src/tokenomics/Minter.sol";
import {RevenueDistributer} from "../src/tokenomics/RevenueDistributer.sol";
import {ScoreGauge} from "../src/tokenomics/ScoreGauge.sol";

import {DeployerUtilities} from "../script/utilities/DeployerUtilities.sol";

import {Governor} from "../src/utilities/Governor.sol";

import {Context, Expectations, Users, ForkIDs} from "./utilities/Types.sol";

import "forge-std/Test.sol";
import "forge-std/console.sol";

/// @notice Base test contract with common functionality needed by all tests
abstract contract Base is Test, DeployerUtilities {

    // ============================================================================================
    // Variables
    // ============================================================================================

    address internal _wnt;

    bytes internal _emptyBytes;

    uint256 internal _polygonForkId;
    uint256 internal _arbitrumForkId;

    uint256 internal constant _BASIS_POINTS_DIVISOR = 10000;

    Context public context;
    Users public users;
    Expectations public expectations;
    ForkIDs public forkIDs;

    // ============================================================================================
    // Contracts
    // ============================================================================================

    // utilities
    Governor internal _governor;
    DataStore internal _dataStore;

    // token
    Amplify internal _ampl;
    DiscountedAmplify internal _dAmpl;
    VotingEscrow internal _votingEscrow;
    GaugeController internal _gaugeController;
    Minter internal _minter;
    RevenueDistributer internal _revenueDistributer;
    ScoreGauge internal _scoreGauge;
    FlashLoanHandler internal _flashLoanHandler;
    AmplifyPriceOracle internal _priceOracle;

    // ============================================================================================
    // Setup Function
    // ============================================================================================

    function setUp() public virtual {

        forkIDs = ForkIDs({
            polygon: vm.createFork(vm.envString("POLYGON_RPC_URL")),
            arbitrum: vm.createFork(vm.envString("ARBITRUM_RPC_URL"))
        });

        vm.selectFork(forkIDs.arbitrum);
        assertEq(vm.activeFork(), forkIDs.arbitrum, "base setUp: arbitrum fork not selected");

        // set WNT
        _wnt = _weth;

        // create users
        users = Users({
            owner: _createUser("Owner"),
            treasury: _createUser("Treasury"),
            trader: _createUser("Trader"),
            keeper: _createUser("Keeper"),
            alice: _createUser("Alice"),
            bob: _createUser("Bob"),
            yossi: _createUser("Yossi")
        });

        _deployTokenAndUtils();

        _labelContracts();

        // set chain id to Arbitrum
        vm.chainId(4216138);
    }

    // ============================================================================================
    // Helper Functions
    // ============================================================================================

    function _deployTokenAndUtils() internal {
        vm.startPrank(users.owner);

        _governor = new Governor(users.owner);
        _dataStore = new DataStore(users.owner);

        _ampl = new Amplify(_governor, "Amplify Protocol Token", "AMPL", 18);
        vm.stopPrank();

        vm.startPrank(users.owner);

        _priceOracle = new AmplifyPriceOracle();
        _flashLoanHandler = new FlashLoanHandler();

        // @todo -- use crvUSD and allow to change it (to future amplUSD)
        _dAmpl = new DiscountedAmplify(_governor, IERC20Metadata(address(_ampl)), IERC20Metadata(_usdcOld), address(_priceOracle), address(_flashLoanHandler), users.treasury, "Discounted Amplify", "dAMPL");
        _votingEscrow = new VotingEscrow(IERC20(address(_ampl)));
        _gaugeController = new GaugeController(_governor, address(_ampl), address(_votingEscrow));
        _minter = new Minter(_ampl, _dAmpl, _gaugeController);
        _scoreGauge = new ScoreGauge(_governor, _votingEscrow, _minter, _dataStore, _dAmpl, IERC20(address(_ampl)));

        _setUserRole(_governor, users.owner, 0, true);
        _setUserRole(_governor, users.keeper, 1, true);

        _setRoleCapability(_governor, 0, address(_ampl), _ampl.setMinter.selector, true);
        _ampl.setMinter(address(_minter));

        _setRoleCapability(_governor, 0, address(_dAmpl), _dAmpl.setMinter.selector, true);
        _dAmpl.setMinter(address(_minter));

        _setRoleCapability(_governor, 0, address(_dAmpl), _dAmpl.setScoreGauge.selector, true);
        _dAmpl.setScoreGauge(address(_scoreGauge), true);

        uint256 _startTime = block.timestamp; // https://www.unixtimestamp.com/index.php?ref=theredish.com%2Fweb (1600300800) // TODO - calc next Thursday at 00:00:00 UTC
        _revenueDistributer = new RevenueDistributer(_governor, address(_votingEscrow), _startTime, _weth, users.owner);

        vm.stopPrank();
    }

    function _labelContracts() internal {
        vm.label({ account: address(_governor), newLabel: "Vovernor" });
        vm.label({ account: address(_dataStore), newLabel: "DataStore" });
        vm.label({ account: address(_ampl), newLabel: "AMPL" });
        vm.label({ account: address(_dAmpl), newLabel: "dAMPL" });
        vm.label({ account: address(_votingEscrow), newLabel: "VotingEscrow" });
        vm.label({ account: address(_gaugeController), newLabel: "GaugeController" });
        vm.label({ account: address(_minter), newLabel: "Minter" });
        vm.label({ account: address(_revenueDistributer), newLabel: "RevenueDistributer" });
        vm.label({ account: address(_scoreGauge), newLabel: "ScoreGauge" });
    }

    function _createUser(string memory _name) internal returns (address payable) {
        address payable _user = payable(makeAddr(_name));
        vm.deal({ account: _user, newBalance: 100 ether });
        deal({ token: address(_wnt), to: _user, give: 1_000_000 * 10 ** IERC20Metadata(_wnt).decimals() });
        deal({ token: address(_usdc), to: _user, give: 1_000_000 * 10 ** IERC20Metadata(_usdc).decimals() });
        deal({ token: address(_frax), to: _user, give: 1_000_000 * 10 ** IERC20Metadata(_frax).decimals() });
        // deal({ token: address(_usdcOld), to: _user, give: 1_000_000 * 10 ** IERC20Metadata(_usdcOld).decimals() });
        _dealNonDealableERC20(_usdcOld, _user, 1_000_000 * 10 ** IERC20Metadata(_usdcOld).decimals());
        return _user;
    }

    function _depositFundsToGelato1Balance() internal {
        vm.selectFork(forkIDs.polygon);
        assertEq(vm.activeFork(), forkIDs.polygon, "_depositFundsToGelato1Balance: polygon fork not selected");

        DecreaseSizeResolver _resolver = new DecreaseSizeResolver(_governor, _dataStore, _gelatoAutomationPolygon);

        uint256 _amount = 1_000_000 * 10 ** IERC20Metadata(_polygonUSDC).decimals();
        deal({ token: address(_polygonUSDC), to: address(_resolver), give: _amount });

        _resolver.depositFunds(_amount, _polygonUSDC, users.owner);

        vm.selectFork(forkIDs.arbitrum);
        assertEq(vm.activeFork(), forkIDs.arbitrum, "_depositFundsToGelato1Balance: arbitrum fork not selected");
    }

    function _approveERC20(address _spender, address _token, uint256 _amount) internal {
        IERC20(_token).approve(_spender, 0);
        IERC20(_token).approve(_spender, _amount);
    }

    function _dealERC20(address _token, address _user, uint256 _amount) internal {
        if (_token == _usdcOld) {
            _dealNonDealableERC20(_token, _user, _amount);
        } else {
            _amount = IERC20(_token).balanceOf(_user) + (_amount * 10 ** IERC20Metadata(_token).decimals());
            deal({ token: _token, to: _user, give: _amount });
        }
    }

    function _dealNonDealableERC20(address _token, address _user, uint256 _amount) internal {
        address _whale = 0xB38e8c17e38363aF6EbdCb3dAE12e0243582891D; // Binance Hot Wallet
        if (IERC20(_token).balanceOf(_whale) < _amount) revert ("dealNonDealableERC20: Whale balance is less than amount");
        vm.prank(_whale);
        IERC20(_token).transfer(_user, _amount);
    }
}