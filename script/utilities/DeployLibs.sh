#!/bin/bash

# Prompt user for input
read -p "Enter your private key: " PRIVATE_KEY
read -p "Enter your RPC URL: " RPC_URL

# Function to extract deployed address
extract_deployed_address() {
    echo "$1" | grep "Deployed to:" | awk '{print $3}'
}

# # import {SharesHelper} from "../libraries/SharesHelper.sol";
# --libraries "src/integrations/libraries/SharesHelper.sol:SharesHelper:$shares_helper_address"
# # import {Keys} from "../libraries/Keys.sol";
# --libraries "src/integrations/libraries/Keys.sol:Keys:$keys_address"
# # import {CommonHelper} from "./CommonHelper.sol";
# --libraries "src/integrations/libraries/CommonHelper.sol:CommonHelper:$common_helper_address"
# # route reader
# --libraries "src/integrations/libraries/RouteReader.sol:RouteReader:$route_reader_address"
# # gmxv2 keys
# --libraries "src/integrations/GMXV2/libraries/GMXV2Keys.sol:GMXV2Keys:$gmxv2_keys_address"
# # order utils
# --libraries "src/integrations/GMXV2/libraries/OrderUtils.sol:OrderUtils:$gmxv2_order_utils_address"

# Deploy contracts and extract addresses
keys_address=$(extract_deployed_address "$(forge create --verify --legacy --private-key $PRIVATE_KEY --rpc-url $RPC_URL src/integrations/libraries/Keys.sol:Keys)")
echo "deployed keys to $keys_address"
shares_helper_address=$(extract_deployed_address "$(forge create --verify --legacy --private-key $PRIVATE_KEY --rpc-url $RPC_URL src/integrations/libraries/SharesHelper.sol:SharesHelper)")
echo "deployed shares helper to $shares_helper_address"
common_helper_address=$(extract_deployed_address "$(forge create --libraries src/integrations/libraries/Keys.sol:Keys:$keys_address --legacy --private-key $PRIVATE_KEY --rpc-url $RPC_URL src/integrations/libraries/CommonHelper.sol:CommonHelper)")
echo "deployed common helper to $common_helper_address"
route_reader_address=$(extract_deployed_address "$(forge create --libraries src/integrations/libraries/CommonHelper.sol:CommonHelper:$common_helper_address --libraries src/integrations/libraries/Keys.sol:Keys:$keys_address --libraries src/integrations/libraries/SharesHelper.sol:SharesHelper:$shares_helper_address --legacy --private-key $PRIVATE_KEY --rpc-url $RPC_URL src/integrations/libraries/RouteReader.sol:RouteReader)")
echo "deployed route reader to $route_reader_address"
route_setter_address=$(extract_deployed_address "$(forge create --libraries src/integrations/libraries/RouteReader.sol:RouteReader:$route_reader_address --libraries src/integrations/libraries/CommonHelper.sol:CommonHelper:$common_helper_address --libraries src/integrations/libraries/Keys.sol:Keys:$keys_address --libraries src/integrations/libraries/SharesHelper.sol:SharesHelper:$shares_helper_address --legacy --private-key $PRIVATE_KEY --rpc-url $RPC_URL src/integrations/libraries/RouteSetter.sol:RouteSetter)")
echo "deployed route setter to $route_setter_address"
orchestrator_helper_address=$(extract_deployed_address "$(forge create --libraries src/integrations/libraries/RouteReader.sol:RouteReader:$route_reader_address --libraries src/integrations/libraries/CommonHelper.sol:CommonHelper:$common_helper_address --libraries src/integrations/libraries/Keys.sol:Keys:$keys_address --libraries src/integrations/libraries/SharesHelper.sol:SharesHelper:$shares_helper_address --legacy --private-key $PRIVATE_KEY --rpc-url $RPC_URL src/integrations/libraries/OrchestratorHelper.sol:OrchestratorHelper)")
echo "deployed orchestrator helper to $orchestrator_helper_address"
gmxv2_keys_address=$(extract_deployed_address "$(forge create --verify --legacy --private-key $PRIVATE_KEY --rpc-url $RPC_URL src/integrations/GMXV2/libraries/GMXV2Keys.sol:GMXV2Keys)")
echo "deployed gmxv2 keys to $gmxv2_keys_address"
gmxv2_orchestrator_helper_address=$(extract_deployed_address "$(forge create --libraries src/integrations/libraries/CommonHelper.sol:CommonHelper:$common_helper_address --libraries src/integrations/GMXV2/libraries/GMXV2Keys.sol:GMXV2Keys:$gmxv2_keys_address --legacy --private-key $PRIVATE_KEY --rpc-url $RPC_URL src/integrations/GMXV2/libraries/GMXV2OrchestratorHelper.sol:GMXV2OrchestratorHelper)")
echo "deployed gmxv2 orchestrator helper to $gmxv2_orchestrator_helper_address"
gmxv2_order_utils_address=$(extract_deployed_address "$(forge create --verify --legacy --private-key $PRIVATE_KEY --rpc-url $RPC_URL src/integrations/GMXV2/libraries/OrderUtils.sol:OrderUtils)")
echo "deployed gmxv2 order utils to $gmxv2_order_utils_address"
gmxv2_route_helper_address=$(extract_deployed_address "$(forge create --libraries src/integrations/GMXV2/libraries/OrderUtils.sol:OrderUtils:$gmxv2_order_utils_address --libraries src/integrations/libraries/CommonHelper.sol:CommonHelper:$common_helper_address --libraries src/integrations/libraries/Keys.sol:Keys:$keys_address --libraries src/integrations/GMXV2/libraries/GMXV2Keys.sol:GMXV2Keys:$gmxv2_keys_address --legacy --private-key $PRIVATE_KEY --rpc-url $RPC_URL src/integrations/GMXV2/libraries/GMXV2RouteHelper.sol:GMXV2RouteHelper)")
echo "deployed gmxv2 route helper to $gmxv2_route_helper_address"

# Verification
forge verify-contract --watch --chain-id 42161 --compiler-version v0.8.19+commit.7dd6d404 --libraries src/integrations/libraries/Keys.sol:Keys:$keys_address --verifier-url https://api.arbiscan.io/api $common_helper_address src/integrations/libraries/CommonHelper.sol:CommonHelper
forge verify-contract --watch --chain-id 42161 --compiler-version v0.8.19+commit.7dd6d404 --libraries src/integrations/libraries/Keys.sol:Keys:$keys_address --libraries src/integrations/libraries/CommonHelper.sol:CommonHelper:$common_helper_address --libraries src/integrations/libraries/SharesHelper.sol:SharesHelper:$shares_helper_address --verifier-url https://api.arbiscan.io/api $route_reader_address src/integrations/libraries/RouteReader.sol:RouteReader
forge verify-contract --watch --chain-id 42161 --compiler-version v0.8.19+commit.7dd6d404 --libraries src/integrations/libraries/Keys.sol:Keys:$keys_address --libraries src/integrations/libraries/CommonHelper.sol:CommonHelper:$common_helper_address --libraries src/integrations/libraries/SharesHelper.sol:SharesHelper:$shares_helper_address --libraries src/integrations/libraries/RouteReader.sol:RouteReader:$route_reader_address --verifier-url https://api.arbiscan.io/api $route_setter_address src/integrations/libraries/RouteSetter.sol:RouteSetter
forge verify-contract --watch --chain-id 42161 --compiler-version v0.8.19+commit.7dd6d404 --libraries src/integrations/libraries/Keys.sol:Keys:$keys_address --libraries src/integrations/libraries/CommonHelper.sol:CommonHelper:$common_helper_address --libraries src/integrations/libraries/SharesHelper.sol:SharesHelper:$shares_helper_address --libraries src/integrations/libraries/RouteReader.sol:RouteReader:$route_reader_address --verifier-url https://api.arbiscan.io/api $orchestrator_helper_address src/integrations/libraries/OrchestratorHelper.sol:OrchestratorHelper
forge verify-contract --watch --chain-id 42161 --compiler-version v0.8.19+commit.7dd6d404 --libraries src/integrations/GMXV2/libraries/GMXV2Keys.sol:GMXV2Keys:$gmxv2_keys_address --libraries src/integrations/libraries/CommonHelper.sol:CommonHelper:$common_helper_address --verifier-url https://api.arbiscan.io/api $gmxv2_orchestrator_helper_address src/integrations/GMXV2/libraries/GMXV2OrchestratorHelper.sol:GMXV2OrchestratorHelper
forge verify-contract --watch --chain-id 42161 --compiler-version v0.8.19+commit.7dd6d404 --libraries src/integrations/libraries/Keys.sol:Keys:$keys_address --libraries src/integrations/GMXV2/libraries/GMXV2Keys.sol:GMXV2Keys:$gmxv2_keys_address --libraries src/integrations/libraries/CommonHelper.sol:CommonHelper:$common_helper_address --libraries src/integrations/GMXV2/libraries/OrderUtils.sol:OrderUtils:$gmxv2_order_utils_address --verifier-url https://api.arbiscan.io/api $gmxv2_route_helper_address src/integrations/GMXV2/libraries/GMXV2RouteHelper.sol:GMXV2RouteHelper

# Print variables
echo "Keys Address: $keys_address"
echo "Shares Helper Address: $shares_helper_address"
echo "Common Helper Address: $common_helper_address"
echo "Route Reader Address: $route_reader_address"
echo "Route Setter Address: $route_setter_address"
echo "Orchestrator Helper Address: $orchestrator_helper_address"
echo "GMXV2 Keys Address: $gmxv2_keys_address"
echo "GMXV2 Orchestrator Helper Address: $gmxv2_orchestrator_helper_address"
echo "GMXV2 Order Utils Address: $gmxv2_order_utils_address"
echo "GMXV2 Route Helper Address: $gmxv2_route_helper_address"

# Keys Address: 0xa9A725FA649093e7ab5b368EcA0fd5D7703fA6c6
# Shares Helper Address: 0x7B2D7d166Fd18449b90F8Af24cbfE6118ae2e10e
# Common Helper Address: 0x20C1E1e86611eF39EbbBe4e011C17400Aa5C0351
# Route Reader Address: 0x1A90e321D0D019383599936D45323C210dE5C12D
# Route Setter Address: 0x56BDB07eB4492beB272531A7E46E9aEEc961A540
# Orchestrator Helper Address: 0xE38CEAA21E5E0A3C0418DC0a520085a77231cCF5
# GMXV2 Keys Address: 0xbC730fF81eD4E1e85485f0703e35C0448Bc60aE5
# GMXV2 Orchestrator Helper Address: 0x5BAA0537c3B448aDFd53da5Bb0D23e552402B9EB
# GMXV2 Order Utils Address: 0x52daBB11490Df14911e82adC525C278379f39980
# GMXV2 Route Helper Address: 0x0f4a0d8fC9E499D876f6f7c2A8e4b8a1360B0c16