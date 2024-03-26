// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

// ======= OPENED POSITION =======
// market_address: 0x70d95587d40A2caf56bd97485aB3Eec10Bee6336
// trader:         0x5d2473EB50365C98B4fFc7064B241b77C8c9bB63
// routeTypeKey:   0xc1513a1f97dd396583308cbc6b016ae90eb062eb1e28f06e00aa8494e629b8f9
// routeKey:       0x7b20751639ca41628bdab366ff7375ea487a9cdb5acc38f95ffa296e8c82d23e
// requestKey:     0x9d8d9203f292bf87100d846d475b793b6567b15e9f4ec9aaff2ed10fb720de12
// ================================

import "../../BaseGMXV2.t.sol";
import  {GMXV2Reader} from "src/integrations/utilities/GmxV2Reader.sol";

contract GMXV2ReaderTest is BaseGMXV2 {

    GMXV2Reader _reader;
    
    // ===== real position =====
    bytes32 _routeTypeKey = 0xc1513a1f97dd396583308cbc6b016ae90eb062eb1e28f06e00aa8494e629b8f9;
    address _trader = 0x5d2473EB50365C98B4fFc7064B241b77C8c9bB63;
    address market = 0x70d95587d40A2caf56bd97485aB3Eec10Bee6336;

    address puppetA;
    address puppetB;
    address puppetC;
    address puppetD;
    address unsubscribedPuppet;

    address routeMock;
    bytes32 routeTypeKeyMock;

    function setUp() public override {
        BaseGMXV2.setUp();

        _reader = new GMXV2Reader();

        bytes32 _routeKeyMock = _registerRoute.registerRoute(context, context.users.trader, _weth, _weth, true, _ethLongMarketData);
        routeMock = _dataStore.getAddress(Keys.routeAddressKey(_routeKeyMock));
        routeTypeKeyMock = _dataStore.getBytes32(Keys.routeRouteTypeKey(routeMock));
    }

    // ============================================================================================
    // Test Functions
    // ============================================================================================

    // function testGetOpenInterest() view external {
            
    //     GMXV2Reader.OpenInterest memory _openInterest = _reader.getOpenInterest(_routeTypeKey, _trader);
        
    //     console.log("longOI, USD: ", _openInterest.longOI/1e30);
    //     console.log("shortOI, USD: ", _openInterest.shortOI/1e30);
    //     console.log("maxLongOI, USD: ", _openInterest.maxLongOI/1e30);
    //     console.log("maxShortOI, USD: ", _openInterest.maxShortOI/1e30);
    //     }
    
    // function testGetPosition0() view external {

    //    GMXV2Reader.PositionData memory _position = _reader.getPosition(_routeTypeKey, _trader);
       
    //    console.log("_position.sizeInUsd: ",_position.sizeInUsd/1e30);
    //    console.log("_position.sizeInTokens: ",_position.sizeInTokens);
    //    console.log("_position.collateralAmount: ",_position.collateralAmount);
    //    console.log("_position.market: ",_position.market);
    //    console.log("_position.collateralToken: ",_position.collateralToken);
    //    console.log("_position.isLong: ",_position.isLong);
    // }

    // function testGetMarketLiquidity() view external {
            
    //     (uint256 _longToken, uint256 _shortToken) = _reader.getAvailableLiquidity(_routeTypeKey, _trader);
        
    //     console.log("long: ", _longToken/1e30);
    //     console.log("short: ", _shortToken/1e30);
    // }

    // function testGeAccruedFees() view external {
        
    //     GMXV2Reader.FeesAccrued memory _fees = _reader.getAccruedFees(_routeTypeKey, _trader); 
        
    //     console.log("executionFeeDex: ", _fees.executionFeeDex);
    //     console.log("executionFeeAmplify: ", _fees.executionFeeAmplify);
    //     console.log("fundingFee: ", _fees.fundingFee);
    //     console.log("borrowFee: ", _fees.borrowFee);
    //     console.log("priceImpact: ", uint256(_fees.priceImpact));
    //     console.log("closeFee: ", _fees.closeFee);
    // }

    // function testGetFeesPerSecond() view external {
        
    //     GMXV2Reader.FeesRates memory _fees = _reader.getFeesPerSecond(market); 
        
    //     console.log("borrowingForLongs: ", _fees.borrowingForLongs);
    //     console.log("borrowingForShorts: ", _fees.borrowingForShorts);
    //     if (_fees.fundingForLongs > 0) {
    //     console.log("fundingForLongs (+): ", uint256(_fees.fundingForLongs));
    //     console.log("fundingForShorts (-): ", uint256(_fees.fundingForShorts));
    //     } else {
    //     console.log("fundingForLongs (-): ", uint256(_fees.fundingForLongs));
    //     console.log("fundingForShorts (+): ", uint256(_fees.fundingForShorts));
    //     }
    // }

    // // function testGetLiquidationPrice() view external {
        
    // //     int256 _liquidationPrice = _reader.getLiquidationPrice(_routeTypeKey, _trader); 
        
    // //     console.log("liquidationPrice: ", uint256(_liquidationPrice));
    // // }

    // //  function testGetMock() view external {
        
    // //     (int256 maxNegativePriceImpactUsd, int256 priceImpactDeltaUsd, uint256 minCollateralFactor) = _reader.getMinCollateralFactor(_routeTypeKey, _trader); 
        
    // //     console.log("maxNegativePriceImpactUsd: ", uint256(maxNegativePriceImpactUsd));
    // //     console.log("priceImpactDeltaUsd: ", uint256(priceImpactDeltaUsd));
    // //     console.log("minCollateralFactor: ", uint256(minCollateralFactor));
    // // }

    // function testGetPositionInfoFees() view external {
        
    //     GMXV2Reader.PositionInfo memory positonInfo = _reader._getPositionFeesInfo(_routeTypeKey, _trader); 
        
    //     console.log("executionPrice: ", uint256(positonInfo.executionPrice));
    //     console.log("fundingFeeAmount: ", uint256(positonInfo.fundingFeeAmount)); // correct amount: div 1e15 -> USD
    //     console.log("latestFundingFeeAmountPerSize: ", uint256(positonInfo.latestFundingFeeAmountPerSize));
    //     console.log("latestLongTokenClaimableFundingAmountPerSize: ", uint256(positonInfo.latestLongTokenClaimableFundingAmountPerSize));
    //     console.log("latestShortTokenClaimableFundingAmountPerSize: ", uint256(positonInfo.latestShortTokenClaimableFundingAmountPerSize));
    //     console.log("borrowingFeeUsd: ", uint256(positonInfo.borrowingFeeUsd)); // correct amount: div 1e34 -> USD

    //     // === ALTERNATIVE WAY TO GET FUNDING FEE ACCRUED ===

    //     uint256 fundingFeeAmountPerSize = _reader._getFundingFeePerSize(_routeTypeKey, _trader);
    //     uint256 latestFundingFeeAmountPerSize = positonInfo.latestFundingFeeAmountPerSize;
        
    //     GMXV2Reader.PositionData memory _position = _reader.getPosition(_routeTypeKey, _trader);
    //     uint256 size = _position.sizeInUsd;

    //     uint256 fundingDiffFactor = latestFundingFeeAmountPerSize - fundingFeeAmountPerSize;
    //     uint256 fundingFee = size * fundingDiffFactor / 1e30;
    //     console.log("FUNDING_FEE_USD_1E30: ", fundingFee); // correct amount: div 1e30 -> USD
    // }

    function testGetBestPuppets()  external {

        _subscribePuppets();
        
        address[] memory _puppets = new address[](4);
        _puppets[0] = puppetA;
        _puppets[1] = puppetB;
        _puppets[2] = puppetC;
        _puppets[3] = puppetD;
        // _puppets[4] = unsubscribedPuppet;

        address[] memory _bestPuppets = _reader.getBestPuppets(_puppets, routeMock, context.dataStore); 
        
        assertEq(_bestPuppets.length, 0, "testGetBestPuppets: E1");
        // assertEq(_bestPuppets[0], puppetD, "testGetBestPuppets: E2");
        // assertEq(_bestPuppets[1], puppetA, "testGetBestPuppets: E3");

        // console.log("_bestPuppets[0]: ", _bestPuppets[0]);
        // console.log("_bestPuppets[1]: ", _bestPuppets[1]);
        // console.log("_bestPuppets[2]: ", _bestPuppets[2]);
    }

    function _subscribePuppets() internal {

        _createPuppets();

        uint256 allowancePuppetA = _BASIS_POINTS_DIVISOR / 5; // 20%
        uint256 allowancePuppetB = _BASIS_POINTS_DIVISOR / 20; // 5%
        uint256 allowancePuppetC = _BASIS_POINTS_DIVISOR / 10; // 10%
        uint256 allowancePuppetD = _BASIS_POINTS_DIVISOR / 2; // 50%
        
        uint256 _expiry = block.timestamp + 24 hours;

        _subscribe.subscribe(context, puppetA, true, allowancePuppetA, _expiry, context.users.trader, routeTypeKeyMock);
        _subscribe.subscribe(context, puppetB, true, allowancePuppetB, _expiry, context.users.trader, routeTypeKeyMock);
        _subscribe.subscribe(context, puppetC, true, allowancePuppetC, _expiry, context.users.trader, routeTypeKeyMock);
        _subscribe.subscribe(context, puppetD, true, allowancePuppetD, _expiry, context.users.trader, routeTypeKeyMock);

        _deposit.depositEntireWNTBalance(context, puppetA, true);
        _deposit.depositEntireWNTBalance(context, puppetB, true);
        _deposit.depositEntireWNTBalance(context, puppetC, true);
        _deposit.depositEntireWNTBalance(context, puppetD, true);
        
        assertEq(CommonHelper.puppetAllowancePercentage(context.dataStore, puppetA, routeMock),  allowancePuppetA, "_subscribePuppets: E0");
        assertEq(CommonHelper.puppetAllowancePercentage(context.dataStore, puppetB, routeMock),  allowancePuppetB, "_subscribePuppets: E1");
        assertEq(CommonHelper.puppetAllowancePercentage(context.dataStore, puppetC, routeMock),  allowancePuppetC, "_subscribePuppets: E2");
        assertEq(CommonHelper.puppetAllowancePercentage(context.dataStore, puppetD, routeMock),  allowancePuppetD, "_subscribePuppets: E3");
    }

    function _createPuppets() internal {
        puppetA = _createUser("Puppet A"); //makeAddr("puppetA");
        puppetB = _createUser("Puppet B"); //makeAddr("puppetB");
        puppetC = _createUser("Puppet C"); //makeAddr("puppetC");
        puppetD = _createUser("Puppet D"); //makeAddr("puppetD");
        unsubscribedPuppet = _createUser("Unsubscribed Puppet"); //makeAddr("unsubscribedPuppet");
    }
}