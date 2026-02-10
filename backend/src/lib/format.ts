import { formatUnits } from "ethers";

export function toDecimalString(value: bigint, decimals = 18): string {
  return formatUnits(value, decimals);
}

export function toHealthLabel(collateralRatioBps: bigint): "safe" | "warning" | "danger" {
  if (collateralRatioBps < 15_000n) return "danger";
  if (collateralRatioBps < 17_000n) return "warning";
  return "safe";
}

