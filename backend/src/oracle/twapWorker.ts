import { parseUnits } from "ethers";

import { env } from "../config/env.js";
import { oracleHub, twapOracle } from "../contracts/client.js";
import { prisma } from "../lib/prisma.js";
import { logger } from "../lib/logger.js";

type PriceStatus = [bigint, bigint, bigint, bigint, bigint, boolean];

function average(values: bigint[]): bigint {
  if (values.length === 0) return 0n;
  const sum = values.reduce((acc, value) => acc + value, 0n);
  return sum / BigInt(values.length);
}

export async function runTwapTick(): Promise<void> {
  const status = (await oracleHub.getPriceStatus()) as PriceStatus;
  const [, spotPrice, twapPrice, spotUpdatedAt, twapUpdatedAt] = status;

  await prisma.oracleSample.create({
    data: {
      source: "spot",
      price: spotPrice.toString(),
      staleness: Math.max(0, Math.floor(Date.now() / 1000) - Number(spotUpdatedAt)),
      deviation:
        twapPrice > 0n
          ? Number((spotPrice > twapPrice ? spotPrice - twapPrice : twapPrice - spotPrice) * 10_000n / twapPrice)
          : 0,
      sampledAt: new Date()
    }
  });

  const since = new Date(Date.now() - env.twapWindowSeconds * 1000);
  const samples = await prisma.oracleSample.findMany({
    where: {
      source: "spot",
      sampledAt: { gte: since }
    },
    orderBy: { sampledAt: "desc" },
    take: env.twapSampleLimit
  });

  const values = samples.map((sample) => BigInt(sample.price));
  const computed = average(values);

  if (computed > 0n && twapOracle.runner && "sendTransaction" in twapOracle.runner) {
    try {
      const tx = await twapOracle.updateTwap(computed);
      await tx.wait();
      logger.info({ computed: computed.toString() }, "twap updated");

      await prisma.oracleSample.create({
        data: {
          source: "twap",
          price: computed.toString(),
          staleness: Math.max(0, Math.floor(Date.now() / 1000) - Number(twapUpdatedAt)),
          deviation: 0,
          sampledAt: new Date()
        }
      });
    } catch (error) {
      logger.error({ error }, "twap update tx failed");
    }
  }
}

export function startTwapWorker(): NodeJS.Timeout {
  return setInterval(() => {
    void runTwapTick().catch((error) => {
      logger.error({ error }, "twap tick failed");
    });
  }, env.oracleIntervalMs);
}

export function parseKeeperMaxRepay(): bigint {
  return parseUnits(env.keeperMaxRepayStb, 18);
}


