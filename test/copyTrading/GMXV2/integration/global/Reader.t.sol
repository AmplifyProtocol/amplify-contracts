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
    
    bytes32 _routeTypeKey = 0xc1513a1f97dd396583308cbc6b016ae90eb062eb1e28f06e00aa8494e629b8f9;
    address _trader = 0x5d2473EB50365C98B4fFc7064B241b77C8c9bB63;
    address market = 0x70d95587d40A2caf56bd97485aB3Eec10Bee6336;

    function setUp() public override {
        BaseGMXV2.setUp();

        _reader = new GMXV2Reader();
    }

    // ============================================================================================
    // Test Functions
    // ============================================================================================

    function testGetOpenInterest() view external {
            
        GMXV2Reader.OpenInterest memory _openInterest = _reader.getOpenInterest(_routeTypeKey, _trader);
        
        console.log("longOI, USD: ", _openInterest.longOI/1e30);
        console.log("shortOI, USD: ", _openInterest.shortOI/1e30);
        console.log("maxLongOI, USD: ", _openInterest.maxLongOI/1e30);
        console.log("maxShortOI, USD: ", _openInterest.maxShortOI/1e30);
        }
    
    function testGetPosition() view external {
       GMXV2Reader.PositionData memory _position = _reader.getPosition(_routeTypeKey, _trader);
       
       console.log("_position.sizeInUsd: ",_position.sizeInUsd/1e30);
       console.log("_position.sizeInTokens: ",_position.sizeInTokens);
       console.log("_position.collateralAmount: ",_position.collateralAmount);
       console.log("_position.market: ",_position.market);
       console.log("_position.collateralToken: ",_position.collateralToken);
       console.log("_position.isLong: ",_position.isLong);
    }

    function testGetMarketLiquidity() view external {
            
        (uint256 _longToken, uint256 _shortToken) = _reader.getAvailableLiquidity(_routeTypeKey, _trader);
        
        console.log("long: ", _longToken/1e30);
        console.log("short: ", _shortToken/1e30);
    }

    function testGeAccruedFees() view external {
        
        GMXV2Reader.FeesAccrued memory _fees = _reader.getAccruedFees(_routeTypeKey, _trader); 
        
        console.log("executionFeeDex: ", _fees.executionFeeDex);
        console.log("executionFeeAmplify: ", _fees.executionFeeAmplify);
        console.log("fundingFee: ", _fees.fundingFee);
        console.log("borrowFee: ", _fees.borrowFee);
        console.log("priceImpact: ", uint256(_fees.priceImpact));
        console.log("closeFee: ", _fees.closeFee);
    }

    function testGetFeesPerSecond() view external {
        
        GMXV2Reader.FeesRates memory _fees = _reader.getFeesPerSecond(market); 
        
        console.log("borrowingForLongs: ", _fees.borrowingForLongs);
        console.log("borrowingForShorts: ", _fees.borrowingForShorts);
        if (_fees.fundingForLongs > 0) {
        console.log("fundingForLongs (+): ", uint256(_fees.fundingForLongs));
        console.log("fundingForShorts (-): ", uint256(_fees.fundingForShorts));
        } else {
        console.log("fundingForLongs (-): ", uint256(_fees.fundingForLongs));
        console.log("fundingForShorts (+): ", uint256(_fees.fundingForShorts));
        }
    }

    function testGetLiquidationPrice() view external {
        
        int256 _liquidationPrice = _reader.getLiquidationPrice(_routeTypeKey, _trader); 
        
        console.log("liquidationPrice: ", uint256(_liquidationPrice));
    }
}       