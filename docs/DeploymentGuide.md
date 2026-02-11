# StableVault Deployment Guide 

This guide provides a complete deployment and bring-up flow for the current repository.
It is based on the validated local reproduction process and is intended for end-to-end setup:
- local chain (Anvil fork)
- contract deployment
- backend/frontend configuration
- runtime verification
- manual liquidation / bad debt checks

## 1. Prerequisites

- Foundry installed (`anvil`, `forge`, `cast`)
- Node.js + npm installed
- Repository path: `/home/nick/stbcoin`

Recommended: use separate terminals for each service to avoid env contamination.

## 2. Start Local Fork Chain

In terminal A:

```bash
anvil --fork-url "https://eth-sepolia.g.alchemy.com/v2/<YOUR_KEY>" --chain-id 31337
```

Default Anvil accounts used in this guide:
- `keeper`: account `0` (`0xf39Fd6e51...`)
- `owner`: account `1` (`0x70997970...`)

## 3. Deployment Role Convention

For this project setup:
- `owner = account 1`
- `keeper = account 0`
- business contracts are deployed to the local fork (`31337`)
- oracle source is forked Chainlink, optionally overridden by Demo Mode

## 4. Deploy Contracts to the Local Fork

In terminal B:

```bash
cd /home/nick/stbcoin/contracts
set -a && source ./.env && set +a
forge script script/DeploySepolia.s.sol:DeploySepolia --rpc-url "$RPC_URL" --broadcast
```

Read deployed addresses:

```bash
jq -r '.transactions[] | select(.transactionType=="CREATE") | "\(.contractName) \(.contractAddress)"' \
  /home/nick/stbcoin/contracts/broadcast/DeploySepolia.s.sol/31337/run-latest.json
```

Read deployment block:

```bash
jq -r '.receipts[0].blockNumber' \
  /home/nick/stbcoin/contracts/broadcast/DeploySepolia.s.sol/31337/run-latest.json
```

Important: if Anvil is restarted, chain state resets. You must redeploy and update env addresses again.

## 5. Update Environment Variables

### Backend (`backend/.env`)

Set:
- `RPC_URL="http://127.0.0.1:8545"`
- `CHAIN_ID=31337`
- `START_BLOCK=<deployment block>`
- `STABLE_VAULT_ADDRESS=<deployed>`
- `ORACLE_HUB_ADDRESS=<deployed>`
- `TWAP_ORACLE_ADDRESS=<deployed>`
- `STB_TOKEN_ADDRESS=<deployed>`
- `KEEPER_PRIVATE_KEY=<anvil account 0 private key>`

### Frontend (`frontend/.env`)

Set:
- `VITE_STABLE_VAULT_ADDRESS=<deployed>`
- `VITE_ORACLE_HUB_ADDRESS=<deployed>`
- `VITE_STB_TOKEN_ADDRESS=<deployed>`
- `VITE_BACKEND_URL=http://localhost:8080`

### Frontend local chain (`frontend/.env.local`)

Set:
- `VITE_RPC_URL=http://127.0.0.1:8545`
- `VITE_TARGET_CHAIN_ID=31337`

## 6. Start Backend and Frontend

Terminal C (backend):

```bash
cd /home/nick/stbcoin/backend
npm run dev
```

Terminal D (frontend):

```bash
cd /home/nick/stbcoin/frontend
npm run dev
```

## 7. Wallet Setup

In MetaMask, connect chain `31337`.

Use owner wallet (account 1 key) for admin/demo actions.
Use keeper wallet (account 0 key) for keeper-side manual liquidation tests.

## 8. Frontend Functional Checks

1. `Deposit`: deposit `12` ETH and confirm collateral increases.
2. `Mint`: mint `10000` STB and confirm debt increases.
3. `Repay`: repay full or partial debt and confirm debt decreases.
4. `Withdraw`: withdraw collateral (expected to fail if vault health is unsafe).
5. `Demo Mode`: as owner, lower demo price and observe health transition (`Safe` -> `Danger`).

## 9. CLI Checks (for scenarios hard to reproduce from UI)

In terminal B:

```bash
cd /home/nick/stbcoin/contracts
set -a && source ./.env && set +a

VAULT=<STABLE_VAULT_ADDRESS>
HUB=<ORACLE_HUB_ADDRESS>
STB=<STB_TOKEN_ADDRESS>
OWNER=0x70997970C51812dc3A010C7d01b50e0d17dc79C8
KEEPER=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
OWNER_PK=<owner private key>
KEEPER_PK=<keeper private key>
RPC=http://127.0.0.1:8545
```

### 9.1 Query vault/risk state

```bash
cast call $VAULT "getVault(address)(uint256,uint256,uint256,uint256,uint256,uint256)" $OWNER --rpc-url $RPC
cast call $VAULT "getCollateralRatioBps(address)(uint256)" $OWNER --rpc-url $RPC
cast call $VAULT "isLiquidatable(address)(bool)" $OWNER --rpc-url $RPC
cast call $HUB "getPriceStatus()(uint256,uint256,uint256,uint256,uint256,bool)" --rpc-url $RPC
```

### 9.2 Manual liquidation flow

Transfer STB from owner to keeper:

```bash
cast send $STB "transfer(address,uint256)" $KEEPER "$(cast to-wei 2000 ether)" --private-key $OWNER_PK --rpc-url $RPC
```

Keeper approves vault:

```bash
cast send $STB "approve(address,uint256)" $VAULT "$(cast to-wei 2000 ether)" --private-key $KEEPER_PK --rpc-url $RPC
```

Keeper liquidates owner vault:

```bash
cast send $VAULT "liquidate(address,uint256)" $OWNER "$(cast to-wei 1000 ether)" --private-key $KEEPER_PK --rpc-url $RPC
```

### 9.3 Force bad debt for UI verification

```bash
cast send $VAULT "setDemoPrice(uint256)" "$(cast to-wei 27 ether)" --private-key $OWNER_PK --rpc-url $RPC
cast send $VAULT "liquidate(address,uint256)" $OWNER "$(cast to-wei 1000 ether)" --private-key $KEEPER_PK --rpc-url $RPC
cast call $VAULT "getSystemBadDebt()(uint256)" --rpc-url $RPC
```

If returned value is `> 0`, frontend `Protocol Bad Debt` should become non-zero.

### 9.4 Cover bad debt (owner)

```bash
cast call $VAULT "protocolReserveStb()(uint256)" --rpc-url $RPC
cast call $VAULT "getSystemBadDebt()(uint256)" --rpc-url $RPC
cast send $VAULT "coverBadDebt(uint256)" "$(cast to-wei 1 ether)" --private-key $OWNER_PK --rpc-url $RPC
```

## 10. Backend API Verification

```bash
curl -s http://127.0.0.1:8080/health
curl -s http://127.0.0.1:8080/v1/protocol/metrics
curl -s http://127.0.0.1:8080/v1/oracle/status
curl -s http://127.0.0.1:8080/v1/keeper/status
curl -s http://127.0.0.1:8080/v1/vaults/$OWNER
curl -s "http://127.0.0.1:8080/v1/liquidations?limit=20"
```

## 11. Common Issues

### 11.1 `BAD_DATA value: 0x`
- Cause: contract addresses no longer exist in current Anvil session (after restart).
- Fix: redeploy and update `backend/.env` + `frontend/.env`.

### 11.2 `eth_getLogs ... Free tier 10 block range`
- Cause: fork upstream RPC (e.g. Alchemy free tier) limits log range.
- Fix: set `START_BLOCK` to deployment block to minimize backfill range.

### 11.3 `Read-only mode` in demo panel
- Cause: connected wallet is not contract owner.
- Fix: switch wallet to owner (account 1).

### 11.4 `keeper signer unavailable`
- Cause: `KEEPER_PRIVATE_KEY` is missing in backend env.
- Fix: set keeper key in `backend/.env`.

## 12. Recommended Restart Order

1. Start Anvil fork  
2. Deploy contracts  
3. Write new addresses to env files  
4. Start backend  
5. Start frontend  
6. Test demo mode with owner wallet  
7. Test liquidation with keeper / auto-keeper  
