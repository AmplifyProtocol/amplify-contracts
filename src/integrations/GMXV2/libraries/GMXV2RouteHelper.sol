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
// ================== GMXV2OrchestratorHelper ===================
// ==============================================================
// Amplify Protocol: https://github.com/AmplifyProtocol

// ==============================================================

import {CommonHelper, Keys} from "../../libraries/CommonHelper.sol";

import {OrderUtils} from "./OrderUtils.sol";
import {GMXV2Keys} from "./GMXV2Keys.sol";

import {IBaseRoute} from "../../interfaces/IBaseRoute.sol";
import {IBaseOrchestrator} from "../../interfaces/IBaseOrchestrator.sol";

import {IDataStore} from "../../utilities/interfaces/IDataStore.sol";

import {IGMXDataStore} from "../interfaces/IGMXDataStore.sol";
import {IGMXExchangeRouter} from "../interfaces/IGMXExchangeRouter.sol";
import {IGMXOrder} from "../interfaces/IGMXOrder.sol";
import {IGMXPosition} from "../interfaces/IGMXPosition.sol";
import {IGMXReader} from "../interfaces/IGMXReader.sol";

/// @title GMXV2RouteHelper
/// @author johnnyonline
/// @dev Helper functions for Route GMX V2 integration
library GMXV2RouteHelper {

    // ============================================================================================
    // View Functions
    // ============================================================================================

    // gmx contract addresses

    function gmxDataStore(IDataStore _dataStore) public view returns (IGMXDataStore) {
        return IGMXDataStore(_dataStore.getAddress(GMXV2Keys.GMX_DATA_STORE));
    }

    function gmxExchangeRouter(IDataStore _dataStore) external view returns (IGMXExchangeRouter) {
        return IGMXExchangeRouter(_dataStore.getAddress(GMXV2Keys.EXCHANGE_ROUTER));
    }

    function gmxRouter(IDataStore _dataStore) external view returns (address) {
        return _dataStore.getAddress(GMXV2Keys.ROUTER);
    }

    function gmxOrderVault(IDataStore _dataStore) external view returns (address) {
        return _dataStore.getAddress(GMXV2Keys.ORDER_VAULT);
    }

    function gmxCallBackCaller(IDataStore _dataStore) external view returns (address) {
        return _dataStore.getAddress(GMXV2Keys.ORDER_HANDLER);
    }

    // gmx data

    function getCreateOrderParams(
        IDataStore _dataStore,
        IBaseRoute.AdjustPositionParams memory _adjustPositionParams,
        uint256 _executionFee,
        bool _isIncrease
    ) external view returns (OrderUtils.CreateOrderParams memory _params) {
        OrderUtils.CreateOrderParamsAddresses memory _addressesParams = OrderUtils.CreateOrderParamsAddresses(
            address(this), // receiver
            address(this), // callbackContract
            CommonHelper.platformFeeRecipient(_dataStore), // uiFeeReceiver
            _dataStore.getAddress(GMXV2Keys.routeMarketToken(address(this))), // marketToken
            CommonHelper.collateralToken(_dataStore, address(this)), // initialCollateralToken
            new address[](0) // swapPath
        );

        OrderUtils.CreateOrderParamsNumbers memory _numbersParams = OrderUtils.CreateOrderParamsNumbers(
            _adjustPositionParams.sizeDelta,
            _adjustPositionParams.collateralDelta,
            _adjustPositionParams.triggerPrice,
            _adjustPositionParams.acceptablePrice,
            _executionFee,
            gmxDataStore(_dataStore).getUint(keccak256(abi.encode("MAX_CALLBACK_GAS_LIMIT"))),
            0 // _minOut - can be 0 since we are not swapping
        );

        _params = OrderUtils.CreateOrderParams(
            _addressesParams,
            _numbersParams,
            _getOrderType(_adjustPositionParams.orderType),
            _isIncrease ? IGMXOrder.DecreasePositionSwapType.NoSwap : IGMXOrder.DecreasePositionSwapType.SwapPnlTokenToCollateralToken,
            CommonHelper.isLong(_dataStore, address(this)),
            false, // shouldUnwrapNativeToken
            CommonHelper.referralCode(_dataStore)
        );
    }

    function isOpenInterest(IDataStore _dataStore) external view returns (bool) {
        bytes32 _positionKey = IBaseOrchestrator(_dataStore.getAddress(Keys.ORCHESTRATOR)).positionKey(address(this));
        IGMXPosition.Props memory _position = IGMXReader(_dataStore.getAddress(GMXV2Keys.GMX_READER)).getPosition(gmxDataStore(_dataStore), _positionKey);
        return _position.numbers.sizeInUsd > 0 || _position.numbers.collateralAmount > 0;
    }

    // ============================================================================================
    // Private View Functions
    // ============================================================================================

    function _getOrderType(IBaseRoute.OrderType _orderType) private pure returns (IGMXOrder.OrderType) {
        if (_orderType == IBaseRoute.OrderType.MarketIncrease) {
            return IGMXOrder.OrderType.MarketIncrease;
        } else if (_orderType == IBaseRoute.OrderType.LimitIncrease) {
            return IGMXOrder.OrderType.LimitIncrease;
        } else if (_orderType == IBaseRoute.OrderType.MarketDecrease) {
            return IGMXOrder.OrderType.MarketDecrease;
        } else if (_orderType == IBaseRoute.OrderType.LimitDecrease) {
            return IGMXOrder.OrderType.LimitDecrease;
        } else {
            revert("GMXV2RouteHelper: invalid order type");
        }
    }
}