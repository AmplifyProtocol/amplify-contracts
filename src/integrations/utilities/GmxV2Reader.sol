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

import {GMXV2Keys} from "../../../../../src/integrations/GMXV2/libraries/GMXV2Keys.sol";
import {GMXV2OrchestratorHelper} from "src/integrations/GMXV2/libraries/GMXV2OrchestratorHelper.sol";
import {IGMXV2Reader, Market, Price, MarketPoolValueInfo, Position, MarketUtils, ReaderUtils, GmxKeys} from "src/integrations/utilities/interfaces/IGmxV2Reader.sol";
import {DataStore} from "src/integrations/utilities/DataStore.sol";
import "./BaseReader.sol";


contract GMXV2Reader is BaseReader {

    IGMXV2Reader constant reader = IGMXV2Reader(0xf60becbba223EEA9495Da3f606753867eC10d139);
    IDataStore constant _gmxDataStore = IDataStore(0xFD70de6b91282D8017aA4E741e9Ae325CAb992d8);
    DataStore gmxDataStore = DataStore(0xFD70de6b91282D8017aA4E741e9Ae325CAb992d8);

    // ============================================================================================
    // View Functions
    // ============================================================================================

    function getAvailableLiquidity(bytes32 _routeTypeKey, address _trader) override public view returns (uint256 _longTokenUsd, uint256 _shortTokenUsd) {
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
        return (marketValueProp.longTokenUsd, marketValueProp.shortTokenUsd);
    }

    function getOpenInterest(bytes32 _routeTypeKey, address _trader) override public view returns (uint256 _longIO, uint256 _shortIO) {
        (,address market) =  _getMarket(_routeTypeKey, _trader);

        Market.Props memory marketProps = reader.getMarket(gmxDataStore, market);

        uint256 indexTokenPrice = getPrice(marketProps.indexToken);

        Price.Props memory indexTokenPriceProps = Price.Props({min: indexTokenPrice, max: indexTokenPrice});

        (int256 _long) = reader.getOpenInterestWithPnl(
            gmxDataStore,
            marketProps,
            indexTokenPriceProps,
            true,
            true
        );

        (int256 _short) = reader.getOpenInterestWithPnl(
            gmxDataStore,
            marketProps,
            indexTokenPriceProps,
            false,
            true
        );
        return (uint256(_long), uint256(_short));
    }

    function getPrice(address _token) override public view returns (uint256 _price) {
        return GMXV2OrchestratorHelper.getPrice(amplifyDataStore, _token);
    }

    function getAccruedFees(bytes32 _routeTypeKey, address _trader) override public view returns (PositionFeesAccrued memory _fees) {
        _fees = PositionFeesAccrued({
            executionFee: 0, // To be added
            fundingFee: _getFundingFee(_routeTypeKey, _trader),
            borrowFee: _getAccruedBorrowingFee(_routeTypeKey, _trader),
            priceImpact: 0 // To be added
         });
    }

    function getFeesPerSecond(address market) override public view returns (FeesRates memory _fees) {
        (uint256 _borrowingForLongs, uint256 _borrowingForShorts) = this.getBorrowingFeesPerSecond(market);
        (, int256 _fundingForLongs, int256 _fundingForShorts) = this.getFundingFeesPerSecond(market);

        _fees = FeesRates({
            borrowingForLongs: _borrowingForLongs, 
            borrowingForShorts: _borrowingForShorts,
            fundingForLongs: uint256(_fundingForLongs),
            fundingForShorts: uint256(_fundingForShorts)
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

    function getFundingFeesPerSecond(address market) external view returns (bool longsPayShorts, int256 longFunding, int256 shortFunding) {

        OpenInterest memory _interest = _getOpenInterestMarket(market);
        uint256 longInterestUsd = _interest.openInterestLong;
        uint256 shortInterestUsd = _interest.openInterestShort;

        int256 fundingFactor = _gmxDataStore.getInt(GmxKeys.savedFundingFactorPerSecondKey(market));
        
        longsPayShorts = fundingFactor > 0;
        int256 factorPerSecondA = -fundingFactor;
        uint256 ratio = shortInterestUsd < longInterestUsd ? (shortInterestUsd * 1e30 / longInterestUsd) : (longInterestUsd * 1e30 / shortInterestUsd);
        int256 factorPerSecondB = (int256(ratio) * fundingFactor / int256(1e30));
        if (longsPayShorts) {
            longFunding = factorPerSecondA / 1e20;
            shortFunding = factorPerSecondB / 1e20;
        } else {
            longFunding = factorPerSecondB / 1e20;
            shortFunding = factorPerSecondA / 1e20;
        }
    }

    function getLiquidationPrice(bytes32 _routeTypeKey, uint256 acceptablePrice, uint256 triggerPrice) override public view returns (uint256 _liquidationPrice) {}

    // ============================================================================================
    // Internal View Functions
    // ============================================================================================

    function _getMarket(bytes32 _routeTypeKey, address _trader) internal view returns (address _route, address _market) {
        address _collateralToken = gmxDataStore.getAddress(Keys.routeTypeCollateralTokenKey(_routeTypeKey));
        address _indexToken = gmxDataStore.getAddress(Keys.routeTypeIndexTokenKey(_routeTypeKey));
        bool _isLong = gmxDataStore.getBool(Keys.routeTypeIsLongKey(_routeTypeKey));
        bytes32 _routeKey = keccak256(abi.encode(_trader, _collateralToken, _indexToken, _isLong));
        _route = gmxDataStore.getAddress(Keys.routeAddressKey(_routeKey));
        return (_route, GMXV2OrchestratorHelper.gmxMarketToken(amplifyDataStore, _route));
    }

    function _getFundingFee(bytes32 _routeTypeKey, address _trader) internal view returns (uint256) {
        (address _route,) =  _getMarket(_routeTypeKey, _trader);
        bytes32 _key = GMXV2OrchestratorHelper.positionKey(amplifyDataStore, _route);
        Position.Props memory positionProps = reader.getPosition(
            gmxDataStore,
            _key
        );
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
        
        return (positionProps.numbers.sizeInUsd * _borrowingFactorDifference);
    }

    function _getOpenInterestMarket(address market) internal view returns (OpenInterest memory _interest) {
        Market.Props memory marketProps = reader.getMarket(gmxDataStore, market);
        
        uint256 longInterestUsingLongToken = _gmxDataStore.getUint(GmxKeys.openInterestKey(market, marketProps.longToken, true));
        uint256 longInterestUsingShortToken = _gmxDataStore.getUint(GmxKeys.openInterestKey(market, marketProps.shortToken, true));
        uint256 shortInterestUsingLongToken = _gmxDataStore.getUint(GmxKeys.openInterestKey(market, marketProps.longToken, false));
        uint256 shortInterestUsingShortToken = _gmxDataStore.getUint(GmxKeys.openInterestKey(market, marketProps.shortToken, false));
        
        _interest = OpenInterest({
            openInterestLong:longInterestUsingLongToken + longInterestUsingShortToken,
            openInterestShort: shortInterestUsingLongToken + shortInterestUsingShortToken,
            maxOpenInterestLong: _gmxDataStore.getUint(GmxKeys.maxOpenInterestKey(market, true)),
            maxOpenInterestShort: _gmxDataStore.getUint(GmxKeys.maxOpenInterestKey(market, false)),
            openInterestReserveLong: _gmxDataStore.getUint(GmxKeys.openInterestReserveFactorKey(market, true)),
            openInterestReserveShort: _gmxDataStore.getUint(GmxKeys.openInterestReserveFactorKey(market, false))
        });
    }

    //@note work in progress
    function getLiquidationPrice(
        IMarketInfo memory marketInfo,
        bool isLong,
        address collateralToken,
        address indexToken,
        uint256 sizeInTokens,
        uint256 sizeInUsd,
        uint256 collateralAmount,
        uint256 collateralUsd,
        uint256 pendingFundingFeesUsd,
        uint256 pendingBorrowingFeesUsd,
        bool useMaxPriceImpact
    ) external view returns (uint256 liquidationPrice) {

        // TODO: how to retrieve closingFeeUsd ?
        uint256 totalPendingFeesUsd = pendingFundingFeesUsd + pendingBorrowingFeesUsd + closingFeeUsd;

        uint256 maxPositionImpactFactorForLiquidations = _gmxDataStore.getUint(GmxKeys.maxPositionImpactFactorForLiquidationsKey(market));
        uint256 maxNegativePriceImpactUsd = (sizeInUsd * maxPositionImpactFactorForLiquidations) / PRECISION;

        if (useMaxPriceImpact) {
            uint256 priceImpactDeltaUsd = maxNegativePriceImpactUsd;
        } else {
            uint256 priceImpactDeltaUsd = getPriceImpactForPosition(marketInfo, sizeInUsd.mul(-1), isLong); //figure out how getPriceImpactForPosition works

            if (priceImpactDeltaUsd < maxNegativePriceImpactUsd) {priceImpactDeltaUsd = maxNegativePriceImpactUsd;}
            // Ignore positive price impact
            if (priceImpactDeltaUsd > 0) {priceImpactDeltaUsd = 0;}
        }

        uint256 minCollateralFactor = _gmxDataStore.getUint(GmxKeys.minCollateralFactorKey(market));
        uint256 liquidationCollateralUsd = sizeInUsd * minCollateralFactor/ PRECISION;

        uint256 indexTokenDenominator ; //TODO: retrieve index token denominator

        if (collateralToken == indexToken) {
            if (isLong) {
                uint256 denominator = sizeInTokens + collateralAmount;
                if (denominator == 0) return 0;

                liquidationPrice = ((sizeInUsd + liquidationCollateralUsd - priceImpactDeltaUsd + totalFeesUsd) * indexTokenDenominator) / denominator;
            } else {
                uint256 denominator = sizeInTokens - collateralAmount;
                if (denominator == 0) return 0;

                liquidationPrice = ((sizeInUsd - liquidationCollateralUsd + priceImpactDeltaUsd - totalFeesUsd) * indexTokenDenominator) / denominator;
            }
        } else {
            if (sizeInTokens == 0) return 0;
            uint256 remainingCollateralUsd = collateralUsd + priceImpactDeltaUsd - totalPendingFeesUsd - closingFeeUsd;

            if (isLong) {
                liquidationPrice = ((liquidationCollateralUsd - remainingCollateralUsd + sizeInUsd) * indexTokenDenominator) / sizeInTokens;
            } else {
                liquidationPrice = ((liquidationCollateralUsd - remainingCollateralUsd - sizeInUsd) * indexTokenDenominator) / sizeInTokens;
            }
        }

        if (liquidationPrice <= 0) return 0;

        return liquidationPrice;
    }
}


// export function getBorrowingFactorPerPeriod(marketInfo: MarketInfo, isLong: boolean, periodInSeconds: number) {
//   const factorPerSecond = isLong
//     ? marketInfo.borrowingFactorPerSecondForLongs
//     : marketInfo.borrowingFactorPerSecondForShorts;

//   return factorPerSecond.mul(periodInSeconds || 1);
// }

// export function getBorrowingFeeRateUsd(
//   marketInfo: MarketInfo,
//   isLong: boolean,
//   sizeInUsd: BigNumber,
//   periodInSeconds: number
// ) {
//   const factor = getBorrowingFactorPerPeriod(marketInfo, isLong, periodInSeconds);

//   return applyFactor(sizeInUsd, factor);

//=========
// export function getFundingFactorPerPeriod(marketInfo: MarketInfo, isLong: boolean, periodInSeconds: number) {
//   const { fundingFactorPerSecond, longsPayShorts, longInterestUsd, shortInterestUsd } = marketInfo;

//   const isLargerSide = isLong ? longsPayShorts : !longsPayShorts;

//   let factorPerSecond;

//   if (isLargerSide) {
//     factorPerSecond = fundingFactorPerSecond.mul(-1);
//   } else {
//     const largerInterestUsd = longsPayShorts ? longInterestUsd : shortInterestUsd;
//     const smallerInterestUsd = longsPayShorts ? shortInterestUsd : longInterestUsd;

//     const ratio = smallerInterestUsd.gt(0)
//       ? largerInterestUsd.mul(PRECISION).div(smallerInterestUsd)
//       : BigNumber.from(0);

//     factorPerSecond = applyFactor(ratio, fundingFactorPerSecond);
//   }

//   return factorPerSecond.mul(periodInSeconds);
// }

// export function getFundingFeeRateUsd(
//   marketInfo: MarketInfo,
//   isLong: boolean,
//   sizeInUsd: BigNumber,
//   periodInSeconds: number
// ) {
//   const factor = getFundingFactorPerPeriod(marketInfo, isLong, periodInSeconds);

//   return applyFactor(sizeInUsd, factor);
// }

// ==== lIQUIDATION PRICE CALC ======

// export function getLiquidationPrice(
//   marketInfo: IMarketInfo,
//   isLong: boolean,
//   collateralToken: viem.Address,
//   indexToken: viem.Address,

//   sizeInTokens: bigint,
//   sizeInUsd: bigint,

//   collateralAmount: bigint,
//   collateralUsd: bigint,
  
//   pendingFundingFeesUsd = 0n,
//   pendingBorrowingFeesUsd = 0n,
//   // minCollateralUsd: bigint,
//   useMaxPriceImpact = true,
// ) {
//   if (sizeInUsd <= 0n) return 0n

//   const closingFeeUsd = getMarginFee(marketInfo, false, sizeInUsd)
//   const totalPendingFeesUsd = pendingFundingFeesUsd + pendingBorrowingFeesUsd
//   const totalFeesUsd = totalPendingFeesUsd + closingFeeUsd

//   const maxNegativePriceImpactUsd = -applyFactor(sizeInUsd, marketInfo.config.maxPositionImpactFactorForLiquidations)

//   let priceImpactDeltaUsd = 0n

//   if (useMaxPriceImpact) {
//     priceImpactDeltaUsd = maxNegativePriceImpactUsd
//   } else {
//     priceImpactDeltaUsd = getPriceImpactForPosition(marketInfo, -sizeInUsd, isLong)

//     if (priceImpactDeltaUsd < maxNegativePriceImpactUsd) {
//       priceImpactDeltaUsd = maxNegativePriceImpactUsd
//     }

//     // Ignore positive price impact
//     if (priceImpactDeltaUsd > 0n) {
//       priceImpactDeltaUsd = 0n
//     }
//   }

//   const liquidationCollateralUsd = applyFactor(sizeInUsd, marketInfo.config.minCollateralFactor)
//   // if (liquidationCollateralUsd < minCollateralUsd) {
//   //   liquidationCollateralUsd = minCollateralUsd
//   // }

//   let liquidationPrice = 0n

//   const indexTokenDescription = getMappedValue(GMX.TOKEN_ADDRESS_DESCRIPTION_MAP, indexToken)
//   const indexTokenDenominator = getDenominator(indexTokenDescription.decimals)

//   if (collateralToken === indexToken) {
//     if (isLong) {
//       const denominator = sizeInTokens + collateralAmount
//       if (denominator === 0n) return 0n
      
//       liquidationPrice = (sizeInUsd + liquidationCollateralUsd - priceImpactDeltaUsd + totalFeesUsd) / denominator * indexTokenDenominator
//     } else {
//       const denominator = sizeInTokens - collateralAmount
//       if (denominator === 0n) return 0n

//       liquidationPrice = (sizeInUsd - liquidationCollateralUsd + priceImpactDeltaUsd - totalFeesUsd) / denominator * indexTokenDenominator
//     }
//   } else {
//     if (sizeInTokens === 0n) return 0n
//     const remainingCollateralUsd = collateralUsd + priceImpactDeltaUsd - totalPendingFeesUsd - closingFeeUsd

//     if (isLong) {
//       liquidationPrice = (liquidationCollateralUsd - remainingCollateralUsd + sizeInUsd) / sizeInTokens * indexTokenDenominator
//     } else {
//       liquidationPrice = (liquidationCollateralUsd - remainingCollateralUsd - sizeInUsd) / -sizeInTokens * indexTokenDenominator
//     }
//   }

//   if (liquidationPrice <= 0n) return 0n

//   return liquidationPrice
// }
