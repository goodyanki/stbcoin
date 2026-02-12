#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTRACTS_DIR="$ROOT_DIR/contracts"
CONTRACTS_ENV="$CONTRACTS_DIR/.env"
BACKEND_ENV="$ROOT_DIR/backend/.env"
FRONTEND_ENV="$ROOT_DIR/frontend/.env"
FRONTEND_LOCAL_ENV="$ROOT_DIR/frontend/.env.local"

FORK_URL="${1:-${FORK_URL:-https://eth-mainnet.g.alchemy.com/v2/YOUR_ALCHEMY_KEY}}"
CHAIN_ID="${CHAIN_ID:-31337}"
RPC_PORT="${RPC_PORT:-8545}"
LOCAL_RPC_URL="http://127.0.0.1:${RPC_PORT}"
ANVIL_LOG="${ANVIL_LOG:-/tmp/stbcoin-anvil.log}"
PORT="${PORT:-8080}"
INDEXER_BLOCK_RANGE="${INDEXER_BLOCK_RANGE:-2000}"

# Mainnet feed for local fork; override if needed.
CHAINLINK_ETH_USD="${CHAINLINK_ETH_USD:-0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419}"

DEFAULT_DEPLOYER_PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
DEFAULT_KEEPER_PRIVATE_KEY="0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"

DEPLOYER_PRIVATE_KEY="${PRIVATE_KEY:-$DEFAULT_DEPLOYER_PRIVATE_KEY}"
KEEPER_PRIVATE_KEY="${KEEPER_PRIVATE_KEY:-$DEFAULT_KEEPER_PRIVATE_KEY}"
DEMO_PRICE_E18="${DEMO_PRICE_E18:-2500000000000000000000}"
ENABLE_DEMO_MODE="${ENABLE_DEMO_MODE:-true}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

upsert_env() {
  local file="$1"
  local key="$2"
  local value="$3"
  touch "$file"
  if grep -qE "^${key}=" "$file"; then
    sed -i "s#^${key}=.*#${key}=${value}#" "$file"
  else
    echo "${key}=${value}" >> "$file"
  fi
}

ensure_env_file() {
  local env_file="$1"
  local template="$2"
  if [[ ! -f "$env_file" ]]; then
    cp "$template" "$env_file"
  fi
}

start_or_reuse_anvil() {
  if cast chain-id --rpc-url "$LOCAL_RPC_URL" >/dev/null 2>&1; then
    echo "[info] Reusing existing anvil at $LOCAL_RPC_URL"
    return
  fi

  echo "[info] Starting anvil fork..."
  nohup anvil \
    --fork-url "$FORK_URL" \
    --chain-id "$CHAIN_ID" \
    --port "$RPC_PORT" \
    >"$ANVIL_LOG" 2>&1 &

  local i
  for i in $(seq 1 30); do
    if cast chain-id --rpc-url "$LOCAL_RPC_URL" >/dev/null 2>&1; then
      echo "[info] Anvil is ready at $LOCAL_RPC_URL"
      return
    fi
    sleep 1
  done

  echo "[error] anvil did not become ready. Check log: $ANVIL_LOG" >&2
  exit 1
}

need_cmd anvil
need_cmd cast
need_cmd forge
need_cmd node

DEPLOYER_ADDRESS="$(cast wallet address --private-key "$DEPLOYER_PRIVATE_KEY")"
KEEPER_ADDRESS="$(cast wallet address --private-key "$KEEPER_PRIVATE_KEY")"

ensure_env_file "$CONTRACTS_ENV" "$CONTRACTS_DIR/.env.example"
ensure_env_file "$BACKEND_ENV" "$ROOT_DIR/backend/.env.example"
ensure_env_file "$FRONTEND_ENV" "$ROOT_DIR/frontend/.env.example"
ensure_env_file "$FRONTEND_LOCAL_ENV" "$ROOT_DIR/frontend/.env.example"

upsert_env "$CONTRACTS_ENV" "PRIVATE_KEY" "$DEPLOYER_PRIVATE_KEY"
upsert_env "$CONTRACTS_ENV" "RPC_URL" "$LOCAL_RPC_URL"
upsert_env "$CONTRACTS_ENV" "CHAINLINK_ETH_USD" "$CHAINLINK_ETH_USD"
upsert_env "$CONTRACTS_ENV" "KEEPER_ADDRESS" "$KEEPER_ADDRESS"
upsert_env "$CONTRACTS_ENV" "ORACLE_PUBLISHER" "$KEEPER_ADDRESS"
upsert_env "$CONTRACTS_ENV" "ENABLE_DEMO_MODE" "$ENABLE_DEMO_MODE"
upsert_env "$CONTRACTS_ENV" "DEMO_PRICE_E18" "$DEMO_PRICE_E18"

start_or_reuse_anvil

CURRENT_CHAIN_ID="$(cast chain-id --rpc-url "$LOCAL_RPC_URL")"
if [[ "$CURRENT_CHAIN_ID" != "$CHAIN_ID" ]]; then
  echo "[error] running chain id ($CURRENT_CHAIN_ID) != expected CHAIN_ID ($CHAIN_ID)" >&2
  echo "        stop current anvil and rerun script with correct CHAIN_ID" >&2
  exit 1
fi

echo "[info] Deploying contracts..."
cd "$CONTRACTS_DIR"
set -a
. "$CONTRACTS_ENV"
set +a
forge script script/DeploySepolia.s.sol:DeploySepolia --rpc-url "$RPC_URL" --broadcast

RUN_FILE="$CONTRACTS_DIR/broadcast/DeploySepolia.s.sol/${CHAIN_ID}/run-latest.json"
if [[ ! -f "$RUN_FILE" ]]; then
  echo "[error] run-latest.json not found: $RUN_FILE" >&2
  exit 1
fi

eval "$(
  node - "$RUN_FILE" <<'NODE'
const fs = require("fs");
const runFile = process.argv[2];
const payload = JSON.parse(fs.readFileSync(runFile, "utf8"));

const transactions = payload.transactions ?? [];
const receipts = payload.receipts ?? [];

const lastCreate = (name) => {
  const matched = transactions.filter(
    (tx) => tx.transactionType === "CREATE" && tx.contractName === name
  );
  return matched.length > 0 ? matched[matched.length - 1].contractAddress : "";
};

const rawBlock = receipts.length > 0 ? String(receipts[0].blockNumber ?? "0") : "0";
const startBlock = rawBlock.startsWith("0x")
  ? BigInt(rawBlock).toString()
  : BigInt(rawBlock || "0").toString();

const values = {
  STB_TOKEN: lastCreate("STBToken"),
  TWAP_ORACLE: lastCreate("TwapOracle"),
  ORACLE_HUB: lastCreate("OracleHub"),
  STABLE_VAULT: lastCreate("StableVault"),
  START_BLOCK: startBlock
};

for (const [key, value] of Object.entries(values)) {
  console.log(`${key}=${value}`);
}
NODE
)"

if [[ -z "$STB_TOKEN" || -z "$TWAP_ORACLE" || -z "$ORACLE_HUB" || -z "$STABLE_VAULT" || -z "$START_BLOCK" ]]; then
  echo "[error] Failed to parse deployed contract addresses from $RUN_FILE" >&2
  exit 1
fi

echo "[info] Updating backend/frontend env files..."
upsert_env "$BACKEND_ENV" "PORT" "$PORT"
upsert_env "$BACKEND_ENV" "RPC_URL" "\"$LOCAL_RPC_URL\""
upsert_env "$BACKEND_ENV" "CHAIN_ID" "$CHAIN_ID"
upsert_env "$BACKEND_ENV" "START_BLOCK" "$START_BLOCK"
upsert_env "$BACKEND_ENV" "STABLE_VAULT_ADDRESS" "\"$STABLE_VAULT\""
upsert_env "$BACKEND_ENV" "ORACLE_HUB_ADDRESS" "\"$ORACLE_HUB\""
upsert_env "$BACKEND_ENV" "TWAP_ORACLE_ADDRESS" "\"$TWAP_ORACLE\""
upsert_env "$BACKEND_ENV" "STB_TOKEN_ADDRESS" "\"$STB_TOKEN\""
upsert_env "$BACKEND_ENV" "KEEPER_PRIVATE_KEY" "\"$KEEPER_PRIVATE_KEY\""
upsert_env "$BACKEND_ENV" "KEEPER_AUTO_FUND_ENABLED" "true"
upsert_env "$BACKEND_ENV" "INDEXER_BLOCK_RANGE" "$INDEXER_BLOCK_RANGE"

upsert_env "$FRONTEND_ENV" "VITE_STABLE_VAULT_ADDRESS" "$STABLE_VAULT"
upsert_env "$FRONTEND_ENV" "VITE_ORACLE_HUB_ADDRESS" "$ORACLE_HUB"
upsert_env "$FRONTEND_ENV" "VITE_STB_TOKEN_ADDRESS" "$STB_TOKEN"
upsert_env "$FRONTEND_ENV" "VITE_BACKEND_URL" "http://localhost:8080"

upsert_env "$FRONTEND_LOCAL_ENV" "VITE_RPC_URL" "$LOCAL_RPC_URL"
upsert_env "$FRONTEND_LOCAL_ENV" "VITE_TARGET_CHAIN_ID" "$CHAIN_ID"

echo
echo "[ok] Done."
echo "RPC:            $LOCAL_RPC_URL"
echo "StableVault:    $STABLE_VAULT"
echo "OracleHub:      $ORACLE_HUB"
echo "TwapOracle:     $TWAP_ORACLE"
echo "STBToken:       $STB_TOKEN"
echo "START_BLOCK:    $START_BLOCK"
echo "Deployer:       $DEPLOYER_ADDRESS"
echo "Keeper:         $KEEPER_ADDRESS"
echo "Keeper PK:      $KEEPER_PRIVATE_KEY"
echo "AutoFund:       true"
echo
echo "Next:"
echo "  cd $ROOT_DIR/backend  && npm run dev"
echo "  cd $ROOT_DIR/frontend && npm run dev"
