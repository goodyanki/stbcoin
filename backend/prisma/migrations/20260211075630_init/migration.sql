-- CreateTable
CREATE TABLE "VaultState" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "owner" TEXT NOT NULL,
    "collateral" TEXT NOT NULL,
    "debtPrincipal" TEXT NOT NULL,
    "accruedFee" TEXT NOT NULL,
    "debtWithFee" TEXT NOT NULL,
    "collateralRatio" TEXT NOT NULL,
    "health" TEXT NOT NULL,
    "updatedAt" DATETIME NOT NULL,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- CreateTable
CREATE TABLE "LiquidationEvent" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "txHash" TEXT NOT NULL,
    "owner" TEXT NOT NULL,
    "liquidator" TEXT NOT NULL,
    "repayAmount" TEXT NOT NULL,
    "seizedAmount" TEXT NOT NULL,
    "badDebtDelta" TEXT NOT NULL,
    "blockNumber" INTEGER NOT NULL,
    "blockTime" DATETIME NOT NULL,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- CreateTable
CREATE TABLE "OracleSample" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "source" TEXT NOT NULL,
    "price" TEXT NOT NULL,
    "staleness" INTEGER NOT NULL,
    "deviation" INTEGER NOT NULL,
    "sampledAt" DATETIME NOT NULL,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- CreateTable
CREATE TABLE "KeeperRun" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "runAt" DATETIME NOT NULL,
    "scanned" INTEGER NOT NULL,
    "attempted" INTEGER NOT NULL,
    "succeeded" INTEGER NOT NULL,
    "failed" INTEGER NOT NULL,
    "durationMs" INTEGER NOT NULL,
    "note" TEXT,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- CreateIndex
CREATE UNIQUE INDEX "VaultState_owner_key" ON "VaultState"("owner");

-- CreateIndex
CREATE UNIQUE INDEX "LiquidationEvent_txHash_key" ON "LiquidationEvent"("txHash");
