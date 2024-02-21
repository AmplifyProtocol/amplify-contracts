// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {GMXV2RouteHelper} from "../../../src/integrations/GMXV2/libraries/GMXV2RouteHelper.sol";
import {GMXV2OrchestratorHelper} from "../../../src/integrations/GMXV2/libraries/GMXV2OrchestratorHelper.sol";

import {IDataStore} from "../../../src/integrations/utilities/interfaces/IDataStore.sol";

import {IBaseOrchestrator} from "../../../src/integrations/interfaces/IBaseOrchestrator.sol";

import "../../Base.t.sol";

/// @notice Base helper contract with common functionality needed by all helper contracts
abstract contract BaseHelper is Base {}