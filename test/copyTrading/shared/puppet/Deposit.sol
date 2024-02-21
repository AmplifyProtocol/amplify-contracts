// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../BaseHelper.t.sol";

contract Deposit is BaseHelper {

    // ============================================================================================
    // Helper Functions
    // ============================================================================================

    function depositEntireWNTBalance(Context memory _context, address _puppet, bool _isWNT) public returns (uint256) {
        address _wnt = _context.wnt;
        uint256 _puppetAccountBalanceBefore = IDataStore(_context.dataStore).getUint(Keys.puppetDepositAccountKey(_puppet, _wnt));
        uint256 _puppetTokenBalanceBefore;
        uint256 _puppetTokenBalanceAfter;
        if (_isWNT) {
            _puppetTokenBalanceBefore = address(_puppet).balance;
            vm.startPrank(_puppet);
            vm.expectRevert(bytes4(keccak256("InvalidAmount()")));
            IBaseOrchestrator(_context.orchestrator).deposit{ value: _puppetTokenBalanceBefore - 1 }(_puppetTokenBalanceBefore, _wnt, _puppet);
            vm.expectRevert(bytes4(keccak256("InvalidAsset()")));
            IBaseOrchestrator(_context.orchestrator).deposit{ value: _puppetTokenBalanceBefore }(_puppetTokenBalanceBefore, _context.usdc, _puppet);

            IBaseOrchestrator(_context.orchestrator).deposit{ value: _puppetTokenBalanceBefore }(_puppetTokenBalanceBefore, _wnt, _puppet);
            _puppetTokenBalanceAfter = address(_puppet).balance;
            vm.stopPrank();
        } else {
            _puppetTokenBalanceBefore = IERC20(_wnt).balanceOf(_puppet);
            vm.startPrank(_puppet);
            _approveERC20(address(_context.orchestrator), _context.wnt, _puppetTokenBalanceBefore);
            IBaseOrchestrator(_context.orchestrator).deposit(_puppetTokenBalanceBefore, _wnt, _puppet);
            vm.stopPrank();
            _puppetTokenBalanceAfter = IERC20(_wnt).balanceOf(_puppet);
        }
        uint256 _puppetAccountBalanceAfter = IDataStore(_context.dataStore).getUint(Keys.puppetDepositAccountKey(_puppet, _wnt));

        vm.expectRevert(bytes4(keccak256("ZeroAmount()")));
        IBaseOrchestrator(_context.orchestrator).deposit(0, _wnt, _puppet);
        vm.expectRevert(bytes4(keccak256("ZeroAddress()")));
        IBaseOrchestrator(_context.orchestrator).deposit(_puppetTokenBalanceBefore, _wnt, address(0));
        vm.expectRevert(bytes4(keccak256("ZeroAddress()")));
        IBaseOrchestrator(_context.orchestrator).deposit(_puppetTokenBalanceBefore, address(0), _puppet);
        vm.expectRevert(bytes4(keccak256("NotCollateralToken()")));
        IBaseOrchestrator(_context.orchestrator).deposit(_puppetTokenBalanceBefore, _frax, _puppet);

        assertTrue(_puppetTokenBalanceBefore > 0, "_depositEntireWNTBalance: E1");
        assertTrue(_puppetAccountBalanceAfter > 0, "_depositEntireWNTBalance: E2");
        assertTrue(_puppetTokenBalanceBefore > _puppetTokenBalanceAfter, "_depositEntireWNTBalance: E3");
        assertTrue(_puppetAccountBalanceAfter > _puppetAccountBalanceBefore, "_depositEntireWNTBalance: E4");
        assertEq(_puppetTokenBalanceAfter, 0, "_depositEntireWNTBalance: E5");

        return _puppetAccountBalanceAfter;
    }

    // ============================================================================================
    // Test Functions
    // ============================================================================================

    function depositWNTFlowTest(Context memory _context, bool _isWNT) external {
        uint256 _aliceDepositedAmount;
        uint256 _bobDepositedAmount;
        uint256 _yossiDepositedAmount;
        uint256 _orchestratorWntBalanceBefore = IERC20(_context.wnt).balanceOf(address(_context.orchestrator));
        if (_isWNT) {
            _aliceDepositedAmount = depositEntireWNTBalance(_context, _context.users.alice, true);
            _bobDepositedAmount = depositEntireWNTBalance(_context, _context.users.bob, true);
            _yossiDepositedAmount = depositEntireWNTBalance(_context, _context.users.yossi, true);
        } else {
            _aliceDepositedAmount = depositEntireWNTBalance(_context, _context.users.alice, false);
            _bobDepositedAmount = depositEntireWNTBalance(_context, _context.users.bob, false);
            _yossiDepositedAmount = depositEntireWNTBalance(_context, _context.users.yossi, false);
        }
        uint256 _orchestratorWntBalanceAfter = IERC20(_context.wnt).balanceOf(address(_context.orchestrator));
        uint256 _totalDepositedAmount = _aliceDepositedAmount + _bobDepositedAmount + _yossiDepositedAmount;

        assertTrue(_aliceDepositedAmount > 0, "testDepositWNTFlow: E1");
        assertTrue(_bobDepositedAmount > 0, "testDepositWNTFlow: E2");
        assertTrue(_yossiDepositedAmount > 0, "testDepositWNTFlow: E3");
        assertTrue(_orchestratorWntBalanceAfter > 0, "testDepositWNTFlow: E4");
        assertEq(_orchestratorWntBalanceBefore, 0, "testDepositWNTFlow: E5");
        assertEq(_aliceDepositedAmount, _bobDepositedAmount, "testDepositWNTFlow: E6");
        assertEq(_aliceDepositedAmount, _yossiDepositedAmount, "testDepositWNTFlow: E7");
        assertEq(_orchestratorWntBalanceAfter, _totalDepositedAmount, "testDepositWNTFlow: E8");
    }

    function puppetsDepsitWNTAndBatchSubscribeFlowTest(Context memory _context, bool _isWNT, bytes32 _routeKey) external {
        uint256 _puppetAccountBalanceBefore = IDataStore(_context.dataStore).getUint(Keys.puppetDepositAccountKey(_context.users.alice, _context.wnt));
        uint256[] memory _allowances = new uint256[](1);
        _allowances[0] = CommonHelper.basisPointsDivisor(); // 100%
        uint256[] memory _expiries = new uint256[](1);
        _expiries[0] = block.timestamp + 24 hours;
        address[] memory _traders = new address[](1);
        _traders[0] = _context.users.trader;
        bytes32[] memory _routeTypeKeys = new bytes32[](1);
        _routeTypeKeys[0] = _context.longETHRouteTypeKey;

        vm.startPrank(_context.users.alice);

        uint256 _amount;
        if (_isWNT) {
            _amount = IERC20(_context.wnt).balanceOf(_context.users.alice);
        } else {
            _amount = address(_context.users.alice).balance;
        }
        _approveERC20(address(_context.orchestrator), _context.wnt, _amount);

        _traders[0] = _context.users.alice; // wrong Trader
        vm.expectRevert(bytes4(keccak256("RouteNotRegistered()")));
        IBaseOrchestrator(_context.orchestrator).depositAndBatchSubscribe(_amount, _context.wnt, _context.users.alice, _allowances, _expiries, _traders, _routeTypeKeys);
        _traders[0] = _context.users.trader;

        _allowances[0] = CommonHelper.basisPointsDivisor() + 1; // wrong allowance
        vm.expectRevert(bytes4(keccak256("InvalidAllowancePercentage()")));
        IBaseOrchestrator(_context.orchestrator).depositAndBatchSubscribe(_amount, _context.wnt, _context.users.alice, _allowances, _expiries, _traders, _routeTypeKeys);
        _allowances[0] = CommonHelper.basisPointsDivisor();

        _expiries[0] = block.timestamp + 24 hours - 1; // wrong expiry
        vm.expectRevert(bytes4(keccak256("InvalidSubscriptionExpiry()")));
        IBaseOrchestrator(_context.orchestrator).depositAndBatchSubscribe(_amount, _context.wnt, _context.users.alice, _allowances, _expiries, _traders, _routeTypeKeys);
        _expiries[0] = block.timestamp + 24 hours;

        if (_isWNT) {
            IBaseOrchestrator(_context.orchestrator).depositAndBatchSubscribe(_amount, _context.wnt, _context.users.alice, _allowances, _expiries, _traders, _routeTypeKeys);
        } else {
            IBaseOrchestrator(_context.orchestrator).depositAndBatchSubscribe{ value: _amount }(_amount, _context.wnt, _context.users.alice, _allowances, _expiries, _traders, _routeTypeKeys);
            _approveERC20(address(_context.orchestrator), _context.wnt, 0);
        }

        vm.stopPrank();

        _afterDepositAsserts(_context, _puppetAccountBalanceBefore, _amount, _allowances[0], _expiries[0], _routeKey);
    }

    function _afterDepositAsserts(
        Context memory _context,
        uint256 _puppetAccountBalanceBefore,
        uint256 _amount,
        uint256 _allowance,
        uint256 _expiry,
        bytes32 _routeKey
    ) internal {
        uint256 _puppetAccountBalanceAfter = _context.dataStore.getUint(Keys.puppetDepositAccountKey(_context.users.alice, _context.wnt));
        address _route = CommonHelper.routeAddress(_context.dataStore, _routeKey);

        assertTrue(_puppetAccountBalanceAfter > 0, "_afterDepositAsserts: E1");
        assertTrue(_amount > 0, "_afterDepositAsserts: E2");
        assertEq(_allowance, 10000, "_afterDepositAsserts: E3");
        assertEq(_puppetAccountBalanceAfter, _puppetAccountBalanceBefore + _amount, "_afterDepositAsserts: E4");
        assertEq(_context.dataStore.getUint(Keys.puppetSubscriptionExpiryKey(_context.users.alice, _route)), _expiry, "_afterDepositAsserts: E5");
        assertEq(_context.dataStore.getAddressToUintFor(Keys.puppetAllowancesKey(_context.users.alice), CommonHelper.routeAddress(_context.dataStore, _routeKey)), _allowance, "_afterDepositAsserts: E6");
    }
}