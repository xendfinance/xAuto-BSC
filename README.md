## DOCUMENTATION

Binance Smart Chain xAuto is an automated yield aggregator on Binance Smart Chain designed to automatically seek the best yield from DeFi protocols by automatically shifting funds across  protocols to the protocol with the highest yield. 

This ensures that users don’t have to have to manually check for protocols with the highest APYs. Our smart contracts perform all these operations automatically.

We are using 4 lending protocols on Binance Smart Chain mainnet(Fulcrum, Fortube , Venus and Alpaca). Our protocol design pattern allows us to dynamically add new protocols without breaking the original design.

## Binance Smart Chain xAuto - Smart Contract Operations:

![Operation_img](https://github.com/xendfinance/BSC-earn/blob/main/operations.png)

### 1. Deposit
* Selects lending provider
Gets APYs from lending protocols and selects max APY from them.
Sets a new lending provider with it.
*Withdraws all token balances from lending protocols and supplies them to the new provider( lending protocol with max APY).

### 2. Withdraw
* Checks balance
If the balance is enough, withdraw the supported token amount.
* In other cases, if it isn’t enough, withdraw the deficit amount from other lending protocols and send the amount requested by the investor to the investor 

### 3. Rebalance
* Selects a lending provider with max APY and withdraws balances from other lending protocols and then supplies the withdrawn token to selected lending provider with max APY

## Fork mainnet for testing

ganache-cli -f https://bsc.getblock.io/mainnet/?api_key=API_KEY -m "hidden moral pulp timber famous opinion melt any praise keen tissue aware" -l 100000000 -i 1 -u 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56 -u 0x468c0cfae487a9de23e20d0b29a2835dc058cdf7 -u 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d -u 0x5a52e96bacdabb82fd05763e25335261b270efcb -u 0x55d398326f99059fF775485246999027B3197955 -u 0xd6216fc19db775df9774a6e33526131da7d19a2c --allowUnlimitedContractSize

## Deployed Contracts
Visit https://docs.xend.finance/contracts/registry to see smart contract addresses