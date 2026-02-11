import { backfillLiquidations, subscribeLiquidations } from "./indexer/indexer.js";
import { startKeeperWorker } from "./keeper/keeperWorker.js";
import { logger } from "./lib/logger.js";
import { prisma } from "./lib/prisma.js";
import { runTwapTick, startTwapWorker } from "./oracle/twapWorker.js";
import { startServer } from "./api/server.js";

async function safeStep(step: string, action: () => Promise<void> | void): Promise<void> {
  try {
    await action();
  } catch (error) {
    logger.error({ error, step }, "bootstrap step failed");
  }
}

async function bootstrap() {
  await startServer();

  await safeStep("indexer backfill", backfillLiquidations);
  await safeStep("indexer subscribe", () => {
    subscribeLiquidations();
  });
  await safeStep("initial twap tick", runTwapTick);
  await safeStep("start twap worker", () => {
    startTwapWorker();
  });
  await safeStep("start keeper worker", () => {
    startKeeperWorker();
  });
}

bootstrap().catch(async (error) => {
  logger.error({ error }, "bootstrap failed");
  await prisma.$disconnect();
  process.exit(1);
});
