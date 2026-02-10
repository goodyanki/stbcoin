import { stableVault } from "../contracts/client.js";
import { prisma } from "../lib/prisma.js";
import { toHealthLabel } from "../lib/format.js";

function isHexAddress(value: string): boolean {
  return /^0x[a-fA-F0-9]{40}$/.test(value);
}

export async function refreshVaultSnapshot(owner: string): Promise<void> {
  if (!isHexAddress(owner)) return;

  const [collateral, principal, accruedFee, debtWithFee] =
    (await stableVault.getVault(owner)) as [bigint, bigint, bigint, bigint, bigint, bigint];

  const collateralRatioBps = (await stableVault.getCollateralRatioBps(owner)) as bigint;
  const health = toHealthLabel(collateralRatioBps);

  await prisma.vaultState.upsert({
    where: { owner },
    update: {
      collateral: collateral.toString(),
      debtPrincipal: principal.toString(),
      accruedFee: accruedFee.toString(),
      debtWithFee: debtWithFee.toString(),
      collateralRatio: collateralRatioBps.toString(),
      health
    },
    create: {
      owner,
      collateral: collateral.toString(),
      debtPrincipal: principal.toString(),
      accruedFee: accruedFee.toString(),
      debtWithFee: debtWithFee.toString(),
      collateralRatio: collateralRatioBps.toString(),
      health
    }
  });
}

