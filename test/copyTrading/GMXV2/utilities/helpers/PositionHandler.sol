// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {IGMXOrderHandler} from "../../../../../src/integrations/GMXV2/interfaces/IGMXOrderHandler.sol";
import {IGMXOrder} from "../../../../../src/integrations/GMXV2/interfaces/IGMXOrder.sol";
import {IGMXEventUtils} from "../../../../../src/integrations/GMXV2/interfaces/IGMXEventUtils.sol";
import {IOrderCallbackReceiver} from "../../../../../src/integrations/GMXV2/interfaces/IOrderCallbackReceiver.sol";

import {IGMXRoleStore} from "../interfaces/IGMXRoleStore.sol";

import {CallbackAsserts} from "../../../shared/global/CallbackAsserts.sol";

import {RequestPosition} from "../../../shared/trader/RequestPosition.sol";

import {ReaderMock} from "../mocks/ReaderMock.sol";

import "../../../shared/BaseHelper.t.sol";

contract PositionHandler is BaseHelper {

    event Callback(bytes32 requestKey, bool isExecuted, bool isIncrease);
    event ExecutePosition(uint256 performanceFeePaid, address indexed route, bytes32 requestKey, bool isExecuted, bool isIncrease);

    error OrderNotFound(bytes32 key);

    struct OracleParamsArguments {
        bytes32 oracleSalt;
        uint256[] minOracleBlockNumbers;
        uint256[] maxOracleBlockNumbers;
        uint256[] oracleTimestamps;
        bytes32[] blockHashes;
        uint256[] signerIndexes;
        address[] tokens;
        bytes32[] tokenOracleTypes;
        uint256[] precisions;
        uint256[] minPrices;
        uint256[] maxPrices;
        Account[] signers;
        address[] realtimeFeedTokens;
        address[] realtimeFeedData;
        address[] priceFeedTokens;
    }

    struct GetOracleParamsHelper {
        uint256[] allMinPrices;
        uint256[] allMaxPrices;
        uint256[] minPriceIndexes;
        uint256[] maxPriceIndexes;
        bytes[] signatures;
    }

    struct SignPriceHelper {
        uint256 minOracleBlockNumber;
        uint256 maxOracleBlockNumber;
        uint256 oracleTimestamp;
        bytes32 blockHash;
        address token;
        bytes32 tokenOracleType;
        uint256 precision;
        uint256 minPrice;
        uint256 maxPrice;
    }

    uint256 private _pendingSizeAdjustment;
    uint256 private _pendingCollateralAdjustment;

    // ============================================================================================
    // Helper Functions
    // ============================================================================================

    function increasePosition(
        Context memory _context,
        RequestPosition _requestPosition,
        IBaseRoute.OrderType _orderType,
        address _trader,
        address _collateralToken,
        address _indexToken,
        bool _isLong
    ) external returns (bytes32 _requestKey) {
        _pendingSizeAdjustment = 1_000_000;
        _pendingCollateralAdjustment = 100_000;

        uint256 _sizeDelta;
        uint256 _amountInTrader;
        if (_isLong) {
            require(_collateralToken == _indexToken, "IncreasePositionUnitConcrete: collateral token is not index token"); // because of `_amountInTrader`

            // should result in max 10x leverage (if no Puppets funds)
            _sizeDelta = _pendingSizeAdjustment * 1e30; // $1M
            _amountInTrader = _pendingCollateralAdjustment * 1e18 * 1e30 / IBaseOrchestrator(_context.orchestrator).getPrice(_collateralToken); // $100k in ETH

            if (_context.expectations.isExpectingAdjustment) {
                // making sure we decrease the position's leverage
                // should result in max 2x leverage (if no Puppets funds)
                _pendingSizeAdjustment = _pendingSizeAdjustment / 10;
                _pendingCollateralAdjustment = _pendingCollateralAdjustment + 1; // changing the amount to make sure it's not the same as the previous one
                _sizeDelta = _pendingSizeAdjustment * 1e30; // $1M
                _amountInTrader = _pendingCollateralAdjustment * 1e18 * 1e30 / IBaseOrchestrator(_context.orchestrator).getPrice(_collateralToken); // $100k in ETH
            }
        } else {
            require(_collateralToken == _context.usdc, "IncreasePositionUnitConcrete: collateral token not USDC");

            // should result in max 10x leverage (if no Puppets funds)
            _sizeDelta = _pendingSizeAdjustment * 1e30; // $1M
            _amountInTrader = _pendingCollateralAdjustment * 1e6; // $100k in USDC
        }

        IBaseRoute.AdjustPositionParams memory _adjustPositionParams = IBaseRoute.AdjustPositionParams({
            orderType: _orderType,
            collateralDelta: 0,
            sizeDelta: _sizeDelta,
            acceptablePrice: _isLong ? type(uint256).max : type(uint256).min,
            triggerPrice: IBaseOrchestrator(_context.orchestrator).getPrice(_indexToken),
            puppets: _context.expectations.subscribedPuppets
        });

        IBaseRoute.SwapParams memory _swapParams;
        {
            address[] memory _path = new address[](1);
            _path[0] = _collateralToken;
            _swapParams = IBaseRoute.SwapParams({
                path: _path,
                amount: _amountInTrader,
                minOut: 0
            });
        }

        bytes32 _routeTypeKey = _isLong ? _context.longETHRouteTypeKey : _context.shortETHRouteTypeKey;

        _requestKey = _requestPosition.requestPositionERC20(
            _context,
            _adjustPositionParams,
            _swapParams,
            _trader,
            true,
            _routeTypeKey
        );
    }

    function decreasePosition(
        Context memory _context,
        RequestPosition _requestPosition,
        IBaseRoute.OrderType _orderType,
        bool _isClose,
        bytes32 _routeKey
    ) external returns (bytes32 _requestKey) {
        address _route = IDataStore(_context.dataStore).getAddress(Keys.routeAddressKey(_routeKey));
        address _collateralToken = IDataStore(_context.dataStore).getAddress(Keys.routeCollateralTokenKey(_route));
        address _indexToken = IDataStore(_context.dataStore).getAddress(Keys.routeIndexTokenKey(_route));
        bool _isLong = IDataStore(_context.dataStore).getBool(Keys.routeIsLongKey(_route));
        address _trader = IDataStore(_context.dataStore).getAddress(Keys.routeTraderKey(_route));
        IBaseRoute.AdjustPositionParams memory _adjustPositionParams;
        {
            (uint256 _positionSize, uint256 _positionCollateral) = _context.orchestrator.positionAmounts(_route);
            require(_positionSize > 0 && _positionCollateral > 0, "decreasePosition: E1");

            _pendingSizeAdjustment = (_isClose ? _positionSize : _positionSize / 2) / 1e30;
            _pendingCollateralAdjustment = (_isClose ? _positionCollateral : _positionCollateral / 2) / 1e30;

            _adjustPositionParams = IBaseRoute.AdjustPositionParams({
                orderType: _orderType,
                collateralDelta: _pendingCollateralAdjustment,
                sizeDelta: _pendingSizeAdjustment,
                acceptablePrice: _isLong ? type(uint256).min : type(uint256).max,
                triggerPrice: IBaseOrchestrator(_context.orchestrator).getPrice(_indexToken),
                puppets: new address[](0)
            });
        }

        IBaseRoute.SwapParams memory _swapParams;
        {
            address[] memory _path = new address[](1);
            _path[0] = _collateralToken;
            _swapParams = IBaseRoute.SwapParams({
                path: _path,
                amount: 0,
                minOut: 0
            });
        }

        {
            bytes32 _routeTypeKey = _isLong ? _context.longETHRouteTypeKey : _context.shortETHRouteTypeKey;
            _requestKey = _requestPosition.requestPositionERC20(
                _context,
                _adjustPositionParams,
                _swapParams,
                _trader,
                false,
                _routeTypeKey
            );
        }
    }

    function executeRequest(
        Context memory _context,
        CallbackAsserts _callbackAsserts,
        address _trader,
        bool _isIncrease,
        bytes32 _routeKey
    ) external {
        assertTrue(IBaseOrchestrator(_context.orchestrator).isWaitingForCallback(_routeKey), "executeRequest: E0");

        address _route = IDataStore(_context.dataStore).getAddress(Keys.routeAddressKey(_routeKey));

        CallbackAsserts.BeforeData memory _beforeData;
        {
            uint256 _positionIndex = IDataStore(_context.dataStore).getUint(Keys.positionIndexKey(_route));
            address _orchestrator = address(_context.orchestrator);
            address _collateralToken = IDataStore(_context.dataStore).getAddress(Keys.routeCollateralTokenKey(_route));
            _beforeData = CallbackAsserts.BeforeData({
                aliceDepositAccountBalanceBefore: CommonHelper.puppetAccountBalance(_context.dataStore, _context.users.alice, _collateralToken),
                orchestratorEthBalanceBefore: _orchestrator.balance,
                executionFeeBalanceBefore: _context.dataStore.getUint(Keys.EXECUTION_FEE_BALANCE),
                volumeGeneratedBefore: IDataStore(_context.dataStore).getUint(Keys.cumulativeVolumeGeneratedKey(_positionIndex, _route)),
                traderSharesBefore: IDataStore(_context.dataStore).getUint(Keys.positionTraderSharesKey(_positionIndex, _route)),
                traderLastAmountIn: IDataStore(_context.dataStore).getUint(Keys.positionLastTraderAmountInKey(_positionIndex, _route)),
                traderETHBalanceBefore: _trader.balance,
                traderCollateralTokenBalanceBefore: IERC20(_collateralToken).balanceOf(_trader),
                orchestratorCollateralTokenBalanceBefore: IERC20(_collateralToken).balanceOf(_orchestrator),
                trader: _trader,
                isIncrease: _isIncrease,
                routeKey: _routeKey
            });
        }

        // _executeOrder(_context);
        _executeOrderMock(_context, _isIncrease, _routeKey);

        if (_context.expectations.isSuccessfulExecution) {
            _callbackAsserts.postSuccessfulExecution(_context, _beforeData);
        } else {
            _callbackAsserts.postFailedExecution(_context, _beforeData);
        }

        if (_context.expectations.isExpectingAdjustment && _isIncrease) {
            uint256 _requiredAdjustmentSizeBefore = DecreaseSizeResolver(_context.decreaseSizeResolver).requiredAdjustmentSize(_route);
            assertTrue(_requiredAdjustmentSizeBefore > 0, "executeRequest: E1");
            assertTrue(IBaseOrchestrator(_context.orchestrator).isWaitingForCallback(_routeKey), "executeRequest: E2");

            (uint256 _sizeBefore, uint256 _collateralBefore) = IBaseOrchestrator(_context.orchestrator).positionAmounts(_route);
            uint256 _leverageBefore = _sizeBefore * _BASIS_POINTS_DIVISOR / _collateralBefore;
            uint256 _targetLeverage = _context.dataStore.getUint(Keys.targetLeverageKey(_route));
            assertTrue(_leverageBefore > _targetLeverage, "executeRequest: E3");

            uint256 _positionIndex = IDataStore(_context.dataStore).getUint(Keys.positionIndexKey(_route));
            _context.expectations.requestKeyToExecute = _context.dataStore.getBytes32(Keys.pendingRequestKey(_positionIndex, _route));
            _executeOrderMock(_context, false, _routeKey);

            ReaderMock(address(GMXV2OrchestratorHelper.gmxReader(_context.dataStore))).decreasePositionAmounts(_requiredAdjustmentSizeBefore, 0);

            assertEq(DecreaseSizeResolver(_context.decreaseSizeResolver).requiredAdjustmentSize(_route), 0, "executeRequest: E4");
            assertTrue(!IBaseOrchestrator(_context.orchestrator).isWaitingForCallback(_routeKey), "executeRequest: E5");
            assertTrue(!IDataStore(_context.dataStore).getBool(Keys.isWaitingForKeeperAdjustmentKey(_route)), "executeRequest: E6");

            (uint256 _sizeAfter, uint256 _collateralAfter) = IBaseOrchestrator(_context.orchestrator).positionAmounts(_route);
            uint256 _leverageAfter = _sizeAfter * _BASIS_POINTS_DIVISOR / _collateralAfter;
            assertApproxEqAbs(_leverageAfter, _targetLeverage, 500, "executeRequest: E7");
            assertApproxEqAbs(_collateralAfter, _collateralBefore, 1e34, "executeRequest: E8");
            assertTrue(_sizeAfter < _sizeBefore, "executeRequest: E9");
            assertTrue(_leverageAfter < _leverageBefore, "executeRequest: E10");
        }
    }

    function simulateExecuteRequest(
        Context memory _context,
        bytes32 _routeKey,
        bytes32 _requestKey
    ) external {
        IGMXOrderHandler.SimulatePricesParams memory _params;
        _params.primaryTokens = new address[](2);
        _params.primaryTokens[0] = _usdcOld;
        _params.primaryTokens[1] = _weth;

        _params.primaryPrices = new IGMXOrderHandler.Props[](2);
        _params.primaryPrices[0] = IGMXOrderHandler.Props({
            min: IBaseOrchestrator(_context.orchestrator).getPrice(_usdcOld),
            max: IBaseOrchestrator(_context.orchestrator).getPrice(_usdcOld)
        });
        _params.primaryPrices[1] = IGMXOrderHandler.Props({
            min: IBaseOrchestrator(_context.orchestrator).getPrice(_weth),
            max: IBaseOrchestrator(_context.orchestrator).getPrice(_weth)
        });

        address _route = IDataStore(_context.dataStore).getAddress(Keys.routeAddressKey(_routeKey));
        bytes32 _controllerRoleKey = keccak256(abi.encode("CONTROLLER"));
        uint256 _controllers = IGMXRoleStore(_gmxV2RoleStore).getRoleMemberCount(_controllerRoleKey);
        address _controller = IGMXRoleStore(_gmxV2RoleStore).getRoleMembers(_controllerRoleKey, 0, _controllers)[0];
        vm.startPrank(_controller);
        if (_context.expectations.isOrderCancelled) {
            vm.expectRevert(abi.encodeWithSelector(OrderNotFound.selector, _requestKey));
        } else {
            vm.expectEmit(_route);
            emit Callback(_requestKey, true, true);
            vm.expectRevert(bytes4(keccak256("EndOfOracleSimulation()"))); // https://github.com/gmx-io/gmx-synthetics/blob/main/contracts/error/Errors.sol#L169C11-L169C32
        }
        IGMXOrderHandler(_gmxV2OrderHandler).simulateExecuteOrder(_requestKey, _params);
        vm.stopPrank();
    }

    // ============================================================================================
    // Internal Helper Functions
    // ============================================================================================

    function _executeOrderMock(Context memory _context, bool _isIncrease, bytes32 _routeKey) internal {
        address _route = IDataStore(_context.dataStore).getAddress(Keys.routeAddressKey(_routeKey));
        bool _isLong = IDataStore(_context.dataStore).getBool(Keys.routeIsLongKey(_route));

        IGMXOrder.Props memory _order = IGMXOrder.Props({
            addresses: IGMXOrder.Addresses({
                account: _route,
                receiver: _route,
                callbackContract: _route,
                uiFeeReceiver: address(0),
                market: address(0), // not correct
                initialCollateralToken: address(0), // not correct
                swapPath: new address[](0)
            }),
            numbers: IGMXOrder.Numbers({
                orderType: _isIncrease ? IGMXOrder.OrderType.MarketIncrease : IGMXOrder.OrderType.MarketDecrease,
                decreasePositionSwapType: IGMXOrder.DecreasePositionSwapType.NoSwap,
                sizeDeltaUsd: 0, // not correct
                initialCollateralDeltaAmount: 0, // not correct
                triggerPrice: 0, // not correct
                acceptablePrice: 0, // not correct
                executionFee: 0, // not correct
                callbackGasLimit: 0, // not correct
                minOutputAmount: 0, // not correct
                updatedAtBlock: 0 // not correct
            }),
            flags: IGMXOrder.Flags({
                isLong: _isLong ? true : false,
                shouldUnwrapNativeToken: false,
                isFrozen: false
            })
        });

        IGMXEventUtils.EventLogData memory _eventLogData = IGMXEventUtils.EventLogData({
            addressItems: IGMXEventUtils.AddressItems({
                items: new IGMXEventUtils.AddressKeyValue[](0),
                arrayItems: new IGMXEventUtils.AddressArrayKeyValue[](0)
            }),
            uintItems: IGMXEventUtils.UintItems({
                items: new IGMXEventUtils.UintKeyValue[](0),
                arrayItems: new IGMXEventUtils.UintArrayKeyValue[](0)
            }),
            intItems: IGMXEventUtils.IntItems({
                items: new IGMXEventUtils.IntKeyValue[](0),
                arrayItems: new IGMXEventUtils.IntArrayKeyValue[](0)
            }),
            boolItems: IGMXEventUtils.BoolItems({
                items: new IGMXEventUtils.BoolKeyValue[](0),
                arrayItems: new IGMXEventUtils.BoolArrayKeyValue[](0)
            }),
            bytes32Items: IGMXEventUtils.Bytes32Items({
                items: new IGMXEventUtils.Bytes32KeyValue[](0),
                arrayItems: new IGMXEventUtils.Bytes32ArrayKeyValue[](0)
            }),
            bytesItems: IGMXEventUtils.BytesItems({
                items: new IGMXEventUtils.BytesKeyValue[](0),
                arrayItems: new IGMXEventUtils.BytesArrayKeyValue[](0)
            }),
            stringItems: IGMXEventUtils.StringItems({
                items: new IGMXEventUtils.StringKeyValue[](0),
                arrayItems: new IGMXEventUtils.StringArrayKeyValue[](0)
            })
        });

        bytes32 _requestKey = _context.expectations.requestKeyToExecute;
        IOrderCallbackReceiver _routeInstance = IOrderCallbackReceiver(_route);

        vm.expectRevert(bytes4(keccak256("NotCallbackCaller()")));
        _routeInstance.afterOrderExecution(_requestKey, _order, _eventLogData);

        vm.expectRevert(bytes4(keccak256("NotCallbackCaller()")));
        _routeInstance.afterOrderCancellation(_requestKey, _order, _eventLogData);

        if (!_isIncrease && _context.expectations.isExpectingPerformanceFee) {
            uint256 _positionIndex = IDataStore(_context.dataStore).getUint(Keys.positionIndexKey(_route));
            assertEq(_context.dataStore.getUint(Keys.performanceFeePaidKey(_positionIndex, _route)), 0, "_executeOrderMock: E1");
        }

        // ------------------------------------------
        // apply execution effects -- before
        // ------------------------------------------

        address _collateralToken = IDataStore(_context.dataStore).getAddress(Keys.routeCollateralTokenKey(_route));
        if (!_context.expectations.isExpectingNonZeroBalance && !_context.expectations.isExpectingPerformanceFee) require(IERC20(_collateralToken).balanceOf(_route) == 0, "PositionHandler: E1");
        if (_isIncrease && !_context.expectations.isSuccessfulExecution) { // unsuccessful increase
            deal({ token: _collateralToken, to: _route, give: 100_000 * 10 ** IERC20Metadata(_collateralToken).decimals() });
        } else if (!_isIncrease && _context.expectations.isSuccessfulExecution) { // successful decrease
            deal({ token: _collateralToken, to: _route, give: 100_000 * 10 ** IERC20Metadata(_collateralToken).decimals() });
        }

        vm.startPrank(GMXV2RouteHelper.gmxCallBackCaller(_context.dataStore));
        if (_context.expectations.isSuccessfulExecution) {
            uint256 _collateral;
            uint256 _size = _pendingSizeAdjustment * 1e30;
            if (_isLong) {
                _collateral = _pendingCollateralAdjustment * 1e18 * 1e30 / IBaseOrchestrator(_context.orchestrator).getPrice(_collateralToken);
            } else {
                _collateral = _pendingCollateralAdjustment * 1e6;
            }

            if (!_context.expectations.isExpectingAdjustment) {
                if (_isIncrease) {
                    ReaderMock(address(GMXV2OrchestratorHelper.gmxReader(_context.dataStore))).increasePositionAmounts(_size, _collateral);
                } else {
                    if (_context.expectations.isPositionClosed) {
                        ReaderMock(address(GMXV2OrchestratorHelper.gmxReader(_context.dataStore))).resetPositionAmounts();
                    } else {
                        ReaderMock(address(GMXV2OrchestratorHelper.gmxReader(_context.dataStore))).decreasePositionAmounts(_size, _collateral);
                    }
                }
            }
            _routeInstance.afterOrderExecution(_requestKey, _order, _eventLogData);
        } else {
            _routeInstance.afterOrderCancellation(_requestKey, _order, _eventLogData);
        }
        vm.stopPrank();

        // ------------------------------------------
        // apply execution effects -- after
        // ------------------------------------------

        // send unused execution fee to Route -- GMX Keeper sends the unused execution fee AFTER the callback
        vm.deal({ account: GMXV2RouteHelper.gmxCallBackCaller(_context.dataStore), newBalance: _route.balance + _context.executionFee });
        vm.startPrank(GMXV2RouteHelper.gmxCallBackCaller(_context.dataStore));
        (bool success, ) = _route.call{value: _context.executionFee}("");
        require(success, "_executeOrderMock: unable to send ETH");
        vm.stopPrank();

        {
            // add request key to order list
            IDataStore _dataStoreInstance = _context.dataStore;
            bytes32 _orderListKey = keccak256(
                abi.encode(keccak256(abi.encode("ACCOUNT_ORDER_LIST")),
                CommonHelper.routeAddress(_dataStoreInstance, _routeKey))
            );
            GMXV2RouteHelper.gmxDataStore(_dataStoreInstance).removeBytes32(_orderListKey, _requestKey);
        }

        if (!_isIncrease && _context.expectations.isExpectingPerformanceFee) {
            uint256 _positionIndex = IDataStore(_context.dataStore).getUint(Keys.positionIndexKey(_route)) - 1;
            assertTrue(_context.dataStore.getUint(Keys.performanceFeePaidKey(_positionIndex, _route)) > 0, "_executeOrderMock: E2");
        }
    }

    function _executeOrder(Context memory _context) internal {
        vm.startPrank(_gmxV2OrderKeeper);
        IGMXOrderHandler(_gmxV2OrderHandler).executeOrder(_context.expectations.requestKeyToExecute, _getOracleParams(_getOracleParamsArguments()));
        vm.stopPrank();
    }

    function _getOracleParams(
        OracleParamsArguments memory _oracleParamsArguments
    ) internal pure returns (IGMXOrderHandler.SetPricesParams memory _oracleParams) {
        _oracleParams.signerInfo = _getSignerInfo(_oracleParamsArguments.signerIndexes);

        GetOracleParamsHelper memory _getOracleParamsHelper;
        _getOracleParamsHelper.allMinPrices = new uint256[](_oracleParamsArguments.tokens.length * _oracleParamsArguments.signers.length);
        _getOracleParamsHelper.allMaxPrices = new uint256[](_oracleParamsArguments.tokens.length * _oracleParamsArguments.signers.length);
        _getOracleParamsHelper.minPriceIndexes = new uint256[](_oracleParamsArguments.tokens.length * _oracleParamsArguments.signers.length);
        _getOracleParamsHelper.maxPriceIndexes = new uint256[](_oracleParamsArguments.tokens.length * _oracleParamsArguments.signers.length);
        _getOracleParamsHelper.signatures = new bytes[](_oracleParamsArguments.tokens.length * _oracleParamsArguments.signers.length);

        for (uint256 i = 0; i < _oracleParamsArguments.tokens.length; i++) {
            uint256 _minPrice = _oracleParamsArguments.minPrices[i];
            uint256 _maxPrice = _oracleParamsArguments.maxPrices[i];

            SignPriceHelper memory _signPriceHelper;
            _signPriceHelper.minOracleBlockNumber = _oracleParamsArguments.minOracleBlockNumbers[i];
            _signPriceHelper.maxOracleBlockNumber = _oracleParamsArguments.maxOracleBlockNumbers[i];
            _signPriceHelper.oracleTimestamp = _oracleParamsArguments.oracleTimestamps[i];
            _signPriceHelper.blockHash = _oracleParamsArguments.blockHashes[i];
            _signPriceHelper.token = _oracleParamsArguments.tokens[i];
            _signPriceHelper.tokenOracleType = _oracleParamsArguments.tokenOracleTypes[i];
            _signPriceHelper.precision = _oracleParamsArguments.precisions[i];
            _signPriceHelper.minPrice = _minPrice;
            _signPriceHelper.maxPrice = _maxPrice;

            for (uint256 j = 0; j < _oracleParamsArguments.signers.length; j++) {
                bytes32 _oracleSalt = _oracleParamsArguments.oracleSalt;
                Account memory _signer = _oracleParamsArguments.signers[j];
                bytes memory _signature = _signPrice(
                    _signPriceHelper,
                    _signer,
                    _oracleSalt
                );

                uint256 _arrayIndex = _getOracleParamsHelper.allMinPrices.length - 1;
                _getOracleParamsHelper.allMinPrices[_arrayIndex] = _minPrice;
                _getOracleParamsHelper.minPriceIndexes[_arrayIndex] = j;
                _getOracleParamsHelper.allMaxPrices[_arrayIndex] = _maxPrice;
                _getOracleParamsHelper.maxPriceIndexes[_arrayIndex] = j;
                _getOracleParamsHelper.signatures[_arrayIndex] = _signature;
            }
        }

        return IGMXOrderHandler.SetPricesParams({
            signerInfo: _oracleParams.signerInfo,
            tokens: _oracleParamsArguments.tokens,
            compactedMinOracleBlockNumbers: _getCompactedOracleBlockNumbers(_oracleParamsArguments.minOracleBlockNumbers),
            compactedMaxOracleBlockNumbers: _getCompactedOracleBlockNumbers(_oracleParamsArguments.maxOracleBlockNumbers),
            compactedOracleTimestamps: _getCompactedOracleTimestamps(_oracleParamsArguments.oracleTimestamps),
            compactedDecimals: _getCompactedDecimals(_oracleParamsArguments.precisions),
            compactedMinPrices: _getCompactedPrices(_getOracleParamsHelper.allMinPrices),
            compactedMinPricesIndexes: _getCompactedPriceIndexes(_getOracleParamsHelper.minPriceIndexes),
            compactedMaxPrices: _getCompactedPrices(_getOracleParamsHelper.allMaxPrices),
            compactedMaxPricesIndexes: _getCompactedPriceIndexes(_getOracleParamsHelper.maxPriceIndexes),
            signatures: _getOracleParamsHelper.signatures,
            priceFeedTokens: _oracleParamsArguments.priceFeedTokens,
            realtimeFeedTokens: new address[](0),
            realtimeFeedData: new bytes[](0)
        });
    }

    function _getOracleParamsArguments() internal returns (OracleParamsArguments memory _oracleParamsArguments) {
        {
            // https://github.com/gmx-io/gmx-synthetics/blob/main/utils/fixture.ts#L50
            uint256 _chaindID = 4216138; // from BaseGMXV2.t.sol
            string memory _oracleSaltString = "xget-oracle-v1";

            bytes memory _encodedChaindID = abi.encode(_chaindID);
            bytes memory _encodedOracleSaltString = abi.encode(_oracleSaltString);

            bytes[] memory _dataTypes = new bytes[](2);
            bytes[] memory _dataValues = new bytes[](2);

            _dataTypes[0] = "uint256";
            _dataTypes[1] = "string";

            _dataValues[0] = _encodedChaindID;
            _dataValues[1] = _encodedOracleSaltString;

            _oracleParamsArguments.oracleSalt = _hashData(_dataTypes, _dataValues);
        }

        // https://github.com/gmx-io/gmx-synthetics/blob/main/utils/exchange.ts#L87
        _oracleParamsArguments.minOracleBlockNumbers = new uint256[](2);
        _oracleParamsArguments.minOracleBlockNumbers[0] = block.number;
        _oracleParamsArguments.minOracleBlockNumbers[1] = block.number;

        // https://github.com/gmx-io/gmx-synthetics/blob/main/utils/exchange.ts#L90
        _oracleParamsArguments.maxOracleBlockNumbers = new uint256[](2);
        _oracleParamsArguments.maxOracleBlockNumbers[0] = block.number;
        _oracleParamsArguments.maxOracleBlockNumbers[1] = block.number;


        // https://github.com/gmx-io/gmx-synthetics/blob/main/utils/exchange.ts#L92
        _oracleParamsArguments.oracleTimestamps = new uint256[](2);
        _oracleParamsArguments.oracleTimestamps[0] = block.timestamp;
        _oracleParamsArguments.oracleTimestamps[1] = block.timestamp;

        // https://github.com/gmx-io/gmx-synthetics/blob/main/utils/exchange.ts#L94
        _oracleParamsArguments.blockHashes = new bytes32[](2);
        _oracleParamsArguments.blockHashes[0] = blockhash(block.number);
        _oracleParamsArguments.blockHashes[1] = blockhash(block.number);

        // https://github.com/gmx-io/gmx-synthetics/blob/main/utils/fixture.ts#L235
        _oracleParamsArguments.signerIndexes = new uint256[](7);
        _oracleParamsArguments.signerIndexes[0] = 0;
        _oracleParamsArguments.signerIndexes[1] = 1;
        _oracleParamsArguments.signerIndexes[2] = 2;
        _oracleParamsArguments.signerIndexes[3] = 3;
        _oracleParamsArguments.signerIndexes[4] = 4;
        _oracleParamsArguments.signerIndexes[5] = 5;
        _oracleParamsArguments.signerIndexes[6] = 6;

        // https://github.com/gmx-io/gmx-synthetics/blob/main/utils/order.ts#L120
        // https://github.com/gmx-io/gmx-synthetics/blob/main/config/tokens.ts#L118
        _oracleParamsArguments.tokens = new address[](2);
        _oracleParamsArguments.tokens[0] = _weth;
        _oracleParamsArguments.tokens[1] = _usdcOld;

        // https://github.com/gmx-io/gmx-synthetics/blob/main/utils/exchange.ts#L70
        // https://github.com/gmx-io/gmx-synthetics/blob/main/utils/oracle.ts#L10
        {
            string memory _tokenOracleType = "one-percent-per-minute";
            bytes memory _encodedTokenOracleType = abi.encode(_tokenOracleType);

            bytes[] memory _dataTypes = new bytes[](1);
            bytes[] memory _dataValues = new bytes[](1);

            _dataTypes[0] = "string";

            _dataValues[0] = _encodedTokenOracleType;

            bytes32 _tokenOracleTypeHash = _hashData(_dataTypes, _dataValues);

            _oracleParamsArguments.tokenOracleTypes = new bytes32[](2);
            _oracleParamsArguments.tokenOracleTypes[0] = _tokenOracleTypeHash;
            _oracleParamsArguments.tokenOracleTypes[1] = _tokenOracleTypeHash;
        }

        // https://github.com/gmx-io/gmx-synthetics/blob/main/utils/order.ts#L124
        _oracleParamsArguments.precisions = new uint256[](2);
        _oracleParamsArguments.precisions[0] = 8;
        _oracleParamsArguments.precisions[1] = 18;

        // https://github.com/gmx-io/gmx-synthetics/blob/main/utils/order.ts#L125
        _oracleParamsArguments.minPrices = new uint256[](2);
        _oracleParamsArguments.minPrices[0] = 5000 * 1e4;
        _oracleParamsArguments.minPrices[1] = 1 * 1e6;

        // https://github.com/gmx-io/gmx-synthetics/blob/main/utils/order.ts#L126
        _oracleParamsArguments.maxPrices = new uint256[](2);
        _oracleParamsArguments.maxPrices[0] = 5000 * 1e4;
        _oracleParamsArguments.maxPrices[1] = 1 * 1e6;

        // https://github.com/gmx-io/gmx-synthetics/blob/main/utils/exchange.ts#L65
        // https://github.com/gmx-io/gmx-synthetics/blob/main/utils/fixture.ts#L182
        _oracleParamsArguments.signers = new Account[](7);
        _oracleParamsArguments.signers[0] = makeAccount("signer0");
        _oracleParamsArguments.signers[1] = makeAccount("signer1");
        _oracleParamsArguments.signers[2] = makeAccount("signer2");
        _oracleParamsArguments.signers[3] = makeAccount("signer3");
        _oracleParamsArguments.signers[4] = makeAccount("signer4");
        _oracleParamsArguments.signers[5] = makeAccount("signer5");
        _oracleParamsArguments.signers[6] = makeAccount("signer6");

        // https://github.com/gmx-io/gmx-synthetics/blob/main/utils/order.ts#L121
        // _oracleParamsArguments.realtimeFeedTokens = new address[](0);

        // https://github.com/gmx-io/gmx-synthetics/blob/main/utils/order.ts#L122
        // address[] memory _realtimeFeedData = new address[](0);

        // https://github.com/gmx-io/gmx-synthetics/blob/main/utils/order.ts#L123
        // address[] memory _priceFeedTokens = new address[](0);
    }

    // https://github.com/gmx-io/gmx-synthetics/blob/main/utils/oracle.ts#L102C1-L113C2
    function _getSignerInfo(uint256[] memory _signerIndexes) internal pure returns (uint256 _signerInfo) {
        uint256 _signerIndexLength = 16;
        uint256 _maxUint8 = 255; // Maximum value for an 8-bit unsigned integer
    
        _signerInfo = _signerIndexes.length;
        for (uint256 i = 0; i < _signerIndexes.length; i++) {
            uint256 _signerIndex = _signerIndexes[i];

            // Check if the signer index exceeds the maximum 8-bit value
            if (_signerIndex > _maxUint8) revert("Max signer index exceeded");

            // Shift and OR operation
            _signerInfo |= _signerIndex << ((i + 1) * _signerIndexLength);
        }
    }

    // https://github.com/gmx-io/gmx-synthetics/blob/main/utils/oracle.ts#L172
    function _getCompactedOracleBlockNumbers(uint256[] memory _blockNumbers) internal pure returns (uint256[] memory) {
        uint256 _compactedValueBitLength = 64;
        uint256 _maxValue = 18446744073709551615; // 2^64 - 1 // https://github.com/gmx-io/gmx-synthetics/blob/main/utils/math.ts#L6C27-L6C62
        return _getCompactedValues(_blockNumbers, _compactedValueBitLength, _maxValue);
    }

    // https://github.com/gmx-io/gmx-synthetics/blob/main/utils/oracle.ts#L180
    function _getCompactedOracleTimestamps(uint256[] memory _timestamps) internal pure returns (uint256[] memory) {
        uint256 _compactedValueBitLength = 64;
        uint256 _maxValue = 18446744073709551615; // 2^64 - 1 // https://github.com/gmx-io/gmx-synthetics/blob/main/utils/math.ts#L6C27-L6C62
        return _getCompactedValues(_timestamps, _compactedValueBitLength, _maxValue);
    }

    // https://github.com/gmx-io/gmx-synthetics/blob/main/utils/oracle.ts#L164
    function _getCompactedDecimals(uint256[] memory _decimals) internal pure returns (uint256[] memory) {
        uint256 _compactedValueBitLength = 8;
        uint256 _maxValue = 255; // 2^8 - 1 // https://github.com/gmx-io/gmx-synthetics/blob/main/utils/math.ts#L4
        return _getCompactedValues(_decimals, _compactedValueBitLength, _maxValue);
    }

    // https://github.com/gmx-io/gmx-synthetics/blob/main/utils/oracle.ts#L148
    function _getCompactedPrices(uint256[] memory _prices) internal pure returns (uint256[] memory) {
        uint256 _compactedValueBitLength = 32;
        uint256 _maxValue = 4294967295; // 2^32 - 1 // https://github.com/gmx-io/gmx-synthetics/blob/main/utils/math.ts#L5
        return _getCompactedValues(_prices, _compactedValueBitLength, _maxValue);
    }

    // https://github.com/gmx-io/gmx-synthetics/blob/main/utils/oracle.ts#L156
    function _getCompactedPriceIndexes(uint256[] memory _priceIndexes) internal pure returns (uint256[] memory) {
        uint256 _compactedValueBitLength = 8;
        uint256 _maxValue = 255; // 2^8 - 1 // https://github.com/gmx-io/gmx-synthetics/blob/main/utils/math.ts#L4
        return _getCompactedValues(_priceIndexes, _compactedValueBitLength, _maxValue);
    }

    // https://github.com/gmx-io/gmx-synthetics/blob/main/utils/oracle.ts#L115
    // values, uint compactedValueBitLength, uint maxValue
    function _getCompactedValues(uint256[] memory _values, uint256 _compactedValueBitLength, uint256 _maxValue) internal pure returns (uint256[] memory _compactedValues) {
        require(_compactedValueBitLength > 0, "Bit length must be greater than zero");
        uint256 _compactedValuesPerSlot = 256 / _compactedValueBitLength;
        _compactedValues = new uint[]((_values.length + _compactedValuesPerSlot - 1) / _compactedValuesPerSlot);

        for (uint256 i = 0; i < _compactedValues.length; i++) {
            uint256 _valueBits = 0;
            for (uint j = 0; j < _compactedValuesPerSlot; j++) {
                uint index = i * _compactedValuesPerSlot + j;
                if (index >= _values.length) {
                    break;
                }

                uint value = _values[index];
                require(value <= _maxValue, "Max value exceeded");

                _valueBits |= value << (j * _compactedValueBitLength);
            }
            _compactedValues[i] = _valueBits;
        }

        return _compactedValues;
    }

    // https://github.com/gmx-io/gmx-synthetics/blob/main/utils/hash.ts#L9
    function _hashData(bytes[] memory _dataTypes, bytes[] memory _dataValues) internal pure returns (bytes32) {
        bytes memory _encodedData = abi.encode(_dataTypes, _dataValues);
        return keccak256(_encodedData);
    }

    function _hashString(bytes[] memory _dataValues) internal pure returns (bytes32) {
        bytes[] memory _stringDataTypes = new bytes[](1);
        _stringDataTypes[0] = "string";

        return _hashData(_stringDataTypes, _dataValues);
    }

    function _signPrice(
        SignPriceHelper memory _signPriceHelper,
        Account memory _signer,
        bytes32 _salt
    ) internal pure returns (bytes memory) {
        require(_signPriceHelper.minOracleBlockNumber <= type(uint64).max, "signPrice: E0");
        require(_signPriceHelper.maxOracleBlockNumber <= type(uint64).max, "signPrice: E1");
        require(_signPriceHelper.oracleTimestamp <= type(uint64).max, "signPrice: E2");
        require(_signPriceHelper.precision <= type(uint8).max, "signPrice: E3");
        require(_signPriceHelper.minPrice <= type(uint32).max, "signPrice: E4");
        require(_signPriceHelper.maxPrice <= type(uint32).max, "signPrice: E5");

        uint256 _expandedPrecision = _expandDecimals(1, _signPriceHelper.precision);

        bytes[] memory _dataTypes = new bytes[](10);
        _dataTypes[0] = "bytes32";
        _dataTypes[1] = "uint256";
        _dataTypes[2] = "uint256";
        _dataTypes[3] = "uint256";
        _dataTypes[4] = "bytes32";
        _dataTypes[5] = "address";
        _dataTypes[6] = "bytes32";
        _dataTypes[7] = "uint256";
        _dataTypes[8] = "uint256";
        _dataTypes[9] = "uint256";

        bytes[] memory _dataValues = new bytes[](10);
        _dataValues[0] = abi.encode(_salt);
        _dataValues[1] = abi.encode(_signPriceHelper.minOracleBlockNumber);
        _dataValues[2] = abi.encode(_signPriceHelper.maxOracleBlockNumber);
        _dataValues[3] = abi.encode(_signPriceHelper.oracleTimestamp);
        _dataValues[4] = abi.encode(_signPriceHelper.blockHash);
        _dataValues[5] = abi.encode(_signPriceHelper.token);
        _dataValues[6] = abi.encode(_signPriceHelper.tokenOracleType);
        _dataValues[7] = abi.encode(_expandedPrecision);
        _dataValues[8] = abi.encode(_signPriceHelper.minPrice);
        _dataValues[9] = abi.encode(_signPriceHelper.maxPrice);

        bytes32 _hash = _hashData(_dataTypes, _dataValues);

        return _signMsg(_signer, _hash);
    }

    function _expandDecimals(uint256 _amount, uint256 _precision) internal pure returns (uint256) {
        return _amount * (10 ** _precision);
    }

    function _signMsg(Account memory _signer, bytes32 _hash) internal pure returns (bytes memory) {
        // create digest: keccak256 gives us the first 32bytes after doing the hash
        // so this is always 32 bytes.
        bytes32 _digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32",
                                                    bytes32(uint256(uint160(_signer.addr))), 
                                                    _hash)
        );

        // r and s are the outputs of the ECDSA signature
        // r,s and v are packed into the signature. It should be 65 bytes: 32 + 32 + 1
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_signer.key, _digest);

        // pack v, r, s into 65bytes signature
        // bytes memory signature = abi.encodePacked(r, s, v);
        return abi.encodePacked(r, s, v);
    }
}