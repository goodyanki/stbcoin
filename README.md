# StableVault: Over-Collateralized Stablecoin MVP

StableVault is a Sepolia-first stablecoin protocol MVP with:
- WETH collateral vaults
- STB stablecoin mint/repay flows
- Automated keeper liquidation
- Chainlink + TWAP oracle checks with circuit breaker
- Node/Express backend indexer + API
- React frontend integrated with real on-chain actions

## Repository Structure

- `contracts/`: Foundry Solidity workspace
- `backend/`: Node + Express + Prisma + SQLite services
- `frontend/`: React + Vite UI
- `.github/workflows/ci.yml`: CI pipeline for contracts/backend/frontend

## Prerequisites

- Node.js 20+
- npm
- Foundry (`forge`, `cast`, `anvil`)

## 1) Deploy Contracts (Sepolia)

Create env for Foundry:

```bash
cd contracts
cp .env.example .env
```

Set:
- `PRIVATE_KEY`
- `RPC_URL`
- `CHAINLINK_ETH_USD`
- `WETH_ADDRESS`
- `KEEPER_ADDRESS` (optional, defaults to owner)
- `ORACLE_PUBLISHER` (optional, defaults to keeper)
- `ENABLE_DEMO_MODE` / `DEMO_PRICE_E18` (optional)

Run:

```bash
forge script script/DeploySepolia.s.sol:DeploySepolia \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify
```

Save deployed addresses for backend/frontend envs.

## 2) Backend Setup

```bash
cd backend
cp .env.example .env
npm install
npx prisma generate
npx prisma migrate dev --name init
npm run dev
```

Backend endpoints:
- `GET /health`
- `GET /v1/protocol/metrics`
- `GET /v1/oracle/status`
- `GET /v1/vaults/:owner`
- `GET /v1/vaults?health=safe|warning|danger&limit=20`
- `GET /v1/liquidations?limit=20`
- `GET /v1/keeper/status`

Keeper env (optional tuning):
- `KEEPER_MAX_ATTEMPTS` (default `2`)
- `KEEPER_BACKOFF_MS` (default `500`)

## 3) Frontend Setup

Create `frontend/.env`:

```bash
VITE_STABLE_VAULT_ADDRESS=0x...
VITE_ORACLE_HUB_ADDRESS=0x...
VITE_STB_TOKEN_ADDRESS=0x...
VITE_WETH_ADDRESS=0x...
VITE_BACKEND_URL=http://localhost:8080
```

Run:

```bash
cd frontend
npm install
npm run dev
```

## 4) Demo Acceptance Flow

1. Connect Sepolia wallet
2. Deposit WETH and mint STB
3. Enable demo mode and lower price from UI (owner wallet)
4. Trigger liquidation flow on unhealthy vault
5. Confirm backend liquidation record and updated protocol metrics

## 5) Scripted Sepolia Smoke

Add extra backend env values:

```bash
SMOKE_OWNER_PRIVATE_KEY=0x...
SMOKE_KEEPER_PRIVATE_KEY=0x...
SMOKE_DEPOSIT_WETH=0.2
SMOKE_MINT_STB=180
SMOKE_LIQUIDATE_STB=50
SMOKE_DEMO_PRICE=1200
```

Run:

```bash
cd backend
npm run smoke:sepolia
```

This script executes `deposit -> mint -> demo price down -> liquidation -> metrics print`.

## Testing

Contracts:

```bash
cd contracts
forge test -vvv
```

Backend:

```bash
cd backend
npm test
```

Frontend build:

```bash
cd frontend
npm run build
```

## Docker Compose

```bash
docker compose up --build
```

Requires valid env values for backend and frontend contract addresses.
