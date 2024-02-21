// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {IPositionHandler} from "../interfaces/IPositionHandler.sol";

import {Deposit} from "../puppet/Deposit.sol";
import {Withdraw} from "../puppet/Withdraw.sol";
import {Subscribe} from "../puppet/Subscribe.sol";

import {RequestPosition} from "../trader/RequestPosition.sol";

import {CallbackAsserts} from "./CallbackAsserts.sol";

import "../BaseHelper.t.sol";

contract Fees is BaseHelper {

    uint256 public constant MAX_FEE = 1000; // 10% max fee

    // ============================================================================================
    // Helper Functions
    // ============================================================================================

    function setFees(Context memory _context, uint256 _managmentFee, uint256 _withdrawalFee, uint256 _performanceFee) public {
        IBaseOrchestrator _orchestratorInstance = IBaseOrchestrator(_context.orchestrator);

        vm.expectRevert("UNAUTHORIZED");
        _orchestratorInstance.updateFees(_managmentFee, _withdrawalFee, _performanceFee);

        vm.startPrank(_context.users.owner);

        vm.expectRevert(bytes4(keccak256("FeeExceedsMax()")));
        _orchestratorInstance.updateFees(MAX_FEE + 1, _withdrawalFee, _performanceFee);

        vm.expectRevert(bytes4(keccak256("FeeExceedsMax()")));
        _orchestratorInstance.updateFees(_managmentFee, MAX_FEE + 1, _performanceFee);

        vm.expectRevert(bytes4(keccak256("FeeExceedsMax()")));
        _orchestratorInstance.updateFees(_managmentFee, _withdrawalFee, MAX_FEE + 1);

        _orchestratorInstance.updateFees(_managmentFee, _withdrawalFee, _performanceFee);

        vm.stopPrank();

        assertEq(_managmentFee, IDataStore(_context.dataStore).getUint(Keys.MANAGEMENT_FEE), "setFees: E1");
        assertEq(_withdrawalFee, IDataStore(_context.dataStore).getUint(Keys.WITHDRAWAL_FEE), "setFees: E2");
        assertEq(_performanceFee, IDataStore(_context.dataStore).getUint(Keys.PERFORMANCE_FEE), "setFees: E3");
    }

    // ============================================================================================
    // Test Functions
    // ============================================================================================

    function withdrawalFeeTest(Context memory _context, Deposit _deposit, Withdraw _withdraw) external {
        uint256 _fee = 1000; // 10% max fee
        setFees(_context, _fee, _fee, _fee);

        _withdraw.withdrawFlowTest(_context, _deposit);
    }

    function managmentFeeTest(
        Context memory _context,
        Deposit _deposit,
        Subscribe _subscribe,
        RequestPosition _requestPosition,
        address _positionHandler,
        bytes32 _routeKey
    ) external {
        {
            uint256 _fee = 1000; // 10% max fee
            setFees(_context, _fee, _fee, _fee);
        }

        address _route = IDataStore(_context.dataStore).getAddress(Keys.routeAddressKey(_routeKey));
        address _trader = IDataStore(_context.dataStore).getAddress(Keys.routeTraderKey(_route));

        _deposit.depositEntireWNTBalance(_context, _context.users.alice, false);
        _subscribe.subscribe(
            _context,
            _context.users.alice,
            true,
            _BASIS_POINTS_DIVISOR / 2, // 50% allowance
            block.timestamp + 1 weeks,
            _trader,
            IDataStore(_context.dataStore).getBytes32(Keys.routeRouteTypeKey(_route))
        );

        address _collateralToken = IDataStore(_context.dataStore).getAddress(Keys.routeCollateralTokenKey(_route));
        assertEq(IDataStore(_context.dataStore).getUint(Keys.platformAccountKey(_collateralToken)), 0, "testManagmentFee: E2");

        {
            _context.expectations.isPuppetsSubscribed = true;
            _context.expectations.subscribedPuppets = new address[](1);
            _context.expectations.subscribedPuppets[0] = _context.users.alice;

            address _indexToken = IDataStore(_context.dataStore).getAddress(Keys.routeIndexTokenKey(_route));
            bool _isLong = IDataStore(_context.dataStore).getBool(Keys.routeIsLongKey(_route));
            IPositionHandler(_positionHandler).increasePosition(_context, _requestPosition, IBaseRoute.OrderType.MarketIncrease, _trader, _collateralToken, _indexToken, _isLong);
        }

        // not checking for exact value because of trader could add less collateral than the allowance amount
        assertTrue(IDataStore(_context.dataStore).getUint(Keys.platformAccountKey(_collateralToken)) > 0, "testManagmentFee: E3");
    }

    function performanceFeeTest(
        Context memory _context,
        Deposit _deposit,
        Subscribe _subscribe,
        RequestPosition _requestPosition,
        CallbackAsserts _callbackAsserts,
        address _positionHandler,
        bytes32 _routeKey
    ) external {
        {
            uint256 _fee = 1000; // 10% max fee
            setFees(_context, _fee, _fee, _fee);
        }

        IDataStore _dataStoreInstance = IDataStore(_context.dataStore);
        address _route = _dataStoreInstance.getAddress(Keys.routeAddressKey(_routeKey));
        address _trader = _dataStoreInstance.getAddress(Keys.routeTraderKey(_route));
        _deposit.depositEntireWNTBalance(_context, _context.users.alice, false);
        _subscribe.subscribe(
            _context,
            _context.users.alice,
            true,
            _BASIS_POINTS_DIVISOR / 2, // 50% allowance
            block.timestamp + 1 weeks,
            _trader,
            _dataStoreInstance.getBytes32(Keys.routeRouteTypeKey(_route))
        );

        {
            _context.expectations.isPuppetsSubscribed = true;
            _context.expectations.isSuccessfulExecution = true;
            _context.expectations.subscribedPuppets = new address[](1);
            _context.expectations.subscribedPuppets[0] = _context.users.alice;

            address _collateralToken = _dataStoreInstance.getAddress(Keys.routeCollateralTokenKey(_route));
            address _indexToken = _dataStoreInstance.getAddress(Keys.routeIndexTokenKey(_route));
            bool _isLong = _dataStoreInstance.getBool(Keys.routeIsLongKey(_route));
            IPositionHandler _positionHandlerInstance = IPositionHandler(_positionHandler);
            _context.expectations.requestKeyToExecute = _positionHandlerInstance.increasePosition(_context, _requestPosition, IBaseRoute.OrderType.MarketIncrease, _trader, _collateralToken, _indexToken, _isLong);
            _positionHandlerInstance.executeRequest(_context, _callbackAsserts, _trader, true, _routeKey);

            _context.expectations.isPositionClosed = true;
            _context.expectations.isExpectingPerformanceFee = true;
            _context.expectations.requestKeyToExecute = _positionHandlerInstance.decreasePosition(_context, _requestPosition, IBaseRoute.OrderType.MarketDecrease, true, _routeKey);
            _dealERC20(_collateralToken, _route, 100 ether); // make sure PnL > 0
            _positionHandlerInstance.executeRequest(_context, _callbackAsserts, _trader, false, _routeKey);
        }
    }
}