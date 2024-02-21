// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

// ==============================================================
// _______                   __________________       ________             _____                  ______
// ___    |______ ______________  /__(_)__  __/____  ____  __ \______________  /_____________________  /
// __  /| |_  __ `__ \__  __ \_  /__  /__  /_ __  / / /_  /_/ /_  ___/  __ \  __/  __ \  ___/  __ \_  / 
// _  ___ |  / / / / /_  /_/ /  / _  / _  __/ _  /_/ /_  ____/_  /   / /_/ / /_ / /_/ / /__ / /_/ /  /  
// /_/  |_/_/ /_/ /_/_  .___//_/  /_/  /_/    _\__, / /_/     /_/    \____/\__/ \____/\___/ \____//_/   
//                   /_/                      /____/                                                    
// ==============================================================
// ========================== Route =============================
// ==============================================================
// Amplify Protocol: https://github.com/AmplifyProtocol

// ==============================================================

import {IGMXVault} from "./interfaces/IGMXVault.sol";
import {IGMXRouter} from "./interfaces/IGMXRouter.sol";
import {IGMXPositionRouter} from "./interfaces/IGMXPositionRouter.sol";
import {IPositionRouterCallbackReceiver} from "./interfaces/IPositionRouterCallbackReceiver.sol";

import {GMXKeys} from "./libraries/GMXKeys.sol";
import {GMXHelper} from "./libraries/GMXHelper.sol";

import {Address, BaseRoute, IBaseOrchestrator, IDataStore, IERC20, CommonHelper, Keys, RouteReader, SafeERC20} from "../BaseRoute.sol";

/// @title Route
/// @author johnnyonline
/// @notice This contract extends the ```BaseRoute``` and is modified to fit GMX V1
contract Route is IPositionRouterCallbackReceiver, BaseRoute {

    using Address for address payable;

    using SafeERC20 for IERC20;

    // ============================================================================================
    // Constructor
    // ============================================================================================

    /// @notice The ```constructor``` function is called on deployment
    /// @param _dataStore The dataStore contract address
    constructor(IDataStore _dataStore) BaseRoute(_dataStore) {
        IGMXRouter(GMXHelper.gmxRouter(_dataStore)).approvePlugin(GMXHelper.gmxPositionRouter(_dataStore));
    }

    // ============================================================================================
    // Callback Function
    // ============================================================================================

    /// @inheritdoc IPositionRouterCallbackReceiver
    function gmxPositionCallback(bytes32 _requestKey, bool _isExecuted, bool _isIncrease) external {
        _callback(_requestKey, _isExecuted, _isIncrease);
    }

    // ============================================================================================
    // Internal Mutated Functions
    // ============================================================================================

    /// @notice The ```_getTraderAssets``` function is used to get the assets of the Trader
    /// @dev This function is called by ```_getAssets```
    /// @param _swapParams The swap data of the Trader, enables the Trader to add collateral with a non-collateral token
    /// @param _executionFee The execution fee paid by the Trader, in ETH
    /// @return _traderAmountIn The total amount of collateral the Trader is requesting to add to the position
    function _getTraderAssets(SwapParams memory _swapParams, uint256 _executionFee) override internal returns (uint256 _traderAmountIn) {
        IDataStore _dataStore = dataStore;
        if (msg.value > _executionFee) {
            payable(CommonHelper.wnt(_dataStore)).functionCallWithValue(abi.encodeWithSignature("deposit()"), _swapParams.amount);
        } else {
            IBaseOrchestrator(RouteReader.orchestrator(_dataStore)).transferTokens(_swapParams.amount, _swapParams.path[0]);
        }

        address _collateralToken = CommonHelper.collateralToken(_dataStore, address(this));
        if (_swapParams.path[0] == _collateralToken) {
            _traderAmountIn = _swapParams.amount;
        } else {
            address _toToken = _swapParams.path[_swapParams.path.length - 1];
            if (_toToken != _collateralToken) revert InvalidPath();

            address _router = GMXHelper.gmxRouter(_dataStore);
            IERC20(_swapParams.path[0]).forceApprove(_router, _swapParams.amount);

            uint256 _before = IERC20(_toToken).balanceOf(address(this));
            IGMXRouter(_router).swap(_swapParams.path, _swapParams.amount, _swapParams.minOut, address(this));
            _traderAmountIn = IERC20(_toToken).balanceOf(address(this)) - _before;
        }
    }

    /// @inheritdoc BaseRoute
    function _makeRequestIncreasePositionCall(
        AdjustPositionParams memory _adjustPositionParams,
        uint256 _executionFee
    ) override internal returns (bytes32 _requestKey) {
        IDataStore _dataStore = dataStore;
        address[] memory _path = new address[](1);
        _path[0] = CommonHelper.collateralToken(_dataStore, address(this));

        address _router = GMXHelper.gmxRouter(_dataStore);
        IERC20(_path[0]).forceApprove(_router, _adjustPositionParams.collateralDelta);

        // slither-disable-next-line arbitrary-send-eth
        _requestKey = IGMXPositionRouter(GMXHelper.gmxPositionRouter(_dataStore)).createIncreasePosition{ value: _executionFee } (
            _path,
            CommonHelper.indexToken(_dataStore, address(this)),
            _adjustPositionParams.collateralDelta,
            0, // _minOut - can be 0 since we are not swapping
            _adjustPositionParams.sizeDelta,
            CommonHelper.isLong(_dataStore, address(this)),
            _adjustPositionParams.acceptablePrice,
            _executionFee,
            CommonHelper.referralCode(_dataStore),
            address(this)
        );
    }

    /// @inheritdoc BaseRoute
    function _makeRequestDecreasePositionCall(
        AdjustPositionParams memory _adjustPositionParams,
        uint256 _executionFee
    ) override internal returns (bytes32 _requestKey) {
        IDataStore _dataStore = dataStore;
        address[] memory _path = new address[](1);
        _path[0] = CommonHelper.collateralToken(_dataStore, address(this));
        // slither-disable-next-line arbitrary-send-eth
        _requestKey = IGMXPositionRouter(GMXHelper.gmxPositionRouter(_dataStore)).createDecreasePosition{ value: _executionFee } (
            _path,
            CommonHelper.indexToken(_dataStore, address(this)),
            _adjustPositionParams.collateralDelta,
            _adjustPositionParams.sizeDelta,
            CommonHelper.isLong(_dataStore, address(this)),
            address(this), // _receiver
            _adjustPositionParams.acceptablePrice,
            0, // _minOut - can be 0 since we are not swapping
            _executionFee,
            false, // _withdrawETH
            address(this)
        );
    }

    /// @inheritdoc BaseRoute
    function _cancelRequest(bytes32) override internal pure {}

    // ============================================================================================
    // Internal View Functions
    // ============================================================================================

    function _isOpenInterest() override internal view returns (bool) {
        IDataStore _dataStore = dataStore;
        IGMXVault _vault = IGMXVault(_dataStore.getAddress(GMXKeys.VAULT));
        (uint256 _size, uint256 _collateral,,,,,,) = _vault.getPosition(
            address(this),
            CommonHelper.collateralToken(_dataStore, address(this)),
            CommonHelper.indexToken(_dataStore, address(this)),
            CommonHelper.isLong(_dataStore, address(this))
        );

        return _size > 0 && _collateral > 0;
    }

    function _callBackCaller() override internal view returns (address) {
        return GMXHelper.gmxPositionRouter(dataStore);
    }

    // ============================================================================================
    // Errors
    // ============================================================================================

    error InvalidPath();
}