// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IBaseOrchestrator} from "src/integrations/interfaces/IBaseOrchestrator.sol";
import {GMXV2Reader} from "src/integrations/utilities/GmxV2Reader.sol";
import "test/copyTrading/GMXV2/BaseGMXV2.t.sol";
import "./DeployerUtilities.sol";

// ---- Usage ----
// forge script script/utilities/IncreasePosition.s.sol:IncreasePosition --legacy --rpc-url $RPC_URL --broadcast

contract IncreasePosition is DeployerUtilities ,BaseGMXV2 {

    IBaseOrchestrator _gmxOrchestrator = IBaseOrchestrator(payable(address(0x32F1469A9D8E63923C1d4a6eaCf7830142BAbfbb)));

    uint256 internal _privateKey = vm.envUint("TRADER_PRIVATE_KEY");
    address internal _trader = vm.envAddress("TRADER_ADDRESS");

    bytes32 _marketType = bytes32(0x4bd5869a01440a9ac6d7bf7aa7004f402b52b845f20e2cec925101e13d84d075); // (https://arbiscan.io/tx/0x80ef8c8a10babfaad5c9b2c97d0f4b0f30f61ba6ceb201ea23f5c5737e46bc36)
    address _shortToken = _usdc;
    address _longToken = _weth;
    address _indexToken = _weth;
    address _collateralToken = _weth;
    bool _isLong = true;

    uint256 _sizeAdjustment = 50;
    uint256 _collateralAdjustment = 10;

    function run() public {
        vm.startBroadcast(_privateKey);

        bytes32 _salt = keccak256(abi.encode("GMX_MARKET", _indexToken, _longToken, _shortToken, _marketType));
        IGMXMarket.Props memory _marketData = IGMXReader(_gmxV2Reader).getMarketBySalt(_gmxV2DataStore, _salt);
        _ethLongMarketData = abi.encode( _marketData.marketToken);

        bytes32 _routeTypeKey = Keys.routeTypeKey(_collateralToken, _indexToken, _isLong, _ethLongMarketData);
        bytes32 _routeKey = _gmxOrchestrator.registerRoute(_routeTypeKey);
        
        console.log(_trader);
        console.logBytes32(_routeTypeKey);
        console.logBytes32(_routeKey);

        //=================================
        uint256 _sizeDelta = _sizeAdjustment * 1e30; // $50
        uint256 _amountInTrader = _collateralAdjustment * 1e18 * 1e30 / _gmxOrchestrator.getPrice(_collateralToken); // $10 in ETH
        {
        IBaseRoute.AdjustPositionParams memory _adjustPositionParams = IBaseRoute.AdjustPositionParams({
            orderType: IBaseRoute.OrderType.MarketIncrease,
            collateralDelta: _amountInTrader,
            sizeDelta: _sizeDelta,
            acceptablePrice:  _isLong ? type(uint256).max : type(uint256).min,
            triggerPrice: _gmxOrchestrator.getPrice(_indexToken),
            puppets: new address[](0)
        });

        address[] memory _path = new address[](1);
        _path[0] = _weth;
        IBaseRoute.SwapParams memory _swapParams;
        _swapParams = IBaseRoute.SwapParams({
            path: _path,
            amount: _amountInTrader,
            minOut: 0
        });

        uint256 _executionFee = IGMXPositionRouter(_gmxV2PositionRouter).minExecutionFee();

        IBaseRoute.ExecutionFees memory _executionFees;
        _executionFees = IBaseRoute.ExecutionFees({
            dexKeeper:  _executionFee,
            puppetKeeper: _executionFee 
        });
        
        bytes32 _requestKey = _gmxOrchestrator.requestPosition{ value:  _executionFee * 2 }(_adjustPositionParams, _swapParams, _executionFees, _routeTypeKey, true);
        
        console.logBytes32(_requestKey);
        }
        
        vm.stopPrank();
    }
}