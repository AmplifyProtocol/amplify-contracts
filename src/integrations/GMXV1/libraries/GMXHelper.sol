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
// ========================= GMXHelper ==========================
// ==============================================================
// Amplify Protocol: https://github.com/AmplifyProtocol

// ==============================================================

import {Keys} from "../../libraries/Keys.sol";
import {CommonHelper, RouteReader} from "../../libraries/RouteReader.sol";

import {GMXKeys} from "./GMXKeys.sol";

import {IDataStore} from "../../utilities/interfaces/IDataStore.sol";

import {IGMXPositionRouter} from "../interfaces/IGMXPositionRouter.sol";
import {IGMXVault} from "../interfaces/IGMXVault.sol";

/// @title GMXHelper
/// @author johnnyonline
/// @notice Helper functions for GMX V1 integration
library GMXHelper {

    // ============================================================================================
    // View functions
    // ============================================================================================

    function positionAmounts(IDataStore _dataStore, address _route) external view returns (uint256 _size, uint256 _collateral) {
        (_size, _collateral,,,,,,) = IGMXVault(_dataStore.getAddress(GMXKeys.VAULT)).getPosition(
            _route,
            CommonHelper.collateralToken(_dataStore, _route),
            CommonHelper.indexToken(_dataStore, _route),
            CommonHelper.isLong(_dataStore, _route)
        );
    }

    function gmxVaultPriceFeed(IDataStore _dataStore) external view returns (address) {
        return _dataStore.getAddress(GMXKeys.VAULT_PRICE_FEED);
    }

    function gmxPositionRouter(IDataStore _dataStore) public view returns (address) {
        return _dataStore.getAddress(GMXKeys.POSITION_ROUTER);
    }

    function gmxRouter(IDataStore _dataStore) external view returns (address) {
        return _dataStore.getAddress(GMXKeys.ROUTER);
    }

    function isWaitingForCallback(IDataStore _dataStore, bytes32 _routeKey) external view returns (bool) {
        address _route = _dataStore.getAddress(Keys.routeAddressKey(_routeKey));
        uint256 _positionIndex = _dataStore.getUint(Keys.positionIndexKey(_route));
        bytes32 _pendingRequest = _dataStore.getBytes32(Keys.pendingRequestKey(_positionIndex, _route));
        IGMXPositionRouter _positionRouter = IGMXPositionRouter(gmxPositionRouter(_dataStore));
        if (_pendingRequest != bytes32(0)) {
            address[] memory _increasePath = _positionRouter.getIncreasePositionRequestPath(_pendingRequest);
            address[] memory _decreasePath = _positionRouter.getDecreasePositionRequestPath(_pendingRequest);
            if (_increasePath.length > 0 || _decreasePath.length > 0) return true;
            return false; // should never happen
        } else {
            return false;
        }
    }

    // ============================================================================================
    // Mutated functions
    // ============================================================================================

    function updateGMXAddresses(IDataStore _dataStore, bytes memory _data) external {
        (
            address _vaultPriceFeed,
            address _router,
            address _vault,
            address _positionRouter
        ) = abi.decode(_data, (address, address, address, address));

        _dataStore.setAddress(GMXKeys.VAULT_PRICE_FEED, _vaultPriceFeed);
        _dataStore.setAddress(GMXKeys.ROUTER, _router);
        _dataStore.setAddress(GMXKeys.VAULT, _vault);
        _dataStore.setAddress(GMXKeys.POSITION_ROUTER, _positionRouter);
    }
}