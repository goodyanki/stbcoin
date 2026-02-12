import { env } from "../config/env.js";
import { stableVault } from "../contracts/client.js";
import { prisma } from "../lib/prisma.js";
import { logger } from "../lib/logger.js";
import { refreshVaultSnapshot } from "./snapshot.js";

type LiquidationLog = {
  blockNumber: bigint;
  transactionHash: string;
  args: {
    owner: string;
    liquidator: string;
    repayAmount: bigint;
    seizedCollateral: bigint;
    badDebtDelta: bigint;
  };
};

type EventWithOwner = {
  args?: {
    owner?: string;
    [index: number]: unknown;
  };
};

function asOwner(event: unknown): string | null {
  const entry = event as EventWithOwner;
  const ownerNamed = entry.args?.owner;
  if (typeof ownerNamed === "string") return ownerNamed;

  const ownerIndexed = entry.args?.[0];
  if (typeof ownerIndexed === "string") return ownerIndexed;

  return null;
}

function isHexAddress(value: string): boolean {
  return /^0x[a-fA-F0-9]{40}$/.test(value);
}

async function queryFilterInChunks(
  filter: Parameters<typeof stableVault.queryFilter>[0],
  fromBlock: number,
  toBlock: number,
  step: number
) {
  if (toBlock < fromBlock) return [];

  const results: unknown[] = [];
  const chunkSize = Math.max(1, step);

  for (let current = fromBlock; current <= toBlock; current += chunkSize) {
    const chunkFrom = current;
    const chunkTo = Math.min(toBlock, current + chunkSize - 1);

    let chunkLoaded = false;
    for (let attempt = 1; attempt <= 2; attempt += 1) {
      try {
        const logs = await stableVault.queryFilter(filter, chunkFrom, chunkTo);
        results.push(...logs);
        chunkLoaded = true;
        break;
      } catch (error) {
        logger.error(
          { error, chunkFrom, chunkTo, attempt },
          "chunk queryFilter failed"
        );
      }
    }

    if (!chunkLoaded) {
      logger.warn({ chunkFrom, chunkTo }, "skipping failed chunk after retries");
    }
  }

  return results;
}

export async function backfillLiquidations(): Promise<void> {
  const latest = await stableVault.runner?.provider?.getBlockNumber();
  if (latest === undefined) return;

  const startBlock = Math.max(0, env.startBlock);
  const chunkRange = Math.max(1, env.indexerBlockRange);

  const [deposits, withdrawals, mints, repays, liquidations] = await Promise.all([
    queryFilterInChunks(stableVault.filters.Deposited(), startBlock, latest, chunkRange),
    queryFilterInChunks(stableVault.filters.Withdrawn(), startBlock, latest, chunkRange),
    queryFilterInChunks(stableVault.filters.Minted(), startBlock, latest, chunkRange),
    queryFilterInChunks(stableVault.filters.Repaid(), startBlock, latest, chunkRange),
    queryFilterInChunks(stableVault.filters.Liquidated(), startBlock, latest, chunkRange)
  ]);

  const ownerSet = new Set<string>();

  for (const event of deposits) {
    const owner = asOwner(event);
    if (owner && isHexAddress(owner)) ownerSet.add(owner);
  }
  for (const event of withdrawals) {
    const owner = asOwner(event);
    if (owner && isHexAddress(owner)) ownerSet.add(owner);
  }
  for (const event of mints) {
    const owner = asOwner(event);
    if (owner && isHexAddress(owner)) ownerSet.add(owner);
  }
  for (const event of repays) {
    const owner = asOwner(event);
    if (owner && isHexAddress(owner)) ownerSet.add(owner);
  }

  for (const rawEvent of liquidations) {
    const event = rawEvent as unknown as LiquidationLog;
    const block = await stableVault.runner?.provider?.getBlock(Number(event.blockNumber));

    if (isHexAddress(event.args.owner)) {
      ownerSet.add(event.args.owner);
    }

    await prisma.liquidationEvent.upsert({
      where: { txHash: event.transactionHash },
      update: {
        owner: event.args.owner,
        liquidator: event.args.liquidator,
        repayAmount: event.args.repayAmount.toString(),
        seizedAmount: event.args.seizedCollateral.toString(),
        badDebtDelta: event.args.badDebtDelta.toString(),
        blockNumber: Number(event.blockNumber),
        blockTime: new Date((block?.timestamp ?? Math.floor(Date.now() / 1000)) * 1000)
      },
      create: {
        txHash: event.transactionHash,
        owner: event.args.owner,
        liquidator: event.args.liquidator,
        repayAmount: event.args.repayAmount.toString(),
        seizedAmount: event.args.seizedCollateral.toString(),
        badDebtDelta: event.args.badDebtDelta.toString(),
        blockNumber: Number(event.blockNumber),
        blockTime: new Date((block?.timestamp ?? Math.floor(Date.now() / 1000)) * 1000)
      }
    });
  }

  for (const owner of ownerSet) {
    await refreshVaultSnapshot(owner);
  }

  logger.info(
    {
      liquidationCount: liquidations.length,
      ownerSnapshotsRefreshed: ownerSet.size
    },
    "historical backfill complete"
  );
}

export function subscribeLiquidations(): void {
  const refreshOwnerFromEvent = async (owner: string) => {
    try {
      await refreshVaultSnapshot(owner);
    } catch (error) {
      logger.error({ error, owner }, "failed refreshing owner snapshot");
    }
  };

  try {
    stableVault.on("Deposited", async (owner: string) => {
      await refreshOwnerFromEvent(owner);
    });

    stableVault.on("Withdrawn", async (owner: string) => {
      await refreshOwnerFromEvent(owner);
    });

    stableVault.on("Minted", async (owner: string) => {
      await refreshOwnerFromEvent(owner);
    });

    stableVault.on("Repaid", async (owner: string) => {
      await refreshOwnerFromEvent(owner);
    });

    stableVault.on(
      "Liquidated",
      async (
        owner: string,
        liquidator: string,
        repayAmount: bigint,
        seizedCollateral: bigint,
        badDebtDelta: bigint,
        event: { log: { transactionHash: string; blockNumber: number } }
      ) => {
        try {
          const block = await stableVault.runner?.provider?.getBlock(event.log.blockNumber);
          await prisma.liquidationEvent.upsert({
            where: { txHash: event.log.transactionHash },
            update: {
              owner,
              liquidator,
              repayAmount: repayAmount.toString(),
              seizedAmount: seizedCollateral.toString(),
              badDebtDelta: badDebtDelta.toString(),
              blockNumber: event.log.blockNumber,
              blockTime: new Date((block?.timestamp ?? Math.floor(Date.now() / 1000)) * 1000)
            },
            create: {
              txHash: event.log.transactionHash,
              owner,
              liquidator,
              repayAmount: repayAmount.toString(),
              seizedAmount: seizedCollateral.toString(),
              badDebtDelta: badDebtDelta.toString(),
              blockNumber: event.log.blockNumber,
              blockTime: new Date((block?.timestamp ?? Math.floor(Date.now() / 1000)) * 1000)
            }
          });
          await refreshOwnerFromEvent(owner);
        } catch (error) {
          logger.error({ error }, "failed to persist liquidation event");
        }
      }
    );
  } catch (error) {
    logger.error({ error }, "subscribeLiquidations failed, keeper will continue with polling snapshot state");
  }
}
