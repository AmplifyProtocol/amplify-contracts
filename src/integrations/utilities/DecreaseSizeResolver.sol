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
// ==================== DecreaseSizeResolver ====================
// ==============================================================
// Amplify Protocol: https://github.com/AmplifyProtocol

// ==============================================================

import {Auth, Authority} from "@solmate/auth/Auth.sol";

import {AutomateTaskCreator, Module, ModuleData} from "@gelato/integrations/AutomateTaskCreator.sol";

import {CommonHelper} from "../libraries/CommonHelper.sol";
import {Keys} from "../libraries/Keys.sol";

import {IDataStore} from "./interfaces/IDataStore.sol";

import {IBaseOrchestrator} from "../interfaces/IBaseOrchestrator.sol";
import {IBaseRoute} from "../interfaces/IBaseRoute.sol";

/// @title DecreaseSizeResolver
/// @author johnnyonline
/// @notice DecreaseSizeResolver is used as a Gelato resolver to decrease the size of a position
contract DecreaseSizeResolver is AutomateTaskCreator, Auth {

    uint256 public executionFee;
    uint256 public priceFeedSlippage;

    bytes32 public taskId;

    IDataStore public dataStore;

    // ============================================================================================
    // Constructor
    // ============================================================================================

    constructor(Authority _authority, IDataStore _dataStore, address _automate)
        AutomateTaskCreator(_automate) Auth(address(0), _authority)
    {
        dataStore = _dataStore;

        executionFee = 180000000000000; // @todo
        priceFeedSlippage = 2000000; // 0.5%
    }

    // ============================================================================================
    // View Functions
    // ============================================================================================

    /// @notice The ```requiredAdjustmentSize``` function returns the required adjustment size for the Route Account
    /// @notice If Puppets cannot pay the required amount when a Trader adds collateral to an existing position, we need to decrease their size so the position's size/collateral ratio is as expected
    /// @notice This function is called by the Keeper when `targetLeverage` is set 
    /**
     @dev Returns the required adjustment size, USD denominated, with 30 decimals of precision, ready to be used by the Keeper

     We get the required adjustment size by calculating the difference between the current position size and the target position size:
      - requiredAdjustmentSize = currentPositionSize - targetPositionSize
      -
      - targetPositionSize:
       - the position size needed to maintain the targetLeverage, with the actual collateral amount that was added by all participants (i.e. current collateral in position)
       - (targetPositionSize = currentCollateral * targetLeverage)
      -
      - currentPositionSize:
       - the position size that maintains the targetLeverage if all participants were to add the required collateral amount
       - (it's expected from Trader to input a `sizeDelta` that assumes all Puppets are adding the required amount of collateral)

     The 'required amount of collateral' is the ratio between the last deposit to the current one
      - puppetLastAmountsIn * increaseRatio / precision
    */
    /// @param _route The route to check
    /// @return _size The required adjustment size, USD denominated, with 30 decimals of precision
    function requiredAdjustmentSize(address _route) public view returns (uint256) {
        IDataStore _dataStore = dataStore;
        (uint256 _size, uint256 _collateral) = IBaseOrchestrator(CommonHelper.orchestrator(_dataStore)).positionAmounts(_route);

        uint256 _targetLeverage = _dataStore.getUint(Keys.targetLeverageKey(_route));
        return _targetLeverage != 0 ? _size - (_collateral * _targetLeverage / CommonHelper.basisPointsDivisor()) : 0;
    }

    function checker() external view returns (bool _canExec, bytes memory _execPayload) {
        IDataStore _dataStore = dataStore;
        address[] memory _routes = CommonHelper.routes(_dataStore);
        for (uint256 i = 0; i < _routes.length; i++) {
            address _route = _routes[i];
            if (_dataStore.getBool(Keys.isKeeperAdjustmentEnabledKey(_route))) {
                IBaseRoute.AdjustPositionParams memory _adjustPositionParams = IBaseRoute.AdjustPositionParams({
                    orderType: IBaseRoute.OrderType.MarketDecrease,
                    collateralDelta: 0, // we don't remove collateral
                    sizeDelta: requiredAdjustmentSize(_route),
                    acceptablePrice: _getAcceptablePrice(_route),
                    triggerPrice: 0, // a market order doesn't need a trigger price
                    puppets: new address[](0)
                });

                _execPayload = abi.encodeWithSelector(
                    IBaseOrchestrator.decreaseSize.selector,
                    _adjustPositionParams,
                    executionFee,
                    CommonHelper.routeKey(_dataStore, _route)
                );

                return(true, _execPayload);
            }
        }

        return(false, bytes("No adjustment needed"));
    }

    // ============================================================================================
    // Mutated Functions
    // ============================================================================================

    function depositFunds(uint256 _amount, address _token, address _sponsor) external payable {
        if (_token == ETH && msg.value != _amount) revert WrongAmount();

        _depositFunds1Balance(_amount, _token, _sponsor);
    }

    // ============================================================================================
    // Authority Functions
    // ============================================================================================

    function createTask(address _orchestrator) external payable requiresAuth {
        if (taskId != bytes32("")) revert AlreadyStartedTask();

        ModuleData memory _moduleData = ModuleData({
            modules: new Module[](2),
            args: new bytes[](2)
        });

        _moduleData.modules[0] = Module.RESOLVER;
        _moduleData.modules[1] = Module.PROXY;

        _moduleData.args[0] = _resolverModuleArg(
            address(this),
            abi.encodeCall(this.checker, ())
        );
        _moduleData.args[1] = _proxyModuleArg();

        bytes32 _id = _createTask(
            _orchestrator,
            abi.encode(IBaseOrchestrator.decreaseSize.selector),
            _moduleData,
            ETH
        );

        taskId = _id;

        emit TaskCreated(_id);
    }

    function setExecutionFee(uint256 _executionFee) external requiresAuth {
        executionFee = _executionFee;
    }

    function setPriceFeedSlippage(uint256 _priceFeedSlippage) external requiresAuth {
        priceFeedSlippage = _priceFeedSlippage;
    }

    // ============================================================================================
    // Internal Function
    // ============================================================================================

    function _getAcceptablePrice(address _route) internal view returns (uint256) {
        IDataStore _dataStore = dataStore;
        uint256 _basisPointsDivisor = CommonHelper.basisPointsDivisor();
        uint256 _indexTokenPrice = IBaseOrchestrator(CommonHelper.orchestrator(_dataStore)).getPrice(CommonHelper.indexToken(_dataStore, _route));
        return CommonHelper.isLong(_dataStore, _route) 
        ? _indexTokenPrice * _basisPointsDivisor / priceFeedSlippage
        : _indexTokenPrice * priceFeedSlippage / _basisPointsDivisor;
    }

    // ============================================================================================
    // Receive Function
    // ============================================================================================

    receive() external payable {}

    // ============================================================================================
    // Events
    // ============================================================================================

    event TaskCreated(bytes32 taskId);

    // ============================================================================================
    // Errors
    // ============================================================================================

    error AlreadyStartedTask();
    error WrongAmount();
}