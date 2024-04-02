// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Keys} from "src/integrations/libraries/Keys.sol";
import {IDataStore} from "src/integrations/utilities/interfaces/IDataStore.sol";
import {CommonHelper} from "src/integrations/libraries/RouteSetter.sol";

abstract contract BaseReader {
    
    IDataStore constant amplifyDataStore = IDataStore(0xcf269C855fDa1e8Ea65Ce51bea2208B400Df03d5);
    address _weth = address(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    uint256 internal constant _BASIS_POINTS_DIVISOR = 10000;
    uint256 internal constant _DENOMINATOR = 1e30;


    struct FeesAccrued {
        int256 fundingFee;
        uint256 borrowFee;
        int256 priceImpact;
        uint256 closeFee; 
    }

    struct FeesRates {
        uint256 borrowingForLongs;
        uint256 borrowingForShorts;
        int256 fundingForLongs;
        int256 fundingForShorts;
    }

    struct PositionData {
        uint256 sizeInUsd;
        uint256 sizeInTokens;
        uint256 collateralAmount;
        address market;
        address collateralToken;
        bool isLong;
        uint256 borrowingFactor;
        uint256 fundingFeePerSize;
    }

    struct OpenInterest {
        uint256 longOI;
        uint256 shortOI;
        uint256 maxLongOI;
        uint256 maxShortOI;
    }

    // Market Data

    // executionFee (from our datastore)
    // fundingFee/borrowFee per second/hour from GMX
    // priceImpact not sure how this goes, need to look into
    function getFees(bytes32 _routeTypeKey, address _trader) virtual public view returns (FeesAccrued memory _fees);

    function getMinExecutionFees() virtual public view returns (uint256 minExecutionFee, uint256 minPuppetExecutionFee);

    function getFeesPerSecond(address _market) virtual public view returns (FeesRates memory _fees);

    // available liq in usd with 30 decimals
    function getAvailableLiquidity(bytes32 _routeTypeKey, address _trader) virtual public view returns (uint256 _longTokenUsd, uint256 _shortTokenUsd);

    // short/long open interest in usd with 30 decimals
    function getOpenInterest(bytes32 _routeTypeKey, address _trader) virtual public view returns (OpenInterest memory _openInterest);

    // need to look how gmx calcs that
    // function getLiquidationPrice(bytes32 _routeTypeKey, address _trader) virtual public view returns (int256 _liquidationPrice);

    // price in usd with 30 decimals
    function getPrice(address _token) virtual public view returns (uint256 _price);

    // get24HChange() - SUBGRAPH
    // get24HHigh() - SUBGRAPH
    // get24HLow() - SUBGRAPH

    // Trader Data

    // need to look what GMXV2 Reader returns - https://github.com/gmx-io/gmx-synthetics/blob/main/contracts/reader/ReaderUtils.sol#L54
    // (stuff like fees/OI/etc, but make it generelized)
    function getPosition(bytes32 _routeTypeKey, address _trader) virtual public view returns (PositionData memory _position);

    // function getEstRewards() // when i finish implementing tokenomics features in the copy trading system we'll look into it

    // getSwapMinAmount(address[] _path) // same as above, i need to finish implementing that feature first

    // getRoutes(address _trader) - returns all Routes owned by a trader - SUBGRAPH

    // Puppets Data

    function getBestPuppets(address[] memory _puppets) external view returns (address[] memory _bestPuppets) {
        // 1. check puppets limit (from our datastore/libs)
        // 2. make sure each puppet is actually subscribed
        // 3. pick the ones with the highest allowance amount (deposit account + allowance %)
    }

    function getIncreaseSizeDelta(
        address[] calldata _puppets,
        uint256 _traderCollateralDelta,
        uint256 _traderSizeDelta
    ) external view returns (uint256 _sizeDelta) {
        // 1. calc trader target leverage
        // 2. figure out how much collateral each puppet adds + what size he'll need to maintain the target leverage
        // 3. return the total sizeDelta (_traderSizeDelta + puppetsSizeDelta)

        // * we prevent against puppet mev attacks with time restrictions on withdrawals
        // * imagine Trader adds $100 collateral and $1000 size for 10x leverage, and he has 2 puppets each contribues $50 collateral, what will be the total increase sizeDelta? 
    }

    // function getDecreaseSizeDelta() // same as above but for decrease, ask what leverage trader wants and figure out the required decrease size

    // getDecreaseCollateralDelta(address[] _puppets, uint256 _traderDecreaseCollagteralDelta) // same as above

    // * regarding getDecreaseSizeDelta/getDecreaseCollateralDelta -- need to think more about it, so feel free to shot me a dm if your not sure

        
    function getBestPuppets(IDataStore _dataStore, address _route, address[] memory _puppets) public view returns (address[] memory _bestPuppets) {
        uint256[] memory _subscriptionAmount = new uint256[](_puppets.length);
        address[] memory _validPuppets = new address[](_puppets.length);
        uint256 _validPuppetsCount;

        for (uint256 i = 0; i < _puppets.length; i++) {
            uint256 _allowance = CommonHelper.puppetAllowancePercentage(_dataStore, _puppets[i], _route);
            uint256 _deposit = CommonHelper.puppetAccountBalance(_dataStore, _puppets[i], CommonHelper.wnt(_dataStore));
            uint256 _expiry = CommonHelper.puppetSubscriptionExpiry(_dataStore, _puppets[i], _route);
            if (_allowance > 0 && _deposit > 0 && _expiry > (block.timestamp + 24 hours)) {
                _subscriptionAmount[_validPuppetsCount] = _deposit * _allowance / _BASIS_POINTS_DIVISOR;
                _validPuppets[_validPuppetsCount] = _puppets[i];
                _validPuppetsCount++;
            }
        }
        if (_validPuppetsCount == 0) revert NoValidPuppets();

        for (uint256 i = 0; i < _validPuppetsCount-1; i++) {
            for (uint256 j = 0; j < _validPuppetsCount-i-1; j++) {
                if (_subscriptionAmount[j] < _subscriptionAmount[j+1]) {
                    (_subscriptionAmount[j], _subscriptionAmount[j+1]) = (_subscriptionAmount[j+1], _subscriptionAmount[j]);
                    (_validPuppets[j], _validPuppets[j+1]) = (_validPuppets[j+1], _validPuppets[j]);
                }
            }
        }
        uint256 _count = CommonHelper.maxPuppets(_dataStore) < _validPuppetsCount ? CommonHelper.maxPuppets(_dataStore) : _validPuppetsCount;
        _bestPuppets = new address[](_count);
        for (uint256 i = 0; i < _count; i++) {
            _bestPuppets[i] = _validPuppets[i];
        }
    }

    // ============================================================================================
    // Errors
    // ============================================================================================

    error NoValidPuppets();
    error UnexpectedBorrowingFactor();
}