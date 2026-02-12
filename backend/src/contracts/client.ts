import { Contract, JsonRpcProvider, Wallet } from "ethers";

import { env } from "../config/env.js";
import { ORACLE_HUB_ABI, STABLE_VAULT_ABI, TWAP_ORACLE_ABI } from "./abis.js";

export const provider = new JsonRpcProvider(env.rpcUrl, env.chainId);

export const keeperSigner = env.keeperPrivateKey
  ? new Wallet(env.keeperPrivateKey, provider)
  : undefined;

export const stableVault = new Contract(
  env.stableVaultAddress,
  STABLE_VAULT_ABI,
  keeperSigner ?? provider
);

export const oracleHub = new Contract(env.oracleHubAddress, ORACLE_HUB_ABI, provider);

export const twapOracle = new Contract(
  env.twapOracleAddress,
  TWAP_ORACLE_ABI,
  keeperSigner ?? provider
);

const ERC20_ABI = [
  "function approve(address spender, uint256 amount) external returns (bool)",
  "function allowance(address owner, address spender) external view returns (uint256)",
  "function balanceOf(address account) external view returns (uint256)"
];

export const stbToken = new Contract(
  env.stbTokenAddress,
  ERC20_ABI,
  keeperSigner ?? provider
);

