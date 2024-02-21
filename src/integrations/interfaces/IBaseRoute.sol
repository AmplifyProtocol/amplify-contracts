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
// ========================= IBaseRoute =========================
// ==============================================================
// Amplify Protocol: https://github.com/AmplifyProtocol

// ==============================================================

interface IBaseRoute {

    enum OrderType {
        MarketIncrease, // increase position at the current market price, the order will be cancelled if the position cannot be increased at the acceptablePrice
        LimitIncrease, // increase position if the triggerPrice is reached and the acceptablePrice can be fulfilled
        MarketDecrease, // decrease position at the current market price, the order will be cancelled if the position cannot be decreased at the acceptablePrice
        LimitDecrease // decrease position if the triggerPrice is reached and the acceptablePrice can be fulfilled
    }

    struct AdjustPositionParams {
        OrderType orderType; // the order type
        uint256 collateralDelta; // for increase orders, is the amount of the collateral token sent in by the user, for decrease orders, is the amount of the position's collateral token to withdraw
        uint256 sizeDelta; // the requested change in position size, in USD with 30 decimals
        uint256 acceptablePrice; // the acceptable execution price for increase / decrease orders, in USD with 30 decimals
        uint256 triggerPrice; // the trigger price for non-market orders, in USD with 30 decimals
        address[] puppets; // the subscribed puppets to allow to the position. Used only when opening a new position
    }

    struct SwapParams {
        address[] path; // the swap path, last element must be the collateral token
        uint256 amount; // the amount in of the first token in the `path`
        uint256 minOut; // the minimum amount of the last token in the `path` that must be received for the swap to not revert
    }

    struct ExecutionFees {
        uint256 dexKeeper; // the execution fee paid to the underlying DEX keeper
        uint256 puppetKeeper; // the execution fee paid to the DecreaseSize Puppet keeper
    }

    // @todo --> combine AddCollateralRequest and PuppetsRequest
    struct AddCollateralRequest {
        uint256 puppetsAmountIn;
        uint256 traderAmountIn;
        uint256 traderShares;
        uint256 totalSupply;
        uint256[] puppetsShares;
        uint256[] puppetsAmounts;
    }

    struct PuppetsRequest {
        uint256 puppetsAmountIn;
        uint256 totalSupply;
        uint256 totalAssets;
        address[] puppetsToUpdateTimestamp;
        uint256[] puppetsShares;
        uint256[] puppetsAmounts;
    }

    // ============================================================================================
    // Mutated Functions
    // ============================================================================================

    // orchestrator

    // called by trader

    /// @notice The ```requestPosition``` function creates a new position request
    /// @param _adjustPositionParams The adjusment params for the position
    /// @param _swapParams The swap data of the Trader, enables the Trader to add collateral with a non-collateral token
    /// @param _executionFees The execution fees
    /// @param _isIncrease The boolean indicating if the request is an increase or decrease request
    /// @return _requestKey The request key
    function requestPosition(AdjustPositionParams memory _adjustPositionParams, SwapParams memory _swapParams, ExecutionFees memory _executionFees, bool _isIncrease) external payable returns (bytes32 _requestKey);

    /// @notice The ```_cancelRequest``` function is used to cancel a non-market request
    /// @param _requestKey The request key of the request
    function cancelRequest(bytes32 _requestKey) external payable;

    // called by keeper

    /// @notice The ```decreaseSize``` function is called by a Keeper to adjust the Route Account leverage to match the target leverage
    /// @param _adjustPositionParams The adjusment params for the position
    /// @param _executionFee The total execution fee, paid by the Keeper in ETH
    /// @return _requestKey The request key
    function decreaseSize(AdjustPositionParams memory _adjustPositionParams, uint256 _executionFee) external payable returns (bytes32 _requestKey);

    // called by owner

    /// @notice The ```forceCallback``` function is called by an emergency Authority address to force a callback, in case it failed
    /// @param _requestKey The request key
    /// @param _isExecuted The boolean indicating if the request was executed
    /// @param _isIncrease The boolean indicating if the request was an increase or decrease request
    function forceCallback(bytes32 _requestKey, bool _isExecuted, bool _isIncrease) external;

    /// @notice The ```rescueTokens``` is called by the Orchestrator and Authority to rescue tokens
    /// @param _amount The amount to rescue
    /// @param _token The token address
    /// @param _receiver The receiver address
    function rescueToken(uint256 _amount, address _token, address _receiver) external;

    // ============================================================================================
    // Events
    // ============================================================================================

    event CancelRequest(bytes32 requestKey);
    event DecreaseSize(bytes32 requestKey, uint256 sizeDelta, uint256 acceptablePrice);
    event Callback(bytes32 requestKey, bool isExecuted, bool isIncrease);
    event ForceCallback(bytes32 requestKey, bool isExecuted, bool isIncrease);
    event RequestPosition(bytes32 requestKey, uint256 collateralDelta, uint256 sizeDelta, uint256 acceptablePrice, bool isIncrease);
    event RepayWNT(uint256 amount);
    event Repay(uint256 totalAssets, bytes32 requestKey);
    event RescueToken(uint256 amount, address token, address receiver);
    event ResetRoute();

    // ============================================================================================
    // Errors
    // ============================================================================================

    error WaitingForCallback();
    error WaitingForKeeperAdjustment();
    error NotKeeper();
    error NotTrader();
    error InvalidExecutionFee();
    error Paused();
    error NotOrchestrator();
    error RouteFrozen();
    error NotCallbackCaller();
    error NotWaitingForKeeperAdjustment();
    error ZeroAddress();
    error KeeperAdjustmentDisabled();
}