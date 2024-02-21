// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IBaseOrchestrator} from "../../src/integrations/interfaces/IBaseOrchestrator.sol";

import "./DeployerUtilities.sol";

// ---- Usage ----
// forge script script/utilities/RescueFunds.s.sol:RescueFunds --legacy --rpc-url $RPC_URL --broadcast

contract RescueToken is DeployerUtilities {

    function run() public {
        vm.startBroadcast(_deployerPrivateKey);

        Governor _governor = Governor(_governorAddr);
        IBaseOrchestrator _orchestrator = IBaseOrchestrator(payable(address(0x8992D776Ad36a92f29c6B3AB8DAd2c0520075364)));

        bytes4 _rescueTokensSig = _orchestrator.rescueToken.selector;

        _setRoleCapability(_governor, 0, address(_orchestrator), _rescueTokensSig, true);

        address _token = _weth;
        address _route = address(0xc15646354aF47BB55E3b2049EDFd4Cabc2A57fB6);
        uint256 _amount = IERC20(_token).balanceOf(_route);
        _orchestrator.rescueToken(_amount, _token, _deployer, _route);

        vm.stopBroadcast();
    }
}