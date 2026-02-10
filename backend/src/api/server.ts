import cors from "cors";
import express from "express";

import { oracleHub, stableVault } from "../contracts/client.js";
import { env } from "../config/env.js";
import { prisma } from "../lib/prisma.js";
import { logger } from "../lib/logger.js";
import { toDecimalString } from "../lib/format.js";
import { getKeeperStatus } from "../keeper/keeperWorker.js";
import { refreshVaultSnapshot } from "../indexer/snapshot.js";

export function createServer() {
  const app = express();

  app.use(cors());
  app.use(express.json());
  app.use((req, _res, next) => {
    logger.info({ method: req.method, url: req.url }, "request");
    next();
  });

  app.get("/health", (_req, res) => {
    res.json({ ok: true, service: "stablevault-backend" });
  });

  app.get("/v1/protocol/metrics", async (_req, res, next) => {
    try {
      const [badDebt, reserve] = await Promise.all([
        stableVault.getSystemBadDebt() as Promise<bigint>,
        stableVault.protocolReserveStb() as Promise<bigint>
      ]);

      res.json({
        badDebt: badDebt.toString(),
        badDebtFormatted: toDecimalString(badDebt),
        reserve: reserve.toString(),
        reserveFormatted: toDecimalString(reserve)
      });
    } catch (error) {
      next(error);
    }
  });

  app.get("/v1/oracle/status", async (_req, res, next) => {
    try {
      const [effectivePrice, spotPrice, twapPrice, spotUpdatedAt, twapUpdatedAt, breakerTriggered] =
        (await oracleHub.getPriceStatus()) as [bigint, bigint, bigint, bigint, bigint, boolean];

      res.json({
        effectivePrice: effectivePrice.toString(),
        spotPrice: spotPrice.toString(),
        twapPrice: twapPrice.toString(),
        spotUpdatedAt: Number(spotUpdatedAt),
        twapUpdatedAt: Number(twapUpdatedAt),
        breakerTriggered
      });
    } catch (error) {
      next(error);
    }
  });

  app.get("/v1/vaults/:owner", async (req, res, next) => {
    try {
      const owner = req.params.owner;
      await refreshVaultSnapshot(owner);

      const row = await prisma.vaultState.findUnique({
        where: { owner }
      });

      if (!row) {
        res.status(404).json({ message: "vault not found" });
        return;
      }

      res.json(row);
    } catch (error) {
      next(error);
    }
  });

  app.get("/v1/vaults", async (req, res, next) => {
    try {
      const health = typeof req.query.health === "string" ? req.query.health : undefined;
      const limitRaw = typeof req.query.limit === "string" ? req.query.limit : "20";
      const limit = Math.min(200, Math.max(1, Number(limitRaw)));

      const where = health ? { health } : undefined;
      const data = await prisma.vaultState.findMany({
        where,
        orderBy: { updatedAt: "desc" },
        take: limit
      });

      res.json(data);
    } catch (error) {
      next(error);
    }
  });

  app.get("/v1/liquidations", async (req, res, next) => {
    try {
      const limitRaw = typeof req.query.limit === "string" ? req.query.limit : "20";
      const limit = Math.min(200, Math.max(1, Number(limitRaw)));

      const data = await prisma.liquidationEvent.findMany({
        orderBy: { blockNumber: "desc" },
        take: limit
      });

      res.json(data);
    } catch (error) {
      next(error);
    }
  });

  app.get("/v1/keeper/status", (_req, res) => {
    res.json(getKeeperStatus());
  });

  app.use((error: unknown, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
    logger.error({ error }, "request failed");
    res.status(500).json({ message: "internal error" });
  });

  return app;
}

export async function startServer() {
  const app = createServer();
  app.listen(env.port, () => {
    logger.info({ port: env.port }, "backend listening");
  });
}
