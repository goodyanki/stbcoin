import { parseUnits } from "ethers";

import { env } from "../config/env.js";
import { stableVault } from "../contracts/client.js";
import { prisma } from "../lib/prisma.js";
import { logger } from "../lib/logger.js";

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
};

type LiquidationTxLike = {
  wait: () => Promise<unknown>;
};

type LiquidateFn = (owner: string, repayAmount: bigint) => Promise<LiquidationTxLike>;

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
  recentFailures: []
};

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

function asReason(error: unknown): string {
  if (error instanceof Error) return error.message;
  return String(error);
}

function isHexAddress(value: string): boolean {
  return /^0x[a-fA-F0-9]{40}$/.test(value);
}

async function listVaultCandidates(limit = 100): Promise<string[]> {
  const rows = await prisma.vaultState.findMany({
    where: {
      health: {
        in: ["danger", "warning"]
      }
    },
    orderBy: { updatedAt: "desc" },
    take: limit
  });

  return rows.map((row) => row.owner).filter(isHexAddress);
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

export async function runKeeperTick(): Promise<void> {
  if (!stableVault.runner || !("sendTransaction" in stableVault.runner)) {
    logger.warn("keeper signer unavailable, skipping tick");
    return;
  }

  const startedAt = Date.now();
  const candidates = await listVaultCandidates();
  let attempted = 0;
  let succeeded = 0;
  let failed = 0;
  let retried = 0;
  const failures: Array<{ owner: string; attempts: number; reason: string; at: string }> = [];

  const repayAmount = parseUnits(env.keeperMaxRepayStb, 18);

  for (const owner of candidates) {
    try {
      const liquidatable = (await stableVault.isLiquidatable(owner)) as boolean;
      if (!liquidatable) continue;

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
      }
    } catch (error) {
      failed += 1;
      failures.push({
        owner,
        attempts: 1,
        reason: asReason(error),
        at: new Date().toISOString()
      });
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

  await prisma.keeperRun.create({
    data: {
      runAt: new Date(),
      scanned: candidates.length,
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
      logger.error({ error }, "keeper tick failed");
    });
  }, env.keeperIntervalMs);
}


