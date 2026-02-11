#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." >/dev/null 2>&1 && pwd)"
cd "${REPO_ROOT}/pyano"

RPC_URL="${RPC_URL:-http://127.0.0.1:8545}"
PRIVATE_KEY="${PRIVATE_KEY:-}"
FEED_ADDRESS="${FEED_ADDRESS:-0x694AA1769357215DE4FAC081bf1f309aDC325306}"
MAX_AGE="${MAX_AGE:-3600}"
MAX_CHANGE_BPS="${MAX_CHANGE_BPS:-0}"
MCR="${MCR:-1500000000000000000}" # 150%
MINT_FEE_BPS="${MINT_FEE_BPS:-50}"
REPAY_FEE_BPS="${REPAY_FEE_BPS:-0}"
DEBT_CAP_PER_VAULT="${DEBT_CAP_PER_VAULT:-0}"
GLOBAL_DEBT_CAP="${GLOBAL_DEBT_CAP:-0}"
LIQ_PENALTY_BPS="${LIQ_PENALTY_BPS:-500}"

if [[ -z "${PRIVATE_KEY}" ]]; then
  echo "PRIVATE_KEY is required"
  exit 1
fi

OWNER="$(cast wallet address --private-key "${PRIVATE_KEY}")"

deploy_contract() {
  local target="$1"
  shift
  forge create "${target}" \
    --rpc-url "${RPC_URL}" \
    --private-key "${PRIVATE_KEY}" \
    --broadcast \
    --constructor-args "$@" | awk '/Deployed to:/{print $3}'
}

echo "Owner: ${OWNER}"

echo "Deploy OracleChainAdapter..."
ORACLE="$(deploy_contract src/OracleChainAdapter.vy:OracleChainAdapter "${FEED_ADDRESS}" "${MAX_AGE}" "${MAX_CHANGE_BPS}" "${OWNER}")"
echo "ORACLE=${ORACLE}"

echo "Deploy VaultManager (temp engine=owner)..."
VAULT="$(deploy_contract src/VaultManager.vy:VaultManager "${ORACLE}" "${OWNER}" "${OWNER}")"
echo "VAULT_MANAGER=${VAULT}"

echo "Deploy Stablecoin (temp minter=owner)..."
STABLECOIN="$(deploy_contract src/Stablecoin.vy:Stablecoin "Stable BTC" "STB" 18 "${OWNER}" "${OWNER}")"
echo "STABLECOIN=${STABLECOIN}"

echo "Deploy StabilityEngine..."
ENGINE="$(deploy_contract src/StabilityEngine.vy:StabilityEngine "${STABLECOIN}" "${VAULT}" "${OWNER}" "${MCR}" "${MINT_FEE_BPS}" "${REPAY_FEE_BPS}" "${DEBT_CAP_PER_VAULT}" "${GLOBAL_DEBT_CAP}")"
echo "STABILITY_ENGINE=${ENGINE}"

echo "Deploy LiquidationEnging..."
LIQUIDATION="$(deploy_contract src/LiquidationEnging.vy:LiquidationEnging "${STABLECOIN}" "${VAULT}" "${ENGINE}" "${OWNER}" "${LIQ_PENALTY_BPS}")"
echo "LIQUIDATION_ENGINE=${LIQUIDATION}"

echo "Wire permissions..."
cast send "${STABLECOIN}" "set_minter(address)" "${ENGINE}" --rpc-url "${RPC_URL}" --private-key "${PRIVATE_KEY}" >/dev/null
cast send "${VAULT}" "set_engine(address)" "${ENGINE}" --rpc-url "${RPC_URL}" --private-key "${PRIVATE_KEY}" >/dev/null
cast send "${VAULT}" "set_liquidation_engine(address)" "${LIQUIDATION}" --rpc-url "${RPC_URL}" --private-key "${PRIVATE_KEY}" >/dev/null

echo "Write frontend/.env.local ..."
cat > "${REPO_ROOT}/frontend/.env.local" <<ENV
VITE_RPC_URL=${RPC_URL}
VITE_VAULT_MANAGER_ADDRESS=${VAULT}
VITE_STABILITY_ENGINE_ADDRESS=${ENGINE}
VITE_STABLECOIN_ADDRESS=${STABLECOIN}
VITE_ORACLE_ADDRESS=${ORACLE}
ENV

echo "Done. Frontend env written to frontend/.env.local"
