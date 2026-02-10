import { Contract, JsonRpcProvider, Wallet, formatUnits, parseUnits } from "ethers";

import { ORACLE_HUB_ABI, STABLE_VAULT_ABI } from "../src/contracts/abis.js";

const REQUIRED = [
  "RPC_URL",
  "CHAIN_ID",
  "SMOKE_OWNER_PRIVATE_KEY",
  "SMOKE_KEEPER_PRIVATE_KEY",
  "STABLE_VAULT_ADDRESS",
  "ORACLE_HUB_ADDRESS",
  "WETH_ADDRESS",
  "STB_TOKEN_ADDRESS"
] as const;

for (const key of REQUIRED) {
  if (!process.env[key]) {
    throw new Error(`Missing env ${key}`);
  }
}

const provider = new JsonRpcProvider(process.env.RPC_URL!, Number(process.env.CHAIN_ID!));
const owner = new Wallet(process.env.SMOKE_OWNER_PRIVATE_KEY!, provider);
const keeper = new Wallet(process.env.SMOKE_KEEPER_PRIVATE_KEY!, provider);

const vault = new Contract(process.env.STABLE_VAULT_ADDRESS!, STABLE_VAULT_ABI, owner);
const vaultAsKeeper = new Contract(process.env.STABLE_VAULT_ADDRESS!, STABLE_VAULT_ABI, keeper);
const oracleHub = new Contract(process.env.ORACLE_HUB_ADDRESS!, ORACLE_HUB_ABI, owner);

const erc20Abi = [
  "function approve(address spender, uint256 amount) returns (bool)",
  "function transfer(address to, uint256 amount) returns (bool)",
  "function balanceOf(address owner) view returns (uint256)"
];

const weth = new Contract(process.env.WETH_ADDRESS!, erc20Abi, owner);
const stb = new Contract(process.env.STB_TOKEN_ADDRESS!, erc20Abi, owner);
const stbAsKeeper = new Contract(process.env.STB_TOKEN_ADDRESS!, erc20Abi, keeper);

function toNum(value: bigint): number {
  return Number(formatUnits(value, 18));
}

async function wait(hashPromise: Promise<string | { hash: string }>): Promise<void> {
  const result = await hashPromise;
  const hash = typeof result === "string" ? result : result.hash;
  await provider.waitForTransaction(hash);
}

async function main() {
  const ownerAddr = await owner.getAddress();
  const keeperAddr = await keeper.getAddress();

  const depositAmount = parseUnits(process.env.SMOKE_DEPOSIT_WETH ?? "0.2", 18);
  const mintAmount = parseUnits(process.env.SMOKE_MINT_STB ?? "180", 18);
  const liquidateAmount = parseUnits(process.env.SMOKE_LIQUIDATE_STB ?? "50", 18);
  const demoPrice = parseUnits(process.env.SMOKE_DEMO_PRICE ?? "1200", 18);

  const wethBalance = (await weth.balanceOf(ownerAddr)) as bigint;
  if (wethBalance < depositAmount) {
    throw new Error(
      `Owner WETH insufficient, have=${formatUnits(wethBalance, 18)} need=${formatUnits(depositAmount, 18)}`
    );
  }

  await wait(weth.approve(process.env.STABLE_VAULT_ADDRESS!, depositAmount));
  await wait(vault.deposit(depositAmount));
  await wait(vault.mint(mintAmount));

  const stbBalanceOwner = (await stb.balanceOf(ownerAddr)) as bigint;
  const transferToKeeper = liquidateAmount < stbBalanceOwner ? liquidateAmount : stbBalanceOwner;
  await wait(stb.transfer(keeperAddr, transferToKeeper));

  await wait(vault.setDemoMode(true));
  await wait(vault.setDemoPrice(demoPrice));

  await wait(stbAsKeeper.approve(process.env.STABLE_VAULT_ADDRESS!, liquidateAmount));
  await wait(vaultAsKeeper.liquidate(ownerAddr, liquidateAmount));

  const [vaultInfo, ratioBps, badDebt, reserve, oracleStatus] = await Promise.all([
    vault.getVault(ownerAddr) as Promise<[bigint, bigint, bigint, bigint, bigint, bigint]>,
    vault.getCollateralRatioBps(ownerAddr) as Promise<bigint>,
    vault.getSystemBadDebt() as Promise<bigint>,
    vault.protocolReserveStb() as Promise<bigint>,
    oracleHub.getPriceStatus() as Promise<[bigint, bigint, bigint, bigint, bigint, boolean]>
  ]);

  console.log("=== Sepolia Smoke Result ===");
  console.log(`owner: ${ownerAddr}`);
  console.log(`keeper: ${keeperAddr}`);
  console.log(`collateralWETH: ${toNum(vaultInfo[0]).toFixed(6)}`);
  console.log(`debtSTB: ${toNum(vaultInfo[3]).toFixed(6)}`);
  console.log(`collateralRatioBps: ${ratioBps.toString()}`);
  console.log(`badDebtSTB: ${toNum(badDebt).toFixed(6)}`);
  console.log(`reserveSTB: ${toNum(reserve).toFixed(6)}`);
  console.log(`effectivePrice: ${toNum(oracleStatus[0]).toFixed(2)}`);
  console.log(`breakerTriggered: ${oracleStatus[5]}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});

