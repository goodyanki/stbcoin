import { config as loadDotenv } from "dotenv";
import { z } from "zod";

loadDotenv();

function parseBoolean(value: string): boolean {
  return value.trim().toLowerCase() === "true";
}

function parseWatchOwners(value: string): string[] {
  const candidates = value
    .split(",")
    .map((entry) => entry.trim())
    .filter(Boolean);
  return candidates.filter((entry) => /^0x[a-fA-F0-9]{40}$/.test(entry));
}

const schema = z.object({
  PORT: z.string().default("8080"),
  DATABASE_URL: z.string().default("file:./dev.db"),
  RPC_URL: z.string().url(),
  CHAIN_ID: z.string().default("11155111"),
  START_BLOCK: z.string().default("0"),
  STABLE_VAULT_ADDRESS: z.string().length(42),
  ORACLE_HUB_ADDRESS: z.string().length(42),
  TWAP_ORACLE_ADDRESS: z.string().length(42),
  STB_TOKEN_ADDRESS: z.string().length(42),
  KEEPER_PRIVATE_KEY: z.string().optional(),
  KEEPER_INTERVAL_MS: z.string().default("15000"),
  KEEPER_MAX_ATTEMPTS: z.string().default("2"),
  KEEPER_BACKOFF_MS: z.string().default("500"),
  ORACLE_INTERVAL_MS: z.string().default("60000"),
  TWAP_WINDOW_SECONDS: z.string().default("1800"),
  TWAP_SAMPLE_LIMIT: z.string().default("120"),
  KEEPER_MAX_REPAY_STB: z.string().default("1000"),
  KEEPER_AUTO_FUND_ENABLED: z.string().default("false"),
  KEEPER_AUTO_FUND_COOLDOWN_MS: z.string().default("60000"),
  KEEPER_AUTO_FUND_DEPOSIT_ETH: z.string().default("20"),
  KEEPER_AUTO_FUND_MINT_STB: z.string().default("20000"),
  WATCH_OWNERS: z.string().default(""),
  INDEXER_BLOCK_RANGE: z.string().default("2000")
});

const parsed = schema.parse(process.env);

export const env = {
  port: Number(parsed.PORT),
  databaseUrl: parsed.DATABASE_URL,
  rpcUrl: parsed.RPC_URL,
  chainId: Number(parsed.CHAIN_ID),
  startBlock: Number(parsed.START_BLOCK),
  stableVaultAddress: parsed.STABLE_VAULT_ADDRESS,
  oracleHubAddress: parsed.ORACLE_HUB_ADDRESS,
  twapOracleAddress: parsed.TWAP_ORACLE_ADDRESS,
  stbTokenAddress: parsed.STB_TOKEN_ADDRESS,
  keeperPrivateKey: parsed.KEEPER_PRIVATE_KEY,
  keeperIntervalMs: Number(parsed.KEEPER_INTERVAL_MS),
  keeperMaxAttempts: Number(parsed.KEEPER_MAX_ATTEMPTS),
  keeperBackoffMs: Number(parsed.KEEPER_BACKOFF_MS),
  oracleIntervalMs: Number(parsed.ORACLE_INTERVAL_MS),
  twapWindowSeconds: Number(parsed.TWAP_WINDOW_SECONDS),
  twapSampleLimit: Number(parsed.TWAP_SAMPLE_LIMIT),
  keeperMaxRepayStb: parsed.KEEPER_MAX_REPAY_STB,
  keeperAutoFundEnabled: parseBoolean(parsed.KEEPER_AUTO_FUND_ENABLED),
  keeperAutoFundCooldownMs: Number(parsed.KEEPER_AUTO_FUND_COOLDOWN_MS),
  keeperAutoFundDepositEth: parsed.KEEPER_AUTO_FUND_DEPOSIT_ETH,
  keeperAutoFundMintStb: parsed.KEEPER_AUTO_FUND_MINT_STB,
  watchOwners: parseWatchOwners(parsed.WATCH_OWNERS),
  indexerBlockRange: Number(parsed.INDEXER_BLOCK_RANGE)
};
