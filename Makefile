-include .env

# deploy scripts
deploy-to-anvil:; forge script script/DeployCollectiveCore.s.sol --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_ACCOUNT_ONE) --broadcast

deploy-to-avalanche:; forge script script/DeployCollectiveCore.s.sol --rpc-url $(AVALANCHE_RPC_URL) --private-key $(ANVIL_ACCOUNT_ONE) --broadcast
deploy-to-optimism:; forge script script/DeployCollectiveCore.s.sol --rpc-url $(OPTIMISM_RPC_URL) --private-key $(ANVIL_ACCOUNT_ONE) --broadcast
deploy-to-polygon:; forge script script/DeployCollectiveCore.s.sol --rpc-url $(POLYGON_RPC_URL) --private-key $(ANVIL_ACCOUNT_ONE) --broadcast

# interactions script

approve-token:; forge script script/Interactions/ApproveTokens.s.sol --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_ACCOUNT_ONE) --broadcast

break-savings:; forge script script/Interactions/BreakSavings.s.sol --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_ACCOUNT_ONE) --broadcast

contribute-to-group:; forge script script/Interactions/ContributeToGroupSavings.s.sol --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_ACCOUNT_ONE) --broadcast

create-group:; forge script script/Interactions/CreateGroupSavings.s.sol --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_ACCOUNT_ONE) --broadcast

dispatch-group-funds:; forge script script/Interactions/DispatchGroupFunds.s.sol --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_ACCOUNT_ONE) --broadcast

get-recently-deployed:; forge script script/Interactions/GetAllRecentlyDeployed.s.sol --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_ACCOUNT_ONE) --broadcast

mint-funds:; forge script script/Interactions/MintFundsToAddress.s.sol --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_ACCOUNT_ONE) --broadcast

start-savings:; forge script script/Interactions/StartSavings.s.sol --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_ACCOUNT_ONE) --broadcast

top-up-save:; forge script script/Interactions/TopUpSavings.s.sol --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_ACCOUNT_ONE) --broadcast

update-addresses:; forge script script/Interactions/UpdateAddresses.s.sol --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_ACCOUNT_ONE) --broadcast

withdraw-contribution:; forge script script/Interactions/WithdrawContribution.s.sol --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_ACCOUNT_ONE) --broadcast

withdraw-savings:; forge script script/Interactions/WithdrawSavings.s.sol --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_ACCOUNT_ONE) --broadcast

get-user-info:; forge script script/Interactions/UserSavingsInfo.s.sol --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_ACCOUNT_ONE) --broadcast



