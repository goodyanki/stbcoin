# StableVault

Over-collateralized stablecoin MVP:
- Native ETH collateral vault
- STB mint / repay / withdraw
- Keeper-based liquidation
- Chainlink + TWAP oracle checks (with circuit breaker + demo mode)
- Backend indexer/API + React frontend

## Repo Layout
- `contracts/` Foundry contracts + scripts + tests
- `backend/` Node.js service (Express + Prisma + SQLite)
- `frontend/` React + Vite UI
- `docs/` test/security reports

## Prerequisites
- Node.js 20+
- npm
- Foundry (`forge`, `cast`, `anvil`)

## Quick Start (Recommended: Local Fork)
This is the easiest way to run everything end-to-end.

### 0) One-command bootstrap (recommended)
```bash
./scripts/dev_bootstrap.sh
```

This script will:
- start/reuse local anvil fork
- deploy contracts
- write `backend/.env` and `frontend/.env(.local)` automatically
- set local demo defaults (`demo mode`, `keeper key`, `start block`)

### 1) Install dependencies
```bash
cd /home/nick/stbcoin
cd backend && npm install
cd ../frontend && npm install
cd ../contracts && forge --version
```

### 2) Start Anvil (fork Sepolia)
Keep this terminal running:
```bash
anvil --fork-url "https://eth-sepolia.g.alchemy.com/v2/<YOUR_KEY>" --chain-id 31337
```

### 3) Configure and deploy contracts to local fork
```bash
cd /home/nick/stbcoin/contracts
cp .env.example .env
```

Edit `contracts/.env` (example):
```bash
PRIVATE_KEY=<anvil account private key>
RPC_URL=http://127.0.0.1:8545
CHAINLINK_ETH_USD=0x694AA1769357215DE4FAC081bf1f309aDC325306
KEEPER_ADDRESS=<optional>
ORACLE_PUBLISHER=<optional>
ENABLE_DEMO_MODE=true
DEMO_PRICE_E18=2500000000000000000000
```

Deploy:
```bash
set -a; source .env; set +a
forge script script/DeploySepolia.s.sol:DeploySepolia --rpc-url "$RPC_URL" --broadcast
```

Get deployed addresses from:
- `contracts/broadcast/DeploySepolia.s.sol/31337/run-latest.json`

### 4) Configure and run backend
```bash
cd /home/nick/stbcoin/backend
cp .env.example .env
```

Set these in `backend/.env`:
- `RPC_URL=http://127.0.0.1:8545`
- `CHAIN_ID=31337`
- `STABLE_VAULT_ADDRESS=<deployed vault>`
- `ORACLE_HUB_ADDRESS=<deployed oracle hub>`
- `TWAP_ORACLE_ADDRESS=<deployed twap>`
- `STB_TOKEN_ADDRESS=<deployed stb>`
- `KEEPER_PRIVATE_KEY=<anvil keeper key>`

Then start:
```bash
npx prisma generate
npx prisma migrate dev --name init
npm run dev
```

Backend runs on `http://127.0.0.1:8080`.

### 5) Configure and run frontend
Create `frontend/.env`:
```bash
VITE_STABLE_VAULT_ADDRESS=<deployed vault>
VITE_ORACLE_HUB_ADDRESS=<deployed oracle hub>
VITE_STB_TOKEN_ADDRESS=<deployed stb>
VITE_BACKEND_URL=http://127.0.0.1:8080
VITE_TARGET_CHAIN_ID=31337
VITE_RPC_URL=http://127.0.0.1:8545
```

Run:
```bash
cd /home/nick/stbcoin/frontend
npm run dev
```

Open `http://127.0.0.1:5173`.

## Sepolia Deployment (Optional)
If you want to deploy to Sepolia directly:

1. Set `contracts/.env` with Sepolia `RPC_URL` + funded `PRIVATE_KEY`.
2. Run:
```bash
cd /home/nick/stbcoin/contracts
set -a; source .env; set +a
forge script script/DeploySepolia.s.sol:DeploySepolia --rpc-url "$RPC_URL" --broadcast
```
3. Copy deployed addresses to `backend/.env` and `frontend/.env`.

## Useful API Endpoints
- `GET /health`
- `GET /v1/protocol/metrics`
- `GET /v1/vaults/:owner`
- `GET /v1/vaults?health=safe|warning|danger&limit=20`
- `GET /v1/liquidations?limit=20`
- `GET /v1/keeper/status`

## Test Commands
Contracts:
```bash
cd /home/nick/stbcoin/contracts
forge test
forge coverage
```

Backend:
```bash
cd /home/nick/stbcoin/backend
npm test
```

Frontend:
```bash
cd /home/nick/stbcoin/frontend
npm run test
npm run test:coverage
```

## Static Analysis
```bash
cd /home/nick/stbcoin/contracts
slither . 2>&1 | tee ../docs/slither-report.txt || true
slither . --json ../docs/slither-report.json || true
```

## Common Issues
- Price drop but `debt` does not change:
  - expected behavior: price move changes collateral ratio, not debt principal
  - debt changes only after `repay` or `liquidate`
  - check `GET /v1/liquidations?limit=20` and `GET /v1/keeper/status`
- `Connection refused` when deploy/call:
  - check Anvil is running on `127.0.0.1:8545`
  - `set -a; source .env; set +a` before using `$RPC_URL`
- Backend `network changed: 31337 => 11155111`:
  - ensure backend `RPC_URL` and `CHAIN_ID` are both for the same chain
- `eth_getLogs` free-tier block range errors:
  - use local fork RPC for backend indexing, or reduce range / upgrade RPC plan
