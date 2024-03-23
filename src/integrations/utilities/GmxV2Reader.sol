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
// ========================== Governor ==========================
// ==============================================================
// Amplify Protocol: https://github.com/AmplifyProtocol

// ==============================================================

import {GMXV2Keys} from "src/integrations/GMXV2/libraries/GMXV2Keys.sol";
import {GMXV2OrchestratorHelper} from "src/integrations/GMXV2/libraries/GMXV2OrchestratorHelper.sol";
import {IGMXV2Reader, Market, Price, MarketPoolValueInfo, Position, MarketUtils, ReaderUtils, GmxKeys, ReaderPricingUtils} from "src/integrations/utilities/interfaces/IGmxV2Reader.sol";

import {DataStore} from "src/integrations/utilities/DataStore.sol";
import "./BaseReader.sol";


contract GMXV2Reader is BaseReader {

    IGMXV2Reader constant reader = IGMXV2Reader(0xf60becbba223EEA9495Da3f606753867eC10d139);
    IDataStore constant _gmxDataStore = IDataStore(0xFD70de6b91282D8017aA4E741e9Ae325CAb992d8);
    DataStore gmxDataStore = DataStore(0xFD70de6b91282D8017aA4E741e9Ae325CAb992d8);

    // ============================================================================================
    // View Functions
    // ============================================================================================

    function getAvailableLiquidity(bytes32 _routeTypeKey, address _trader) override public view returns (uint256, uint256) {
        (,address market) =  _getMarket(_routeTypeKey, _trader);

        Market.Props memory marketProps = reader.getMarket(gmxDataStore, market);

        uint256 _longTokenAmount = _gmxDataStore.getUint(GmxKeys.poolAmountKey(market, marketProps.longToken));
        uint256 _shortTokenAmount = _gmxDataStore.getUint(GmxKeys.poolAmountKey(market, marketProps.shortToken));

        uint256 _longTokenPrice = getPrice(marketProps.longToken);
        uint256 _shortTokenPrice = getPrice(marketProps.shortToken);

        uint256 _longTokenUsd = _longTokenAmount * _longTokenPrice / (10 ** IERC20Metadata(marketProps.longToken).decimals());
        uint256 _shortTokenUsd = _shortTokenAmount * _shortTokenPrice/ (10 ** IERC20Metadata(marketProps.shortToken).decimals());

        return (_longTokenUsd, _shortTokenUsd);
    }
    
    function getOpenInterest(bytes32 _routeTypeKey, address _trader) override public view returns (OpenInterest memory _openInterest) {
        (,address market) =  _getMarket(_routeTypeKey, _trader);

        Market.Props memory marketProps = reader.getMarket(gmxDataStore, market);

        uint256 _shortTokenLongOI = _gmxDataStore.getUint(GmxKeys.openInterestKey(market, marketProps.shortToken, true));
        uint256 _shortTokenShortOI = _gmxDataStore.getUint(GmxKeys.openInterestKey(market, marketProps.shortToken, false));
        uint256 _longTokenLongOI = _gmxDataStore.getUint(GmxKeys.openInterestKey(market, marketProps.longToken, true));
        uint256 _longTokenShortOI = _gmxDataStore.getUint(GmxKeys.openInterestKey(market, marketProps.longToken, false));
        uint256 _maxOpenInterestLong = _gmxDataStore.getUint(GmxKeys.maxOpenInterestKey(market, true));
        uint256 _maxOpenInterestShort = _gmxDataStore.getUint(GmxKeys.maxOpenInterestKey(market, false));

        _openInterest = OpenInterest({
            longOI: _shortTokenLongOI+_longTokenLongOI,
            shortOI: _shortTokenShortOI+_longTokenShortOI,
            maxLongOI: _maxOpenInterestLong,
            maxShortOI: _maxOpenInterestShort
         });
    }

    function getOpenInterest(address market) public view returns (OpenInterest memory _openInterest) {

        Market.Props memory marketProps = reader.getMarket(gmxDataStore, market);

        uint256 _shortTokenLongOI = _gmxDataStore.getUint(GmxKeys.openInterestKey(market, marketProps.shortToken, true));
        uint256 _shortTokenShortOI = _gmxDataStore.getUint(GmxKeys.openInterestKey(market, marketProps.shortToken, false));
        uint256 _longTokenLongOI = _gmxDataStore.getUint(GmxKeys.openInterestKey(market, marketProps.longToken, true));
        uint256 _longTokenShortOI = _gmxDataStore.getUint(GmxKeys.openInterestKey(market, marketProps.longToken, false));
        uint256 _maxOpenInterestLong = _gmxDataStore.getUint(GmxKeys.maxOpenInterestKey(market, true));
        uint256 _maxOpenInterestShort = _gmxDataStore.getUint(GmxKeys.maxOpenInterestKey(market, false));

        _openInterest = OpenInterest({
            longOI: _shortTokenLongOI+_longTokenLongOI,
            shortOI: _shortTokenShortOI+_longTokenShortOI,
            maxLongOI: _maxOpenInterestLong,
            maxShortOI: _maxOpenInterestShort
         });
    }

    function getPrice(address _token) override public view returns (uint256 _price) {
        return GMXV2OrchestratorHelper.getPrice(amplifyDataStore, _token);
    }

    function getAccruedFees(bytes32 _routeTypeKey, address _trader) override public view returns (FeesAccrued memory _fees) {
        _fees = FeesAccrued({
            executionFeeDex: CommonHelper.minExecutionFee(amplifyDataStore),
            executionFeeAmplify: CommonHelper.minPuppetExecutionFee(amplifyDataStore),
            fundingFee: _getFundingFee(_routeTypeKey, _trader),
            borrowFee: _getAccruedBorrowingFee(_routeTypeKey, _trader),
            priceImpact: _getPriceImpact(_routeTypeKey, _trader),
            closeFee: 0 // To be added
         });
    }

    function getFeesPerSecond(address market) override public view returns (FeesRates memory _fees) {
        (uint256 _borrowingForLongs, uint256 _borrowingForShorts) = this.getBorrowingFeesPerSecond(market);
        (, int256 _fundingForLongs, int256 _fundingForShorts) = this.getFundingFeesPerSecond(market);

        _fees = FeesRates({
            borrowingForLongs: _borrowingForLongs,  // Factor Per Second //%-> /1e24 *100 
            borrowingForShorts: _borrowingForShorts, // Factor Per Second
            fundingForLongs: _fundingForLongs,
            fundingForShorts: _fundingForShorts // %-> /1e30 *100
         });
    }

    function getPosition(bytes32 _routeTypeKey, address _trader) override public view returns (PositionData memory _position){
        (address _route,) =  _getMarket(_routeTypeKey, _trader);
        bytes32 _key = GMXV2OrchestratorHelper.positionKey(amplifyDataStore, _route);
        Position.Props memory positionProps = reader.getPosition(
            gmxDataStore,
            _key
        );
         _position = PositionData({
            sizeInUsd: positionProps.numbers.sizeInUsd,
            sizeInTokens: positionProps.numbers.sizeInTokens,
            collateralAmount: positionProps.numbers.collateralAmount,
            market: positionProps.addresses.market,
            collateralToken: positionProps.addresses.collateralToken,
            isLong: positionProps.flags.isLong
         });
    }

    function getBorrowingFeesPerSecond(address market) external view returns (uint256 borrowingFactorPerSecondForLongs, uint256 borrowingFactorPerSecondForShorts) {

        Market.Props memory marketProps = reader.getMarket(gmxDataStore, market);

        uint256 indexTokenPrice = getPrice(marketProps.indexToken);
        uint256 longTokenPrice = getPrice(marketProps.longToken);
        uint256 shortTokenPrice = getPrice(marketProps.shortToken);

        Price.Props memory indexTokenPriceProps = Price.Props({min: indexTokenPrice, max: indexTokenPrice});
        Price.Props memory longTokenPriceProps = Price.Props({min: longTokenPrice, max: longTokenPrice});
        Price.Props memory shortTokenPriceProps = Price.Props({min: shortTokenPrice,max: shortTokenPrice});

        MarketUtils.MarketPrices memory prices = MarketUtils.MarketPrices({
            indexTokenPrice: indexTokenPriceProps,
            longTokenPrice: longTokenPriceProps,
            shortTokenPrice: shortTokenPriceProps
            });

        ReaderUtils.MarketInfo memory marketInfo= reader.getMarketInfo(
            gmxDataStore,
            prices,
            market
        );
        return (marketInfo.borrowingFactorPerSecondForLongs, marketInfo.borrowingFactorPerSecondForShorts);
    }

    // function getFundingFeesPerSecond(address market) external view returns (bool longsPayShorts, int256 longFunding, int256 shortFunding ,uint256 ratio) {

    //     OpenInterest memory _interest = getOpenInterest(market);
    //     uint256 longInterestUsd = _interest.longOI;
    //     uint256 shortInterestUsd = _interest.shortOI;

    //     int256 fundingFactor = _gmxDataStore.getInt(GmxKeys.savedFundingFactorPerSecondKey(market));
        
    //     longsPayShorts = fundingFactor > 0;
    //     int256 factorPerSecondA = -(fundingFactor);
    //     ratio = shortInterestUsd < longInterestUsd ? ((shortInterestUsd * 1e30 / longInterestUsd)) : ((longInterestUsd * 1e30 / shortInterestUsd));
    //     int256 factorPerSecondB = (int256(ratio) * fundingFactor / 1e30);
    //     if (longsPayShorts) {
    //         longFunding = factorPerSecondA;
    //         shortFunding = factorPerSecondB;
    //     } else {
    //         longFunding = factorPerSecondB;
    //         shortFunding = factorPerSecondA;
    //     }
    // }

    function getFundingFeesPerSecond(address market) external view returns (bool longsPayShorts, int256 longFunding, int256 shortFunding) {

        OpenInterest memory _interest = getOpenInterest(market);
        uint256 longInterestUsd = _interest.longOI;
        uint256 shortInterestUsd = _interest.shortOI;

        int256 fundingFactor = _gmxDataStore.getInt(GmxKeys.savedFundingFactorPerSecondKey(market));
        
        longsPayShorts = fundingFactor > 0;
        // (uint256 ratio0, uint256 ratio1) = shortInterestUsd < longInterestUsd ? ((shortInterestUsd * 1e30 / longInterestUsd), (longInterestUsd * 1e30 / shortInterestUsd)) : ((longInterestUsd * 1e30 / shortInterestUsd), (shortInterestUsd * 1e30 / longInterestUsd));
        uint256 ratio = shortInterestUsd < longInterestUsd ? ((shortInterestUsd * 1e30 / longInterestUsd)) : ((longInterestUsd * 1e30 / shortInterestUsd));
        int256 factorPerSecondB = (int256(ratio) * fundingFactor / 1e30);
        int256 factorPerSecondA = (int256(1e60 / ratio) * fundingFactor / 1e30);
        longFunding = longsPayShorts ? (-1) * factorPerSecondA : factorPerSecondB;
        shortFunding = longsPayShorts ? factorPerSecondB : (-1) * factorPerSecondA;
    }
    
    function getLiquidationPrice(bytes32 _routeTypeKey, address _trader) public view returns (int256 _liquidationPrice) {

        PositionData memory _position = getPosition(_routeTypeKey, _trader);
        FeesAccrued memory _fees = getAccruedFees(_routeTypeKey, _trader);
        Market.Props memory _marketProps = reader.getMarket(gmxDataStore, _position.market);

        uint256 totalPendingFeesUsd = _fees.fundingFee + _fees.borrowFee + _fees.closeFee;

        int256 maxNegativePriceImpactUsd = (-1) * int256(_position.sizeInUsd * _gmxDataStore.getUint(GmxKeys.maxPositionImpactFactorForLiquidationsKey(_position.market)));

        int256 priceImpactDeltaUsd = _getPriceImpactDeltaUsd(_fees.priceImpact, maxNegativePriceImpactUsd, true);

        uint256 minCollateralFactor = _gmxDataStore.getUint(GmxKeys.minCollateralFactorKey(_position.market)); // This determines the minimum allowed ratio of (position collateral) / (position size)
        int256 liquidationCollateralUsd = int256(_position.sizeInUsd * minCollateralFactor);

        int256 indexTokenDenominator = 1e18 ; //TODO: retrieve index token denominator

        if (_position.collateralToken == _marketProps.indexToken) {
            if (_position.isLong) {
                uint256 denominator = _position.sizeInTokens + _position.collateralAmount;
                if (denominator == 0) return 0;

                _liquidationPrice = (int256(_position.sizeInUsd) + liquidationCollateralUsd - priceImpactDeltaUsd + int256(totalPendingFeesUsd)) / int256(denominator) * indexTokenDenominator;
            } else {
                uint256 denominator = _position.sizeInTokens - _position.collateralAmount;
                if (denominator == 0) return 0;

                _liquidationPrice = (int256(_position.sizeInUsd) - liquidationCollateralUsd + priceImpactDeltaUsd - int256(totalPendingFeesUsd)) / int256(denominator) * indexTokenDenominator;
            }
        } else {
            if (_position.sizeInTokens == 0) return 0;
            int256 remainingCollateralUsd = int256(_position.collateralAmount) + priceImpactDeltaUsd - int256(totalPendingFeesUsd) - int256(_fees.closeFee);

            if (_position.isLong) {
                _liquidationPrice = ((liquidationCollateralUsd - remainingCollateralUsd + int256(_position.sizeInUsd)) * indexTokenDenominator) / int256(_position.sizeInTokens);
            } else {
                _liquidationPrice = ((liquidationCollateralUsd - remainingCollateralUsd - int256(_position.sizeInUsd)) * indexTokenDenominator) / (-1 * int256(_position.sizeInTokens));
            }
        }

        if (_liquidationPrice <= 0) return 0;

        return _liquidationPrice;
    }

    // ============================================================================================
    // Internal View Functions
    // ============================================================================================

    function _getMarket(bytes32 _routeTypeKey, address _trader) internal view returns (address _route, address _market) {
        bytes32 _routeKey = CommonHelper.routeKey(amplifyDataStore, _trader, _routeTypeKey);
        _route = CommonHelper.routeAddress(amplifyDataStore, _routeKey);
        return (_route, GMXV2OrchestratorHelper.gmxMarketToken(amplifyDataStore, _route));
    }

    function _getFundingFee(bytes32 _routeTypeKey, address _trader) internal view returns (uint256) {
        (address _route,) =  _getMarket(_routeTypeKey, _trader);
        bytes32 _key = GMXV2OrchestratorHelper.positionKey(amplifyDataStore, _route);
        Position.Props memory positionProps = reader.getPosition(gmxDataStore,_key);
        return positionProps.numbers.fundingFeeAmountPerSize;
    }

    function _getBorrowingFeePoolFactor(bytes32 _routeTypeKey, address _trader) internal view returns (uint256 _borrowingFeePoolFactor) {
        (,address market) =  _getMarket(_routeTypeKey, _trader);

         Market.Props memory marketProps = reader.getMarket(gmxDataStore, market);

        uint256 indexTokenPrice = getPrice(marketProps.indexToken);
        uint256 longTokenPrice = getPrice(marketProps.longToken);
        uint256 shortTokenPrice = getPrice(marketProps.shortToken);

        Price.Props memory indexTokenPriceProps = Price.Props({min: indexTokenPrice, max: indexTokenPrice});
        Price.Props memory longTokenPriceProps = Price.Props({min: longTokenPrice, max: longTokenPrice});
        Price.Props memory shortTokenPriceProps = Price.Props({min: shortTokenPrice,max: shortTokenPrice});

        (,MarketPoolValueInfo.Props memory marketValueProp) = reader.getMarketTokenPrice(
            gmxDataStore,
            marketProps,
            indexTokenPriceProps,
            longTokenPriceProps,
            shortTokenPriceProps,
            keccak256(abi.encode("MAX_PNL_FACTOR")),
            true
        );
        return marketValueProp.borrowingFeePoolFactor;
    }

    function _getAccruedBorrowingFee(bytes32 _routeTypeKey, address _trader) internal view returns (uint256 _borrowingFees) {
        (address _route,) =  _getMarket(_routeTypeKey, _trader);
        bytes32 _key = GMXV2OrchestratorHelper.positionKey(amplifyDataStore, _route);
        Position.Props memory positionProps = reader.getPosition(
            gmxDataStore,
            _key
        );
        // Calculate the difference between the pool borrowing factor and the position borrowing factor
        uint256 _borrowingFactorDifference = _getBorrowingFeePoolFactor(_routeTypeKey,_trader) - positionProps.numbers.borrowingFactor;
        
        return (positionProps.numbers.sizeInUsd * _borrowingFactorDifference) / 1e30 /100 ; //100 - fraction to % coeficient convertion
    }

    function _getPriceImpact(bytes32 _routeTypeKey, address _trader) internal view returns (int256) { 
        PositionData memory _position = getPosition(_routeTypeKey, _trader);

        Market.Props memory marketProps = reader.getMarket(gmxDataStore, _position.market);
        uint256 indexTokenPrice = getPrice(marketProps.indexToken);
        Price.Props memory indexTokenPriceProps = Price.Props({min: indexTokenPrice, max: indexTokenPrice});

        ReaderPricingUtils.ExecutionPriceResult memory _executionPrice = reader.getExecutionPrice(
            gmxDataStore, 
            _position.market, 
            indexTokenPriceProps, 
            _position.sizeInUsd, 
            _position.sizeInTokens,  
            int256(_position.sizeInUsd) * (-1), //position size delta
            _position.isLong
            );

        return _executionPrice.priceImpactUsd;
    }

    function _getPriceImpactDeltaUsd(int256 priceImpact, int256 maxNegativePriceImpactUsd, bool useMaxPriceImpact) internal pure returns(int256 priceImpactDeltaUsd){
        
        if (useMaxPriceImpact) {
            priceImpactDeltaUsd = maxNegativePriceImpactUsd;
        } else {
            priceImpactDeltaUsd = priceImpact;

            if (priceImpactDeltaUsd < maxNegativePriceImpactUsd) {priceImpactDeltaUsd = maxNegativePriceImpactUsd;}
            // Ignore positive price impact
            if (priceImpactDeltaUsd > 0) {priceImpactDeltaUsd = 0;}
        }
        return priceImpactDeltaUsd;
    }
}