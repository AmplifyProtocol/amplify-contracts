// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../../BaseHelper.t.sol";

contract FuzzPuppetDeposit is BaseHelper {

    // ============================================================================================
    // Helper Functions
    // ============================================================================================

    function deposit_fuzzReceiver(Context memory _context, address _receiver) external {
        uint256 _amount = 1 ether;
        address _token = _weth;
        address _user = _receiver;

        _dealERC20(_token, _user, _amount);

        vm.startPrank(_user);

        if (_user == address(0)) {
            vm.expectRevert(bytes4(keccak256("ZeroAddress()")));
            _context.orchestrator.deposit(_amount, _token, _user);
        } else {
            uint256 _userDepositAccountBalanceBefore = CommonHelper.puppetAccountBalance(_context.dataStore, _user, _token);
            uint256 _orchestratorBalanceBefore = IERC20(_token).balanceOf(address(_context.orchestrator));

            _approveERC20(address(_context.orchestrator), _token, _amount);
            _context.orchestrator.deposit(_amount, _token, _user);

            assertEq(CommonHelper.puppetAccountBalance(_context.dataStore, _user, _token), _userDepositAccountBalanceBefore + _amount);
            assertEq(IERC20(_token).balanceOf(address(_context.orchestrator)), _orchestratorBalanceBefore + _amount);
        }
        vm.stopPrank();
    }

    function deposit_fuzzToken(Context memory _context, address _token) external {
        uint256 _amount = 1 ether;
        address _user = _context.users.alice;

        vm.startPrank(_user);

        if (_token == address(0)) {
            vm.expectRevert(bytes4(keccak256("ZeroAddress()")));
            _context.orchestrator.deposit(_amount, _token, _user);
        } else {
            if (_token != _weth || _token != _context.usdc) {
                vm.expectRevert(bytes4(keccak256("NotCollateralToken()")));
                _context.orchestrator.deposit(_amount, _token, _user);
            } else {
                uint256 _userDepositAccountBalanceBefore = CommonHelper.puppetAccountBalance(_context.dataStore, _user, _token);
                uint256 _orchestratorBalanceBefore = IERC20(_token).balanceOf(address(_context.orchestrator));

                _approveERC20(address(_context.orchestrator), _token, _amount);
                _context.orchestrator.deposit(_amount, _token, _user);

                assertEq(CommonHelper.puppetAccountBalance(_context.dataStore, _user, _token), _userDepositAccountBalanceBefore + _amount);
                assertEq(IERC20(_token).balanceOf(address(_context.orchestrator)), _orchestratorBalanceBefore + _amount);
            }
        }
        vm.stopPrank();
    }

    function deposit_fuzzAmount(Context memory _context, uint256 _amount, uint256 _value) external {
        vm.assume(_value < 10000 ether);

        address _token = _weth;
        address _user = _context.users.alice;
        uint256 _userDepositAccountBalanceBefore = CommonHelper.puppetAccountBalance(_context.dataStore, _user, _token);
        uint256 _orchestratorBalanceBefore = IERC20(_token).balanceOf(address(_context.orchestrator));

        vm.deal({ account: _user, newBalance: _value });

        vm.startPrank(_user);

        if (_amount == 0) {
            vm.expectRevert(bytes4(keccak256("ZeroAmount()")));
            _context.orchestrator.deposit(_amount, _token, _user);

            vm.expectRevert(bytes4(keccak256("ZeroAmount()")));
            _context.orchestrator.deposit{ value: _value }(_amount, _token, _user);
        } else {
            if (_value == 0) {
                vm.expectRevert(); // ERC20: transfer amount exceeds allowance
                _context.orchestrator.deposit{ value: _value }(_amount, _token, _user);
                vm.stopPrank();
                return;
            } else {
                if (_value != _amount) {
                    vm.expectRevert(bytes4(keccak256("InvalidAmount()")));
                    _context.orchestrator.deposit{ value: _value }(_amount, _token, _user);
                    vm.stopPrank();
                    return;
                }

                vm.expectRevert(bytes4(keccak256("InvalidAsset()")));
                _context.orchestrator.deposit{ value: _value }(_amount, _context.usdc, _user);

                vm.expectRevert(bytes4(keccak256("NotCollateralToken()")));
                _context.orchestrator.deposit{ value: _value }(_amount, _frax, _user);
            }

            _context.orchestrator.deposit{ value: _value }(_amount, _token, _user);

            assertEq(CommonHelper.puppetAccountBalance(_context.dataStore, _user, _token), _userDepositAccountBalanceBefore + _amount);
            assertEq(IERC20(_token).balanceOf(address(_context.orchestrator)), _orchestratorBalanceBefore + _amount);
        }
        vm.stopPrank();
    }
}