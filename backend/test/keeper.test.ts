import { describe, expect, it } from "vitest";

import { toHealthLabel } from "../src/lib/format.js";

process.env.RPC_URL ??= "https://example.com";
process.env.CHAIN_ID ??= "11155111";
process.env.STABLE_VAULT_ADDRESS ??= "0x0000000000000000000000000000000000000001";
process.env.ORACLE_HUB_ADDRESS ??= "0x0000000000000000000000000000000000000002";
process.env.TWAP_ORACLE_ADDRESS ??= "0x0000000000000000000000000000000000000003";
process.env.STB_TOKEN_ADDRESS ??= "0x0000000000000000000000000000000000000004";

const { computeBackoffMs, liquidateWithRetry } = await import("../src/keeper/keeperWorker.js");

describe("keeper selection helpers", () => {
  it("maps danger threshold", () => {
    expect(toHealthLabel(14_999n)).toBe("danger");
  });

  it("maps warning threshold", () => {
    expect(toHealthLabel(15_000n)).toBe("warning");
    expect(toHealthLabel(16_999n)).toBe("warning");
  });

  it("maps safe threshold", () => {
    expect(toHealthLabel(17_000n)).toBe("safe");
  });

  it("computes exponential backoff", () => {
    expect(computeBackoffMs(500, 1)).toBe(500);
    expect(computeBackoffMs(500, 2)).toBe(1000);
    expect(computeBackoffMs(500, 3)).toBe(2000);
  });

  it("retries liquidation until success", async () => {
    let calls = 0;

    const result = await liquidateWithRetry({
      owner: "0x1111111111111111111111111111111111111111",
      repayAmount: 1n,
      maxAttempts: 3,
      baseBackoffMs: 0,
      liquidate: async () => {
        calls += 1;
        if (calls < 3) {
          throw new Error("fail-before-success");
        }
        return {
          wait: async () => undefined
        };
      }
    });

    expect(result.success).toBe(true);
    expect(result.attempts).toBe(3);
    expect(calls).toBe(3);
  });

  it("returns failure after max attempts", async () => {
    let calls = 0;
    const result = await liquidateWithRetry({
      owner: "0x1111111111111111111111111111111111111111",
      repayAmount: 1n,
      maxAttempts: 2,
      baseBackoffMs: 0,
      liquidate: async () => {
        calls += 1;
        throw new Error("always-fail");
      }
    });

    expect(result.success).toBe(false);
    expect(result.attempts).toBe(2);
    expect(result.reason).toContain("always-fail");
    expect(calls).toBe(2);
  });
});
