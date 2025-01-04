-include .env

.PHONY: all test deploy build

build :; forge build

test :; forge test -vvvvv

install :; forge install cyfrin/foundry-devops@0.2.3 --no-commit && forge install smartcontractkit/chainlink@v2.18.0 --no-commit && forge install foundry-rs/forge-std@v1.9.4 --no-commit && forge install transmissions11/solmate@v6 --no-commit

deploy-sepolia :
	@forge script scripts/DeployRaffle.s.sol:DeployRaffle --rpc-url ${SEPOLIA_RPC_URL} --account myaccount --broadcast --verify --etherscan-api-key ${ETHERSCAN_API_KEY} -vvvvv
