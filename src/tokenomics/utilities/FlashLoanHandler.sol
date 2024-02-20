// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.24;

// ==============================================================
// _______                   __________________       ________             _____                  ______
// ___    |______ ______________  /__(_)__  __/____  ____  __ \______________  /_____________________  /
// __  /| |_  __ `__ \__  __ \_  /__  /__  /_ __  / / /_  /_/ /_  ___/  __ \  __/  __ \  ___/  __ \_  / 
// _  ___ |  / / / / /_  /_/ /  / _  / _  __/ _  /_/ /_  ____/_  /   / /_/ / /_ / /_/ / /__ / /_/ /  /  
// /_/  |_/_/ /_/ /_/_  .___//_/  /_/  /_/    _\__, / /_/     /_/    \____/\__/ \____/\___/ \____//_/   
//                   /_/                      /____/                                                    
// ==============================================================
// ===================== FlashLoanHandler =======================
// ==============================================================
// Amplify Protocol: https://github.com/AmplifyProtocol

// ==============================================================

import "@balancer-labs/interfaces/contracts/vault/IVault.sol";
import "@balancer-labs/interfaces/contracts/vault/IFlashLoanRecipient.sol";

import {IFlashLoanHandler} from "./interfaces/IFlashLoanHandler.sol";

/// @title Flash Loan Handler
/// @author johnnyonline
/// @notice Helps to excerise Options without the need to provide collateral
contract FlashLoanHandler is IFlashLoanRecipient, IFlashLoanHandler {

    IVault public constant VAULT = IVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    /// @inheritdoc IFlashLoanHandler
    function execute(uint256 _amount, address _token, address _treasury, address _receiver) external {
        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = _amount;
        IERC20[] memory _tokens = new IERC20[](1);
        _tokens[0] = IERC20(_token);

        bytes memory _data = abi.encode(_treasury, _receiver);
        VAULT.flashLoan(this, _tokens, _amounts, _data);
    }

    /// @inheritdoc IFlashLoanRecipient
    function receiveFlashLoan(
        IERC20[] memory, // _tokens
        uint256[] memory, // _amounts
        uint256[] memory, // _feeAmounts
        bytes memory // _data
    ) external view {
        if (msg.sender != address(VAULT)) revert NotVault();

        // (address _treasury, address _receiver) = abi.decode(_data, (address, address));

        // 1. send USD to treasury
        // 2. swap just enough PUPPET to USD to repay flash loan
        // 3. send remaining PUPPET to _receiver
        revert("Flashloan exercise not implemented yet!"); // @todo

        // Approve the Vault contract to *pull* the owed amount
        // _tokens[0].approve(address(VAULT), (_amounts[0] + _feeAmounts[0]));
    }
}