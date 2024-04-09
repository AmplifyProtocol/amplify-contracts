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
// ========================== IReader ==========================
// ==============================================================
// Amplify Protocol: https://github.com/AmplifyProtocol

// ==============================================================

interface IReader {

    struct MarketFees {
        FundingFee fundingFee;
        uint256 borrowFee;
        uint256 dexExecutionFee;
        uint256 amplifyExecutionFee;
    }

    struct PositionFees {
        uint256 priceImpact;
        uint256 openFee;
        uint256 closeFee;
    }

    struct FundingFee {
        bool longsPayShorts;
        uint256 amount;
    }

    // Market Data

    function getMarketFees(bytes32 _routeTypeKey) external view returns (MarketFees memory _fees);
    // function getAvailableLiquidity(bytes32 _routeTypeKey) external view returns (uint256 _availableLiquidity);
    // function getOpenInterest(bytes32 _routeTypeKey) external view returns (uint256 _longIO, uint256 _shortIO);
    // function getPrice(address _token) external view returns (uint256 _price);

    // TODO
    // function getLiquidationPrice(bytes32 _routeTypeKey, uint256 acceptablePrice, uint256 triggerPrice) virtual public view returns (uint256 _liquidationPrice);

    // Trader Data

    // TODO
    // need to look what GMXV2 Reader returns - https://github.com/gmx-io/gmx-synthetics/blob/main/contracts/reader/ReaderUtils.sol#L54
    // (stuff like fees/OI/etc, but make it generelized)
    // function getPosition(bytes32 _routeTypeKey, address _trader)

    // TODO
    // function getEstRewards() // when i finish implementing tokenomics features in the copy trading system we'll look into it

    // Puppets Data

    // function getBestPuppets(address[] memory _puppets) external view returns (address[] memory _bestPuppets) {
    //     // 1. check puppets limit (from our datastore/libs)
    //     // 2. make sure each puppet is actually subscribed
    //     // 3. pick the ones with the highest allowance amount (deposit account + allowance %)
    // }

    // function getIncreaseSizeDelta(
    //     address[] calldata _puppets,
    //     uint256 _traderCollateralDelta,
    //     uint256 _traderSizeDelta
    // ) external view returns (uint256 _sizeDelta) {
    //     // 1. calc trader target leverage
    //     // 2. figure out how much collateral each puppet adds + what size he'll need to maintain the target leverage
    //     // 3. return the total sizeDelta (_traderSizeDelta + puppetsSizeDelta)

    //     // * we prevent against puppet mev attacks with time restrictions on withdrawals
    //     // * imagine Trader adds $100 collateral and $1000 size for 10x leverage, and he has 2 puppets each contribues $50 collateral, what will be the total increase sizeDelta? 
    // }

    // function getDecreaseSizeDelta() // same as above but for decrease, ask what leverage trader wants and figure out the required decrease size

    // getDecreaseCollateralDelta(address[] _puppets, uint256 _traderDecreaseCollagteralDelta) // same as above

    // * regarding getDecreaseSizeDelta/getDecreaseCollateralDelta -- need to think more about it, so feel free to shot me a dm if your not sure
}