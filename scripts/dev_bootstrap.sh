#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTRACTS_DIR="$ROOT_DIR/contracts"
BACKEND_ENV="$ROOT_DIR/backend/.env"
FRONTEND_ENV="$ROOT_DIR/frontend/.env"
FRONTEND_LOCAL_ENV="$ROOT_DIR/frontend/.env.local"

FORK_URL="${1:-${FORK_URL:-https://eth-mainnet.g.alchemy.com/v2/U6jYIv7oQtZdCPG8XHpUP}}"
CHAIN_ID="${CHAIN_ID:-31337}"
RPC_PORT="${RPC_PORT:-8545}"
LOCAL_RPC_URL="http://127.0.0.1:${RPC_PORT}"
ANVIL_LOG="${ANVIL_LOG:-/tmp/stbcoin-anvil.log}"

# Mainnet feed and WETH; override if needed.
CHAINLINK_ETH_USD="${CHAINLINK_ETH_USD:-0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419}"
WETH_ADDRESS="${WETH_ADDRESS:-0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2}"

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
need_cmd jq

if [[ ! -f "$CONTRACTS_DIR/.env" ]]; then
  cp "$CONTRACTS_DIR/.env.example" "$CONTRACTS_DIR/.env"
fi

upsert_env "$CONTRACTS_DIR/.env" "RPC_URL" "$LOCAL_RPC_URL"
upsert_env "$CONTRACTS_DIR/.env" "CHAINLINK_ETH_USD" "$CHAINLINK_ETH_USD"
upsert_env "$CONTRACTS_DIR/.env" "WETH_ADDRESS" "$WETH_ADDRESS"

start_or_reuse_anvil

echo "[info] Deploying contracts..."
cd "$CONTRACTS_DIR"
set -a
. ./.env
set +a
forge script script/DeploySepolia.s.sol:DeploySepolia --rpc-url "$RPC_URL" --broadcast

RUN_FILE="$CONTRACTS_DIR/broadcast/DeploySepolia.s.sol/31337/run-latest.json"
if [[ ! -f "$RUN_FILE" ]]; then
  echo "[error] run-latest.json not found: $RUN_FILE" >&2
  exit 1
fi

STB_TOKEN="$(jq -r '.transactions[] | select(.transactionType=="CREATE" and .contractName=="STBToken") | .contractAddress' "$RUN_FILE" | tail -n1)"
TWAP_ORACLE="$(jq -r '.transactions[] | select(.transactionType=="CREATE" and .contractName=="TwapOracle") | .contractAddress' "$RUN_FILE" | tail -n1)"
ORACLE_HUB="$(jq -r '.transactions[] | select(.transactionType=="CREATE" and .contractName=="OracleHub") | .contractAddress' "$RUN_FILE" | tail -n1)"
STABLE_VAULT="$(jq -r '.transactions[] | select(.transactionType=="CREATE" and .contractName=="StableVault") | .contractAddress' "$RUN_FILE" | tail -n1)"

if [[ -z "$STB_TOKEN" || -z "$TWAP_ORACLE" || -z "$ORACLE_HUB" || -z "$STABLE_VAULT" ]]; then
  echo "[error] Failed to parse deployed contract addresses from $RUN_FILE" >&2
  exit 1
fi

echo "[info] Updating backend/frontend env files..."
upsert_env "$BACKEND_ENV" "RPC_URL" "\"$LOCAL_RPC_URL\""
upsert_env "$BACKEND_ENV" "CHAIN_ID" "$CHAIN_ID"
upsert_env "$BACKEND_ENV" "STABLE_VAULT_ADDRESS" "\"$STABLE_VAULT\""
upsert_env "$BACKEND_ENV" "ORACLE_HUB_ADDRESS" "\"$ORACLE_HUB\""
upsert_env "$BACKEND_ENV" "TWAP_ORACLE_ADDRESS" "\"$TWAP_ORACLE\""
upsert_env "$BACKEND_ENV" "STB_TOKEN_ADDRESS" "\"$STB_TOKEN\""

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
echo
echo "Next:"
echo "  cd $ROOT_DIR/backend  && npm run dev"
echo "  cd $ROOT_DIR/frontend && npm run dev"
