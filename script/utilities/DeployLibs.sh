#!/bin/bash

# Prompt user for input
read -p "Enter your private key: " PRIVATE_KEY
read -p "Enter your RPC URL: " RPC_URL

# Function to extract deployed address
extract_deployed_address() {
    echo "$1" | grep "Deployed to:" | awk '{print $3}'
}

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
forge verify-contract --watch --chain-id 42161 --compiler-version v0.8.23+commit.f704f362 --libraries src/integrations/libraries/Keys.sol:Keys:$keys_address --verifier-url https://api.arbiscan.io/api $common_helper_address src/integrations/libraries/CommonHelper.sol:CommonHelper
forge verify-contract --watch --chain-id 42161 --compiler-version v0.8.23+commit.f704f362 --libraries src/integrations/libraries/Keys.sol:Keys:$keys_address --libraries src/integrations/libraries/CommonHelper.sol:CommonHelper:$common_helper_address --libraries src/integrations/libraries/SharesHelper.sol:SharesHelper:$shares_helper_address --verifier-url https://api.arbiscan.io/api $route_reader_address src/integrations/libraries/RouteReader.sol:RouteReader
forge verify-contract --watch --chain-id 42161 --compiler-version v0.8.23+commit.f704f362 --libraries src/integrations/libraries/Keys.sol:Keys:$keys_address --libraries src/integrations/libraries/CommonHelper.sol:CommonHelper:$common_helper_address --libraries src/integrations/libraries/SharesHelper.sol:SharesHelper:$shares_helper_address --libraries src/integrations/libraries/RouteReader.sol:RouteReader:$route_reader_address --verifier-url https://api.arbiscan.io/api $route_setter_address src/integrations/libraries/RouteSetter.sol:RouteSetter
forge verify-contract --watch --chain-id 42161 --compiler-version v0.8.23+commit.f704f362 --libraries src/integrations/libraries/Keys.sol:Keys:$keys_address --libraries src/integrations/libraries/CommonHelper.sol:CommonHelper:$common_helper_address --libraries src/integrations/libraries/SharesHelper.sol:SharesHelper:$shares_helper_address --libraries src/integrations/libraries/RouteReader.sol:RouteReader:$route_reader_address --verifier-url https://api.arbiscan.io/api $orchestrator_helper_address src/integrations/libraries/OrchestratorHelper.sol:OrchestratorHelper
forge verify-contract --watch --chain-id 42161 --compiler-version v0.8.23+commit.f704f362 --libraries src/integrations/GMXV2/libraries/GMXV2Keys.sol:GMXV2Keys:$gmxv2_keys_address --libraries src/integrations/libraries/CommonHelper.sol:CommonHelper:$common_helper_address --verifier-url https://api.arbiscan.io/api $gmxv2_orchestrator_helper_address src/integrations/GMXV2/libraries/GMXV2OrchestratorHelper.sol:GMXV2OrchestratorHelper
forge verify-contract --watch --chain-id 42161 --compiler-version v0.8.23+commit.f704f362 --libraries src/integrations/libraries/Keys.sol:Keys:$keys_address --libraries src/integrations/GMXV2/libraries/GMXV2Keys.sol:GMXV2Keys:$gmxv2_keys_address --libraries src/integrations/libraries/CommonHelper.sol:CommonHelper:$common_helper_address --libraries src/integrations/GMXV2/libraries/OrderUtils.sol:OrderUtils:$gmxv2_order_utils_address --verifier-url https://api.arbiscan.io/api $gmxv2_route_helper_address src/integrations/GMXV2/libraries/GMXV2RouteHelper.sol:GMXV2RouteHelper

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

# Keys Address: 0x2503e378fEE8da4a78eA0BE45e70DB286A069Ff8
# Shares Helper Address: 0x5012b05F611f9498a3fC6A80013A9B6781F0bBBd
# Common Helper Address: 0x67bf4c18ecF000328857030a131009e9c44929F0
# Route Reader Address: 0xBA0a4ad8a635F3fE38EDbeAfdB53797a70D96DE9
# Route Setter Address: 0x7dD08E239075A108b09b85671F6C8DaDFA740410
# Orchestrator Helper Address: 0x98fe47970e7C401244EeC8af39A3668BC2143E9B
# GMXV2 Keys Address: 0xfcFE1B3417d4d6F6E8a95E05d0243a09D5993A08
# GMXV2 Orchestrator Helper Address: 0xC2EE029E0fCA5f905B4D8C839f27E47c3EB5519E
# GMXV2 Order Utils Address: 0x812386c417b79A5e79F614F661a5984b70249861
# GMXV2 Route Helper Address: 0x71256D7d96521Dd003A9299e233D254ca804d41a