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
// ========================== Minter ============================
// ==============================================================
// Amplify Protocol: https://github.com/AmplifyProtocol

// ==============================================================

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IMinter} from "./interfaces/IMinter.sol";
import {IAmplify} from "./interfaces/IAmplify.sol";
import {IDiscountedAmplify} from "./interfaces/IDiscountedAmplify.sol";
import {IScoreGauge} from "./interfaces/IScoreGauge.sol";
import {IGaugeController} from "./interfaces/IGaugeController.sol";

/// @title Token Minter
/// @author Curve Finance
/// @author johnnyonline
/// @notice Modified fork from Curve Finance: https://github.com/curvefi 
contract Minter is ReentrancyGuard, IMinter {

    mapping(uint256 => mapping(address => bool)) public minted; // epoch -> gauge -> hasMinted

    IAmplify public immutable token;
    IDiscountedAmplify public immutable dToken;

    IGaugeController private immutable _controller;

    // ============================================================================================
    // Constructor
    // ============================================================================================

    constructor(IAmplify _token, IDiscountedAmplify _dToken, IGaugeController __controller) {
        token = _token;
        dToken = _dToken;
        _controller = __controller;
    }

    // ============================================================================================
    // External functions
    // ============================================================================================

    /// @inheritdoc IMinter
    function controller() external view override returns (address) {
        return address(_controller);
    }

    /// @inheritdoc IMinter
    function mint(address _gauge) external nonReentrant {
        _mint(_gauge);
    }

    /// @inheritdoc IMinter
    function mintMany(address[] memory _gauges) external nonReentrant {
        for (uint256 i = 0; i < _gauges.length; i++) {
            if (_gauges[i] == address(0)) {
                break;
            }
            _mint(_gauges[i]);
        }
    }

    // ============================================================================================
    // Internal functions
    // ============================================================================================

    function _mint(address _gauge) internal {
        if (IScoreGauge(_gauge).isKilled()) revert GaugeIsKilled();

        IGaugeController __controller = _controller;
        if (__controller.gaugeTypes(_gauge) < 0) revert GaugeNotAdded();

        uint256 _epoch = __controller.epoch() - 1; // underflows if epoch() is 0
        if (!__controller.hasEpochEnded(_epoch)) revert EpochNotEnded();
        if (minted[_epoch][_gauge]) revert AlreadyMinted();

        (uint256 _epochStartTime, uint256 _epochEndTime) = __controller.epochTimeframe(_epoch);
        if (block.timestamp < _epochEndTime) revert EpochNotEnded();

        uint256 _totalMint = token.mintableInTimeframe(_epochStartTime, _epochEndTime);
        uint256 _mintForGauge = _totalMint * __controller.gaugeWeightForEpoch(_epoch, _gauge) / 1e18;

        if (_mintForGauge > 0) {
            minted[_epoch][_gauge] = true;

            token.mint(address(dToken), _mintForGauge);
            dToken.addRewards(_mintForGauge, _gauge);

            IScoreGauge(_gauge).addRewards(_epoch, _mintForGauge);

            emit Minted(_gauge, _mintForGauge, _epoch);
        }
    }
}