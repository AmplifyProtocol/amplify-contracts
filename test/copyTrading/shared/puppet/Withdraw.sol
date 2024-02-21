// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {Fees} from "../global/Fees.sol";

import {Deposit} from "./Deposit.sol";

import "../BaseHelper.t.sol";

contract Withdraw is BaseHelper {

    // ============================================================================================
    // Helper Functions
    // ============================================================================================

    function withdrawEntireWNTBalance(Context memory _context, address _puppet, bool _isWrappedToken) public {
        uint256 _puppetBalanceBefore = _isWrappedToken ? address(_puppet).balance : IERC20(_context.wnt).balanceOf(_puppet);
        uint256 _puppetDepositAccountBalanceBefore = IDataStore(_context.dataStore).getUint(Keys.puppetDepositAccountKey(_puppet, _context.wnt));
        uint256 _orchestratorBalanceBefore = IERC20(_context.wnt).balanceOf(address(_context.orchestrator));
        IBaseOrchestrator _orchestratorInstance = IBaseOrchestrator(_context.orchestrator);

        vm.startPrank(_puppet);

        vm.expectRevert(bytes4(keccak256("ZeroAmount()")));
        _orchestratorInstance.withdraw(0, _context.wnt, _puppet, _isWrappedToken);

        vm.expectRevert(bytes4(keccak256("ZeroAddress()")));
        _orchestratorInstance.withdraw(_puppetDepositAccountBalanceBefore, _context.wnt, address(0), _isWrappedToken);

        vm.expectRevert(bytes4(keccak256("ZeroAddress()")));
        _orchestratorInstance.withdraw(_puppetDepositAccountBalanceBefore, address(0), _puppet, _isWrappedToken);

        vm.expectRevert(bytes4(keccak256("NotCollateralToken()")));
        _orchestratorInstance.withdraw(_puppetDepositAccountBalanceBefore, _frax, _puppet, _isWrappedToken);

        vm.expectRevert(bytes4(keccak256("InvalidAsset()")));
        _orchestratorInstance.withdraw(_puppetDepositAccountBalanceBefore, _context.usdc, _puppet, true);

        _orchestratorInstance.withdraw(_puppetDepositAccountBalanceBefore, _context.wnt, _puppet, _isWrappedToken);
        uint256 _puppetBalanceAfter = _isWrappedToken ? address(_puppet).balance : IERC20(_context.wnt).balanceOf(_puppet);
        uint256 _puppetDepositAccountBalanceAfter = IDataStore(_context.dataStore).getUint(Keys.puppetDepositAccountKey(_puppet, _context.wnt));
        uint256 _orchestratorBalanceAfter = IERC20(_context.wnt).balanceOf(address(_context.orchestrator));
        vm.stopPrank();

        assertTrue(_puppetDepositAccountBalanceBefore > 0, "withdrawEntireWNTBalance: E1");
        assertEq(_puppetDepositAccountBalanceAfter, 0, "withdrawEntireWNTBalance: E2");

        uint256 _withdrawalFee = IDataStore(_context.dataStore).getUint(Keys.WITHDRAWAL_FEE);
        if (_withdrawalFee > 0) {
            uint256 _feePaid = _puppetDepositAccountBalanceBefore * _withdrawalFee / _BASIS_POINTS_DIVISOR;
            assertEq(_puppetBalanceBefore + _puppetDepositAccountBalanceBefore - _feePaid, _puppetBalanceAfter, "withdrawEntireWNTBalance: E3");
            assertEq(_orchestratorBalanceBefore - _orchestratorBalanceAfter, _puppetDepositAccountBalanceBefore - _feePaid, "withdrawEntireWNTBalance: E4");
        } else {
            assertEq(_orchestratorBalanceBefore - _orchestratorBalanceAfter, _puppetDepositAccountBalanceBefore, "withdrawEntireWNTBalance: E5");
            assertEq(_puppetBalanceBefore + _puppetDepositAccountBalanceBefore, _puppetBalanceAfter, "withdrawEntireWNTBalance: E6");
        }
    }

    // ============================================================================================
    // Test Functions
    // ============================================================================================

    function withdrawFlowTest(Context memory _context, Deposit _deposit) external {
        _deposit.depositEntireWNTBalance(_context, _context.users.alice, true);
        _deposit.depositEntireWNTBalance(_context, _context.users.bob, true);
        _deposit.depositEntireWNTBalance(_context, _context.users.yossi, false);

        withdrawEntireWNTBalance(_context, _context.users.alice, true);
        withdrawEntireWNTBalance(_context, _context.users.bob, false);
        withdrawEntireWNTBalance(_context, _context.users.yossi, false);
    }
}