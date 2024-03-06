// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {IPositionHandler} from "../interfaces/IPositionHandler.sol";

import {Deposit} from "../puppet/Deposit.sol";
import {Withdraw} from "../puppet/Withdraw.sol";
import {Subscribe} from "../puppet/Subscribe.sol";

import {RequestPosition} from "../trader/RequestPosition.sol";

import {CallbackAsserts} from "./CallbackAsserts.sol";

import "../BaseHelper.t.sol";

contract ReferralLink is BaseHelper {

    // ============================================================================================
    // Helper Functions
    // ============================================================================================

    function registerCode(Context memory _context) public {
        vm.startPrank(_context.users.referrer);

        vm.expectRevert(bytes4(keccak256("InvalidCode()")));
        _context.referralManager.registerCode(bytes32(0));

        bytes32 _code = keccak256(abi.encode("REFERRER_LINK"));
        _context.referralManager.registerCode(_code);

        vm.expectRevert(bytes4(keccak256("CodeAlreadyExists()")));
        _context.referralManager.registerCode(_code);

        assertEq(_context.referralManager.codeOwner(_code), _context.users.referrer, "registerCode: E0");
        assertEq(_context.referralManager.userCode(_context.users.referrer), bytes32(0), "registerCode: E1");
        assertEq(_context.referralManager.codeBoost(_code), 10250, "registerCode: E2");
        assertEq(_context.referralManager.codeTier(_code), 0, "registerCode: E3");

        vm.expectRevert(bytes4(keccak256("InvalidCode()")));
        _context.referralManager.transferCodeOwnership(bytes32(0), _context.users.alice);

        _context.referralManager.transferCodeOwnership(_code, _context.users.alice);
        assertEq(_context.referralManager.codeOwner(_code), _context.users.alice, "registerCode: E4");

        vm.stopPrank();

        vm.expectRevert(bytes4(keccak256("NotCodeOwner()")));
        _context.referralManager.transferCodeOwnership(_code, _context.users.alice);

        vm.prank(_context.users.alice);
        _context.referralManager.transferCodeOwnership(_code, _context.users.referrer);
        assertEq(_context.referralManager.codeOwner(_code), _context.users.referrer, "registerCode: E5");
    }

    function useCode(Context memory _context, address _user) public {
        vm.startPrank(_user);

        vm.expectRevert(bytes4(keccak256("InvalidCode()")));
        _context.referralManager.useCode(bytes32(0));

        vm.expectRevert(bytes4(keccak256("CodeDoesNotExist()")));
        _context.referralManager.useCode(keccak256(abi.encode("REFERRER_LINK1")));

        bytes32 _code = keccak256(abi.encode("REFERRER_LINK"));
        _context.referralManager.useCode(_code);

        assertEq(_context.referralManager.userCode(_user), _code, "useCode: E1");
    }

    // ============================================================================================
    // Test Functions
    // ============================================================================================

    function referralLinkTest(
        Context memory _context,
        Deposit _deposit,
        Subscribe _subscribe,
        RequestPosition _requestPosition,
        CallbackAsserts _callbackAsserts,
        address _positionHandler,
        bytes32 _routeKey
    ) external {
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

        registerCode(_context);
        useCode(_context, _context.users.alice);
        useCode(_context, _trader);

        {
            _context.expectations.isPuppetsSubscribed = true;
            _context.expectations.isSuccessfulExecution = true;
            _context.expectations.isExpectingNonZeroBalance = true;
            _context.expectations.subscribedPuppets = new address[](1);
            _context.expectations.subscribedPuppets[0] = _context.users.alice;

            address _collateralToken = _dataStoreInstance.getAddress(Keys.routeCollateralTokenKey(_route));
            address _indexToken = _dataStoreInstance.getAddress(Keys.routeIndexTokenKey(_route));
            bool _isLong = _dataStoreInstance.getBool(Keys.routeIsLongKey(_route));
            IPositionHandler _positionHandlerInstance = IPositionHandler(_positionHandler);
            _context.expectations.requestKeyToExecute = _positionHandlerInstance.increasePosition(_context, _requestPosition, IBaseRoute.OrderType.MarketIncrease, _trader, _collateralToken, _indexToken, _isLong);
            _positionHandlerInstance.executeRequest(_context, _callbackAsserts, _trader, true, _routeKey);

            _context.expectations.isPositionClosed = true;
            _context.expectations.isExpectingReferralBoost = true;
            _context.expectations.requestKeyToExecute = _positionHandlerInstance.decreasePosition(_context, _requestPosition, IBaseRoute.OrderType.MarketDecrease, true, _routeKey);
            _dealERC20(_collateralToken, _route, 100 ether); // make sure PnL > 0
            _positionHandlerInstance.executeRequest(_context, _callbackAsserts, _trader, false, _routeKey);
        }
    }
}