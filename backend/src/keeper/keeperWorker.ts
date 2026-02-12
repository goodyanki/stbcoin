import { parseUnits } from "ethers";

import { env } from "../config/env.js";
import { stableVault, stbToken as _stbToken } from "../contracts/client.js";
import { prisma } from "../lib/prisma.js";
import { logger } from "../lib/logger.js";

type KeeperErrorClass = "config" | "rpc" | "revert" | "decode" | "unknown";

type KeeperState = {
  active: boolean;
  lastRunAt: Date | null;
  lastSummary: {
    scanned: number;
    attempted: number;
    succeeded: number;
    failed: number;
    retried: number;
  };
  recentFailures: Array<{ owner: string; attempts: number; reason: string; at: string }>;
  lastErrorClass: KeeperErrorClass | null;
  lastErrorMessage: string | null;
  lastErrorAt: Date | null;
  lastAutoFundAt: Date | null;
  autoFundLastResult: string | null;
  ownersScannedOnChain: number;
};

type LiquidationTxLike = {
  wait: () => Promise<unknown>;
};

type LiquidateFn = (owner: string, repayAmount: bigint) => Promise<LiquidationTxLike>;

type KeeperSignerLike = {
  sendTransaction: (...args: unknown[]) => Promise<unknown>;
  getAddress: () => Promise<string>;
};

const keeperState: KeeperState = {
  active: false,
  lastRunAt: null,
  lastSummary: {
    scanned: 0,
    attempted: 0,
    succeeded: 0,
    failed: 0,
    retried: 0
  },
  recentFailures: [],
  lastErrorClass: null,
  lastErrorMessage: null,
  lastErrorAt: null,
  lastAutoFundAt: null,
  autoFundLastResult: null,
  ownersScannedOnChain: 0
};

let lastAutoFundAttemptAt = 0;

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

function asReason(error: unknown): string {
  if (error instanceof Error) return error.message;
  return String(error);
}

function classifyError(error: unknown): KeeperErrorClass {
  const message = asReason(error).toLowerCase();

  if (
    message.includes("private key") ||
    message.includes("signer unavailable") ||
    message.includes("missing")
  ) {
    return "config";
  }

  if (
    message.includes("network") ||
    message.includes("timeout") ||
    message.includes("socket") ||
    message.includes("rpc") ||
    message.includes("failed to fetch")
  ) {
    return "rpc";
  }

  if (
    message.includes("execution reverted") ||
    message.includes("call exception") ||
    message.includes("revert") ||
    message.includes("insufficient")
  ) {
    return "revert";
  }

  if (
    message.includes("decode") ||
    message.includes("bad data") ||
    message.includes("unexpected amount of data")
  ) {
    return "decode";
  }

  return "unknown";
}

function setLastError(error: unknown, klass?: KeeperErrorClass): void {
  keeperState.lastErrorClass = klass ?? classifyError(error);
  keeperState.lastErrorMessage = asReason(error);
  keeperState.lastErrorAt = new Date();
}

function isHexAddress(value: string): boolean {
  return /^0x[a-fA-F0-9]{40}$/.test(value);
}

function isKeeperSigner(value: unknown): value is KeeperSignerLike {
  if (!value || typeof value !== "object") return false;
  const maybeSigner = value as KeeperSignerLike;
  return typeof maybeSigner.sendTransaction === "function" && typeof maybeSigner.getAddress === "function";
}

async function listVaultCandidates(): Promise<string[]> {
  const rows = await prisma.vaultState.findMany({
    select: { owner: true }
  });

  const ownerSet = new Set<string>();

  for (const row of rows) {
    if (isHexAddress(row.owner)) {
      ownerSet.add(row.owner.toLowerCase());
    }
  }

  for (const owner of env.watchOwners) {
    if (isHexAddress(owner)) {
      ownerSet.add(owner.toLowerCase());
    }
  }

  return Array.from(ownerSet);
}

export function computeBackoffMs(baseBackoffMs: number, attempt: number): number {
  if (baseBackoffMs <= 0) return 0;
  if (attempt <= 0) return 0;
  return baseBackoffMs * 2 ** (attempt - 1);
}

export async function liquidateWithRetry(params: {
  owner: string;
  repayAmount: bigint;
  liquidate: LiquidateFn;
  maxAttempts: number;
  baseBackoffMs: number;
}): Promise<{
  success: boolean;
  attempts: number;
  reason?: string;
}> {
  let attempts = 0;
  let lastReason: string | undefined;

  const maxAttempts = Math.max(1, params.maxAttempts);
  const baseBackoffMs = Math.max(0, params.baseBackoffMs);

  while (attempts < maxAttempts) {
    attempts += 1;
    try {
      const tx = await params.liquidate(params.owner, params.repayAmount);
      await tx.wait();
      return { success: true, attempts };
    } catch (error) {
      lastReason = asReason(error);
      logger.error({ owner: params.owner, attempts, error }, "keeper liquidation attempt failed");

      if (attempts >= maxAttempts) break;
      const backoff = computeBackoffMs(baseBackoffMs, attempts);
      if (backoff > 0) {
        await sleep(backoff);
      }
    }
  }

  return { success: false, attempts, reason: lastReason };
}

async function attemptLiquidationWithRetry(owner: string, repayAmount: bigint): Promise<{
  success: boolean;
  attempts: number;
  reason?: string;
}> {
  return liquidateWithRetry({
    owner,
    repayAmount,
    liquidate: async (liquidationOwner, liquidationRepayAmount) =>
      (await stableVault.liquidate(liquidationOwner, liquidationRepayAmount)) as LiquidationTxLike,
    maxAttempts: env.keeperMaxAttempts,
    baseBackoffMs: env.keeperBackoffMs
  });
}

async function autoFundKeeper(repayAmount: bigint): Promise<string> {
  if (!env.keeperAutoFundEnabled) {
    return "disabled";
  }

  const now = Date.now();
  const cooldownMs = Math.max(0, env.keeperAutoFundCooldownMs);
  if (now - lastAutoFundAttemptAt < cooldownMs) {
    return "cooldown";
  }

  const runner = stableVault.runner;
  if (!isKeeperSigner(runner)) {
    throw new Error("keeper signer unavailable");
  }

  lastAutoFundAttemptAt = now;
  keeperState.lastAutoFundAt = new Date();

  const keeperAddress = await runner.getAddress();

  const allowance = (await _stbToken.getFunction("allowance")(
    keeperAddress,
    env.stableVaultAddress
  )) as bigint;

  if (allowance < repayAmount) {
    const approveTx = (await _stbToken.getFunction("approve")(
      env.stableVaultAddress,
      1n << 255n
    )) as LiquidationTxLike;
    await approveTx.wait();
  }

  const balance = (await _stbToken.getFunction("balanceOf")(keeperAddress)) as bigint;
  if (balance >= repayAmount) {
    return allowance < repayAmount ? "approved" : "ready";
  }

  const autoFundDepositEth = parseUnits(env.keeperAutoFundDepositEth, 18);
  const autoFundMintStb = parseUnits(env.keeperAutoFundMintStb, 18);
  if (autoFundDepositEth <= 0n || autoFundMintStb <= 0n) {
    throw new Error("auto-fund amounts must be positive");
  }

  const depositTx = (await stableVault.deposit(autoFundDepositEth, {
    value: autoFundDepositEth
  })) as LiquidationTxLike;
  await depositTx.wait();

  const mintTx = (await stableVault.mint(autoFundMintStb)) as LiquidationTxLike;
  await mintTx.wait();

  return "funded";
}

export async function runKeeperTick(): Promise<void> {
  const startedAt = Date.now();
  const candidates = await listVaultCandidates();
  const signerReady = isKeeperSigner(stableVault.runner);
  let attempted = 0;
  let succeeded = 0;
  let failed = 0;
  let retried = 0;
  let ownersScannedOnChain = 0;
  const failures: Array<{ owner: string; attempts: number; reason: string; at: string }> = [];

  const repayAmount = parseUnits(env.keeperMaxRepayStb, 18);
  let autoFundLastResult = "disabled";

  if (!signerReady) {
    setLastError(new Error("keeper signer unavailable"), "config");
  }

  try {
    autoFundLastResult = await autoFundKeeper(repayAmount);
  } catch (error) {
    autoFundLastResult = `failed:${asReason(error)}`;
    setLastError(error);
    logger.error({ error }, "failed to auto-fund keeper");
  }

  for (const owner of candidates) {
    try {
      ownersScannedOnChain += 1;
      const liquidatable = (await stableVault.isLiquidatable(owner)) as boolean;
      if (!liquidatable) continue;

      if (!signerReady) {
        failed += 1;
        const reason = "keeper signer unavailable";
        failures.push({
          owner,
          attempts: 0,
          reason,
          at: new Date().toISOString()
        });
        setLastError(new Error(reason), "config");
        continue;
      }

      attempted += 1;

      const result = await attemptLiquidationWithRetry(owner, repayAmount);
      if (result.attempts > 1) {
        retried += result.attempts - 1;
      }

      if (result.success) {
        succeeded += 1;
      } else {
        failed += 1;
        const reason = result.reason ?? "unknown";
        failures.push({ owner, attempts: result.attempts, reason, at: new Date().toISOString() });
        setLastError(new Error(reason));
      }
    } catch (error) {
      failed += 1;
      failures.push({
        owner,
        attempts: 1,
        reason: asReason(error),
        at: new Date().toISOString()
      });
      setLastError(error);
      logger.error({ owner, error }, "keeper liquidation failed before retry path");
    }
  }

  const durationMs = Date.now() - startedAt;

  keeperState.active = true;
  keeperState.lastRunAt = new Date();
  keeperState.lastSummary = {
    scanned: candidates.length,
    attempted,
    succeeded,
    failed,
    retried
  };
  keeperState.recentFailures = failures.slice(0, 20);
  keeperState.autoFundLastResult = autoFundLastResult;
  keeperState.ownersScannedOnChain = ownersScannedOnChain;

  await prisma.keeperRun.create({
    data: {
      runAt: new Date(),
      scanned: ownersScannedOnChain,
      attempted,
      succeeded,
      failed,
      durationMs,
      note:
        failures.length > 0
          ? failures
            .slice(0, 5)
            .map((item) => `${item.owner}:${item.attempts}:${item.reason.slice(0, 80)}`)
            .join(" | ")
          : null
    }
  });
}

export function getKeeperStatus() {
  return keeperState;
}

export function startKeeperWorker(): NodeJS.Timeout {
  keeperState.active = true;
  return setInterval(() => {
    void runKeeperTick().catch((error) => {
      setLastError(error);
      logger.error({ error }, "keeper tick failed");
    });
  }, env.keeperIntervalMs);
}
