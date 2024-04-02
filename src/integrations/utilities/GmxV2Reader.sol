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
import {IGMXV2Reader, Market, Price, MarketPoolValueInfo, Position, MarketUtils, ReaderUtils, GmxKeys, ReaderPricingUtils, IReferralStorage, Precision} from "src/integrations/utilities/interfaces/IGmxV2Reader.sol";

import {DataStore} from "src/integrations/utilities/DataStore.sol";
import "./BaseReader.sol";


contract GMXV2Reader is BaseReader {

    struct PositionInfo {
        uint256 executionPrice;
        uint256 fundingFeeAmount;
        uint256 latestFundingFeeAmountPerSize;
        uint256 latestLongTokenClaimableFundingAmountPerSize;
        uint256 latestShortTokenClaimableFundingAmountPerSize;
        uint256 borrowingFeeUsd;
        uint256 closingFeeFactor;
    }

    IGMXV2Reader constant reader = IGMXV2Reader(0xf60becbba223EEA9495Da3f606753867eC10d139);
    IDataStore constant _gmxDataStore = IDataStore(0xFD70de6b91282D8017aA4E741e9Ae325CAb992d8);
    DataStore gmxDataStore = DataStore(0xFD70de6b91282D8017aA4E741e9Ae325CAb992d8);


    // ============================================================================================
    // View Functions
    // ============================================================================================

    function getAvailableLiquidity(bytes32 _routeTypeKey, address _trader) override public view returns (uint256 _longTokenUsd, uint256 _shortTokenUsd) {
        (,address _market) =  _getMarket(_routeTypeKey, _trader);
        (_longTokenUsd, _shortTokenUsd) = getAvailableLiquidity( _market);
    }

    function getAvailableLiquidity(address _market) public view returns (uint256, uint256) {
        Market.Props memory marketProps = reader.getMarket(gmxDataStore, _market);

        uint256 _longTokenAmount = _gmxDataStore.getUint(GmxKeys.poolAmountKey(_market, marketProps.longToken));
        uint256 _shortTokenAmount = _gmxDataStore.getUint(GmxKeys.poolAmountKey(_market, marketProps.shortToken));

        uint256 _longTokenPrice = getPrice(marketProps.longToken);
        uint256 _shortTokenPrice = getPrice(marketProps.shortToken);

        uint256 _longTokenUsd = _longTokenAmount * _longTokenPrice / (10 ** IERC20Metadata(marketProps.longToken).decimals());
        uint256 _shortTokenUsd = _shortTokenAmount * _shortTokenPrice/ (10 ** IERC20Metadata(marketProps.shortToken).decimals());

        return (_longTokenUsd, _shortTokenUsd);
    }
    
    function getOpenInterest(bytes32 _routeTypeKey, address _trader) override public view returns (OpenInterest memory _openInterest) {
        (,address _market) =  _getMarket(_routeTypeKey, _trader);
        _openInterest = getOpenInterest(_market);
    }

    function getOpenInterest(address _market) public view returns (OpenInterest memory _openInterest) {
        Market.Props memory marketProps = reader.getMarket(gmxDataStore, _market);

        uint256 _shortTokenLongOI = _gmxDataStore.getUint(GmxKeys.openInterestKey(_market, marketProps.shortToken, true));
        uint256 _shortTokenShortOI = _gmxDataStore.getUint(GmxKeys.openInterestKey(_market, marketProps.shortToken, false));
        uint256 _longTokenLongOI = _gmxDataStore.getUint(GmxKeys.openInterestKey(_market, marketProps.longToken, true));
        uint256 _longTokenShortOI = _gmxDataStore.getUint(GmxKeys.openInterestKey(_market, marketProps.longToken, false));
        uint256 _maxOpenInterestLong = _gmxDataStore.getUint(GmxKeys.maxOpenInterestKey(_market, true));
        uint256 _maxOpenInterestShort = _gmxDataStore.getUint(GmxKeys.maxOpenInterestKey(_market, false));

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
        PositionInfo memory _positionFeesInfo = _getPositionFeesInfo(_routeTypeKey, _trader);
        PositionData memory _position = getPosition(_routeTypeKey, _trader);
        
        _fees = FeesAccrued({
            fundingFee: _getAccruedFundingFee(_routeTypeKey, _trader),
            borrowFee: _getBorrowingFees(_routeTypeKey, _trader),//_positionFeesInfo.borrowingFeeUsd,
            priceImpact: _getPriceImpact(_routeTypeKey, _trader),
            closeFee: _positionFeesInfo.closingFeeFactor * _position.sizeInUsd / _DENOMINATOR
         });
    }

    function getMinExecutionFees() override public view returns (uint256 minExecutionFee, uint256 minPuppetExecutionFee) {
           return (CommonHelper.minExecutionFee(amplifyDataStore), CommonHelper.minPuppetExecutionFee(amplifyDataStore));
            
    }

    function getFeesPerSecond(address _market) override public view returns (FeesRates memory _fees) {
        (uint256 _borrowingForLongs, uint256 _borrowingForShorts) = _getBorrowingFeesPerSecond(_market);
        (, int256 _fundingForLongs, int256 _fundingForShorts) = _getFundingFeesPerSecond(_market);

        _fees = FeesRates({
            borrowingForLongs: _borrowingForLongs,  
            borrowingForShorts: _borrowingForShorts, 
            fundingForLongs: _fundingForLongs,
            fundingForShorts: _fundingForShorts 
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
            isLong: positionProps.flags.isLong,
            borrowingFactor: positionProps.numbers.borrowingFactor
         });
    }
    event DataTest(address market, int256 fundingFee, uint256 borrowFee, uint256 closeFee, int256 maxNegativePriceImpactUsd, int256 priceImpactDeltaUsd, uint256 minCollateralFactor, int256 liquidationCollateralUsd);
    /// @notice https://github.com/RageTrade/Perp-Aggregator-SDK/blob/c6a23a68b3c5bec4c3bd6536d3a74c1ef6b5bb31/src/configs/gmxv2/positions/utils.ts#L46
    function getLiquidationPrice(bytes32 _routeTypeKey, address _trader) public  returns (int256 _liquidationPrice) {

        PositionData memory _position = getPosition(_routeTypeKey, _trader);
        FeesAccrued memory _fees = getAccruedFees(_routeTypeKey, _trader);
        Market.Props memory _marketProps = reader.getMarket(gmxDataStore, _position.market);

        int256 totalPendingFeesUsd = _fees.fundingFee + int256(_fees.borrowFee) + int256(_fees.closeFee);

        int256 maxNegativePriceImpactUsd = (-1) * int256(_position.sizeInUsd * _gmxDataStore.getUint(GmxKeys.maxPositionImpactFactorForLiquidationsKey(_position.market)));

        int256 priceImpactDeltaUsd = _getPriceImpactDeltaUsd(_fees.priceImpact, maxNegativePriceImpactUsd, true);

        uint256 minCollateralFactor = _gmxDataStore.getUint(GmxKeys.minCollateralFactorKey(_position.market)); // This determines the minimum allowed ratio of (position collateral) / (position size)
        int256 liquidationCollateralUsd = int256(_position.sizeInUsd * minCollateralFactor /_DENOMINATOR);

        emit DataTest(_position.market, _fees.fundingFee, _fees.borrowFee, _fees.closeFee, maxNegativePriceImpactUsd, priceImpactDeltaUsd, minCollateralFactor, liquidationCollateralUsd);

        int256 indexTokenDenominator = int256(10 ** IERC20Metadata(_marketProps.indexToken).decimals());

        if (_position.collateralToken == _marketProps.indexToken) {
            if (_position.isLong) {
                uint256 denominator = _position.sizeInTokens + _position.collateralAmount;
                if (denominator == 0) return 0;

                _liquidationPrice = (int256(_position.sizeInUsd) + liquidationCollateralUsd - priceImpactDeltaUsd + totalPendingFeesUsd) / int256(denominator) * indexTokenDenominator;
            } else {
                uint256 denominator = _position.sizeInTokens - _position.collateralAmount;
                if (denominator == 0) return 0;

                _liquidationPrice = (int256(_position.sizeInUsd) - liquidationCollateralUsd + priceImpactDeltaUsd - totalPendingFeesUsd) / int256(denominator) * indexTokenDenominator;
            }
        } else {
            if (_position.sizeInTokens == 0) return 0;
            int256 remainingCollateralUsd = int256(_position.collateralAmount) + priceImpactDeltaUsd - totalPendingFeesUsd - int256(_fees.closeFee);

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

    function _getBorrowingFeesPerSecond(address _market) internal view returns (uint256 borrowingFactorPerSecondForLongs, uint256 borrowingFactorPerSecondForShorts) {
        Market.Props memory marketProps = reader.getMarket(gmxDataStore, _market);

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
            _market
        );
        return (marketInfo.borrowingFactorPerSecondForLongs, marketInfo.borrowingFactorPerSecondForShorts);
    }

    function _getFundingFeesPerSecond(address _market) internal view returns (bool longsPayShorts, int256 longFunding, int256 shortFunding) {

        OpenInterest memory _interest = getOpenInterest(_market);
        uint256 longInterestUsd = _interest.longOI;
        uint256 shortInterestUsd = _interest.shortOI;

        int256 fundingFactor = _gmxDataStore.getInt(GmxKeys.savedFundingFactorPerSecondKey(_market));
        
        longsPayShorts = fundingFactor > 0;
        uint256 ratio = shortInterestUsd < longInterestUsd ? ((shortInterestUsd * _DENOMINATOR / longInterestUsd)) : ((longInterestUsd * _DENOMINATOR / shortInterestUsd));
        int256 factorPerSecondB = (int256(ratio) * fundingFactor / 1e30);
        int256 factorPerSecondA = (int256(1e60 / ratio) * fundingFactor / 1e30);
        longFunding = longsPayShorts ? (-1) * factorPerSecondA : factorPerSecondB;
        shortFunding = longsPayShorts ? factorPerSecondB : (-1) * factorPerSecondA;
    }

    function _getFundingFeePerSize(bytes32 _routeTypeKey, address _trader) internal view returns (uint256) {
        (address _route,) =  _getMarket(_routeTypeKey, _trader);
        bytes32 _key = GMXV2OrchestratorHelper.positionKey(amplifyDataStore, _route);
        Position.Props memory positionProps = reader.getPosition(gmxDataStore,_key);
        return positionProps.numbers.fundingFeeAmountPerSize;
    }

    /// @notice https://github.com/nissoh/gmx-middleware/blob/f81e968a4c2f8401e420314596fe4c66db59ec60/utils/src/position.ts#L66
    function _getAccruedFundingFee(bytes32 _routeTypeKey, address _trader) internal view returns (int256 _fundingFee) {
        uint256 _fundingFeeAmountPerSize = _getFundingFeePerSize(_routeTypeKey, _trader);

        PositionInfo memory _positonInfo = _getPositionFeesInfo(_routeTypeKey, _trader); 
        uint256 _latestFundingFeeAmountPerSize = _positonInfo.latestFundingFeeAmountPerSize;
        
        PositionData memory _position = getPosition(_routeTypeKey, _trader);
        int256 _size = int256(_position.sizeInUsd);

        int256 _fundingDiffFactor = int256(_latestFundingFeeAmountPerSize) - int256(_fundingFeeAmountPerSize);
        return ((_size * _fundingDiffFactor )/ 1e30);
    }

    /// @notice https://github.com/sherlock-audit/2023-02-gmx/blob/b8f926738d1e2f4ec1173939caa51698f2c89631/gmx-synthetics/contracts/market/MarketUtils.sol#L1232C5-L1246C6

    /// @param latestFundingAmountPerSize the latest funding amount per size
    /// @param positionFundingAmountPerSize the funding amount per size for the position
    /// @param positionSizeInUsd the position size in USD
    /// @return (hasPendingFundingFee, fundingFeeAmount)
    function _getFundingFeeAmount(
        int256 latestFundingAmountPerSize,
        int256 positionFundingAmountPerSize,
        uint256 positionSizeInUsd
    ) internal pure returns (bool, int256) {
        int256 fundingDiffFactor = (latestFundingAmountPerSize - positionFundingAmountPerSize);
        int256 amount = Precision.applyFactor(positionSizeInUsd, fundingDiffFactor);

        return (fundingDiffFactor != 0 && amount == 0, amount);
    }

    /// @return the borrowing fees for a position
    function _getBorrowingFees(bytes32 _routeTypeKey, address _trader) internal view returns (uint256) {
        PositionData memory _position = getPosition(_routeTypeKey, _trader);
        uint256 _cumulativeBorrowingFactor = _gmxDataStore.getUint(GmxKeys.cumulativeBorrowingFactorKey(_position.market, _position.isLong));
        
        if (_position.borrowingFactor > _cumulativeBorrowingFactor) {
            revert UnexpectedBorrowingFactor();
        }
        uint256 _diffFactor = _cumulativeBorrowingFactor - _position.borrowingFactor;
        return Precision.applyFactor(_position.sizeInUsd, _diffFactor);
    }

    // function _getAccruedBorrowingFee(bytes32 _routeTypeKey, address _trader) internal view returns (uint256 _borrowingFees) {
    //     (address _route,) =  _getMarket(_routeTypeKey, _trader);
    //     bytes32 _key = GMXV2OrchestratorHelper.positionKey(amplifyDataStore, _route);
    //     Position.Props memory positionProps = reader.getPosition(
    //         gmxDataStore,
    //         _key
    //     );
    //     // Calculate the difference between the pool borrowing factor and the position borrowing factor
    //     uint256 _borrowingFactorDifference = _getBorrowingFeePoolFactor(_routeTypeKey,_trader) - positionProps.numbers.borrowingFactor;
        
    //     return (positionProps.numbers.sizeInUsd * _borrowingFactorDifference) / _DENOMINATOR;
    // }

    // function _getBorrowingFeePoolFactor(bytes32 _routeTypeKey, address _trader) internal view returns (uint256 _borrowingFeePoolFactor) {
    //     (,address market) =  _getMarket(_routeTypeKey, _trader);

    //     Market.Props memory marketProps = reader.getMarket(gmxDataStore, market);

    //     uint256 indexTokenPrice = getPrice(marketProps.indexToken);
    //     uint256 longTokenPrice = getPrice(marketProps.longToken);
    //     uint256 shortTokenPrice = getPrice(marketProps.shortToken);

    //     Price.Props memory indexTokenPriceProps = Price.Props({min: indexTokenPrice, max: indexTokenPrice});
    //     Price.Props memory longTokenPriceProps = Price.Props({min: longTokenPrice, max: longTokenPrice});
    //     Price.Props memory shortTokenPriceProps = Price.Props({min: shortTokenPrice,max: shortTokenPrice});

    //     (,MarketPoolValueInfo.Props memory marketValueProp) = reader.getMarketTokenPrice(
    //         gmxDataStore,
    //         marketProps,
    //         indexTokenPriceProps,
    //         longTokenPriceProps,
    //         shortTokenPriceProps,
    //         keccak256(abi.encode("MAX_PNL_FACTOR")),
    //         true
    //     );
    //     return marketValueProp.borrowingFeePoolFactor;
    // }

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

    function _getPositionFeesInfo(bytes32 _routeTypeKey, address _trader) public view returns (PositionInfo memory _info) {
        (address _route,) =  _getMarket(_routeTypeKey, _trader);
        bytes32 _key = GMXV2OrchestratorHelper.positionKey(amplifyDataStore, _route);
        (,address _market) =  _getMarket(_routeTypeKey, _trader);

        // To measure results against ui on opened positon:
        // bytes32 _key = 0xa8ab5058c2aa1681effa619cff63b72896c129d255b72d258d0ebbaab0840dc3;
        // address _market = 0x70d95587d40A2caf56bd97485aB3Eec10Bee6336; 

        Market.Props memory marketProps = reader.getMarket(gmxDataStore, _market);

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

        PositionData memory _position = getPosition(_routeTypeKey, _trader);

        ReaderUtils.PositionInfo memory positonInfo = reader.getPositionInfo(
            gmxDataStore,
            IReferralStorage(0xe6fab3F0c7199b0d34d7FbE83394fc0e0D06e99d),
            _key,
            prices,
            _position.sizeInUsd,
            address(0),
            true            
        );

        return PositionInfo({
            executionPrice: positonInfo.executionPriceResult.executionPrice,
            fundingFeeAmount: positonInfo.fees.funding.fundingFeeAmount,
            latestFundingFeeAmountPerSize: positonInfo.fees.funding.latestFundingFeeAmountPerSize,
            latestLongTokenClaimableFundingAmountPerSize: positonInfo.fees.funding.latestLongTokenClaimableFundingAmountPerSize,
            latestShortTokenClaimableFundingAmountPerSize: positonInfo.fees.funding.latestShortTokenClaimableFundingAmountPerSize,
            borrowingFeeUsd: positonInfo.fees.borrowing.borrowingFeeUsd,
            closingFeeFactor: positonInfo.fees.positionFeeFactor
        });
    }
}