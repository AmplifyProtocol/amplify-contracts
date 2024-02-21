// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../../BaseHelper.t.sol";

contract FuzzPuppetWithdraw is BaseHelper {

    // ============================================================================================
    // Helper Functions
    // ============================================================================================

    function withdraw_fuzzReceiver(Context memory _context, address _receiver) external {
        address _user = _context.users.alice;
        uint256 _amountDepositedWETH = CommonHelper.puppetAccountBalance(_context.dataStore, _user, _weth);
        uint256 _amountToWithdrawWETH = _amountDepositedWETH / 2;

        vm.startPrank(_user);

        if (_receiver == address(0)) {
            vm.expectRevert(bytes4(keccak256("ZeroAddress()")));
            _context.orchestrator.withdraw(_amountToWithdrawWETH, _weth, _receiver, false);

            vm.expectRevert(bytes4(keccak256("ZeroAddress()")));
            _context.orchestrator.withdraw(_amountToWithdrawWETH, _weth, _receiver, true);
        } else {
            if (!_isContract(_receiver)) {
                uint256 _receiverBalanceBefore = _receiver.balance;
                uint256 _orchesratorBalanceBefore = IERC20(_weth).balanceOf(address(_context.orchestrator));
                uint256 _expectedFeeAmount = _amountToWithdrawWETH * CommonHelper.withdrawalFeePercentage(_context.dataStore) / 10000;

                uint256 _amountOut = _context.orchestrator.withdraw(_amountToWithdrawWETH, _weth, _receiver, true);

                assertEq(_receiver.balance, _receiverBalanceBefore + _amountOut);
                assertEq(IERC20(_weth).balanceOf(address(_context.orchestrator)), _orchesratorBalanceBefore - _amountOut);
                assertEq(_context.dataStore.getUint(Keys.platformAccountKey(_weth)), _expectedFeeAmount);
            }
        }
        vm.stopPrank();
    }

    function withdraw_fuzzToken(Context memory _context, address _token) external {
        address _user = _context.users.alice;
        uint256 _amountDepositedWETH = CommonHelper.puppetAccountBalance(_context.dataStore, _user, _weth);
        uint256 _amountDepositedUSDC = CommonHelper.puppetAccountBalance(_context.dataStore, _user, _context.usdc);
        uint256 _amountToWithdrawWETH = _amountDepositedWETH / 2;
        uint256 _amountToWithdrawUSDC = _amountDepositedUSDC / 2;

        vm.startPrank(_user);

        if (_token == address(0)) {
            vm.expectRevert(bytes4(keccak256("ZeroAddress()")));
            _context.orchestrator.withdraw(_amountToWithdrawWETH, _token, _user, false);

            vm.expectRevert(bytes4(keccak256("ZeroAddress()")));
            _context.orchestrator.withdraw(_amountToWithdrawWETH, _token, _user, true);
        } else {
            if (_token != _weth || _token != _context.usdc) {
                vm.expectRevert(bytes4(keccak256("NotCollateralToken()")));
                _context.orchestrator.withdraw(_amountToWithdrawWETH, _token, _user, false);

                vm.expectRevert(bytes4(keccak256("NotCollateralToken()")));
                _context.orchestrator.withdraw(_amountToWithdrawWETH, _token, _user, true);
            } else {
                if (_token == _context.usdc) {
                    vm.expectRevert(bytes4(keccak256("InvalidAsset()")));
                    _context.orchestrator.withdraw(_amountToWithdrawUSDC, _token, _user, true);

                    uint256 _userBalanceBefore = IERC20(_token).balanceOf(_user);
                    uint256 _orchesratorBalanceBefore = IERC20(_token).balanceOf(address(_context.orchestrator));
                    uint256 _expectedFeeAmount = _amountToWithdrawUSDC * CommonHelper.withdrawalFeePercentage(_context.dataStore) / 10000;
                    uint256 _platformBalanceBefore = _context.dataStore.getUint(Keys.platformAccountKey(_token));

                    uint256 _amountOut = _context.orchestrator.withdraw(_amountToWithdrawUSDC, _token, _user, false);

                    assertEq(IERC20(_token).balanceOf(_user), _userBalanceBefore + _amountOut);
                    assertEq(IERC20(_token).balanceOf(address(_context.orchestrator)), _orchesratorBalanceBefore - _amountOut);
                    assertEq(_context.dataStore.getUint(Keys.platformAccountKey(_token)), _platformBalanceBefore + _expectedFeeAmount);
                } else {
                    // token == _weth
                    uint256 _userBalanceBefore = _user.balance;
                    uint256 _orchesratorBalanceBefore = IERC20(_token).balanceOf(address(_context.orchestrator));
                    uint256 _expectedFeeAmount = _amountToWithdrawWETH * CommonHelper.withdrawalFeePercentage(_context.dataStore) / 10000;
                    uint256 _platformBalanceBefore = _context.dataStore.getUint(Keys.platformAccountKey(_token));

                    uint256 _amountOut = _context.orchestrator.withdraw(_amountToWithdrawWETH, _token, _user, false);

                    assertEq(_user.balance, _userBalanceBefore + _amountOut);
                    assertEq(IERC20(_token).balanceOf(address(_context.orchestrator)), _orchesratorBalanceBefore - _amountOut);
                    assertEq(_context.dataStore.getUint(Keys.platformAccountKey(_token)), _platformBalanceBefore + _expectedFeeAmount);
                }
            }
        }
        vm.stopPrank();
    }

    function withdraw_fuzzAmount(Context memory _context, uint256 _amount) external {
        address _token = _weth;
        address _user = _context.users.alice;
        uint256 _amountDeposited = CommonHelper.puppetAccountBalance(_context.dataStore, _user, _token);
        bool _canPay = CommonHelper.canPuppetPayAmount(_context.dataStore, _user, _token, _amount, true);

        vm.startPrank(_user);

        if (_amount == 0) {
            vm.expectRevert(bytes4(keccak256("ZeroAmount()")));
            _context.orchestrator.withdraw(_amount, _token, _user, false);

            vm.expectRevert(bytes4(keccak256("ZeroAmount()")));
            _context.orchestrator.withdraw(_amount, _token, _user, true);
        } else {
            if (_amount >= _amountDeposited && !_canPay) {
                vm.expectRevert(); // Arithmetic over/underflow
                _context.orchestrator.withdraw(_amount, _token, _user, false);

                vm.expectRevert(); // Arithmetic over/underflow
                _context.orchestrator.withdraw(_amount, _token, _user, true);
            } else {
                uint256 _puppetWETHBalanceBefore = IERC20(_token).balanceOf(_user);
                uint256 _puppetETHBalanceBefore = _user.balance;
                uint256 _orchesratorWETHBalanceBefore = IERC20(_token).balanceOf(address(_context.orchestrator));
                uint256 _platformAccountWETHBalanceBefore = _context.dataStore.getUint(Keys.platformAccountKey(_token));

                uint256 _amountWithdrawn;
                if (_amount % 2 == 0) {
                    _amountWithdrawn = _context.orchestrator.withdraw(_amount, _token, _user, false);

                    assertEq(IERC20(_token).balanceOf(_user), _puppetWETHBalanceBefore + _amount);
                    assertEq(_user.balance, _puppetETHBalanceBefore);
                } else {
                    _amountWithdrawn = _context.orchestrator.withdraw(_amount, _token, _user, true);

                    assertEq(IERC20(_token).balanceOf(_user), _puppetWETHBalanceBefore);
                    assertEq(_user.balance, _puppetETHBalanceBefore + _amountWithdrawn);
                }

                assertEq(IERC20(_token).balanceOf(address(_context.orchestrator)), _orchesratorWETHBalanceBefore - _amountWithdrawn);
                if (CommonHelper.withdrawalFeePercentage(_context.dataStore) > 0) {
                    assertTrue(_context.dataStore.getUint(Keys.platformAccountKey(_token)) > _platformAccountWETHBalanceBefore);
                } else {
                    assertEq(_context.dataStore.getUint(Keys.platformAccountKey(_token)), _platformAccountWETHBalanceBefore);
                }
            }
            vm.stopPrank();
        }
    }

    function _isContract(address _addr) private view returns (bool isContract){
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }
}