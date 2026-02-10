import { backfillLiquidations, subscribeLiquidations } from "./indexer/indexer.js";
import { startKeeperWorker } from "./keeper/keeperWorker.js";
import { logger } from "./lib/logger.js";
import { prisma } from "./lib/prisma.js";
import { runTwapTick, startTwapWorker } from "./oracle/twapWorker.js";
import { startServer } from "./api/server.js";

async function bootstrap() {
  await backfillLiquidations();
  subscribeLiquidations();

  await runTwapTick();

  startTwapWorker();
  startKeeperWorker();

  await startServer();
}

bootstrap().catch(async (error) => {
  logger.error({ error }, "bootstrap failed");
  await prisma.$disconnect();
  process.exit(1);
});

