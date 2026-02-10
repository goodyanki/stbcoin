import { describe, expect, it } from "vitest";

describe("oracle math smoke", () => {
  it("computes absolute diff and bps", () => {
    const spot = 2600_00000000n;
    const twap = 2500_00000000n;
    const diff = spot > twap ? spot - twap : twap - spot;
    const bps = Number((diff * 10_000n) / twap);

    expect(diff).toBe(100_00000000n);
    expect(bps).toBe(400);
  });

  it("computes simple twap average over 30m samples", () => {
    const samples = [2400n, 2500n, 2600n, 2550n];
    const sum = samples.reduce((acc, value) => acc + value, 0n);
    const twap = sum / BigInt(samples.length);

    expect(twap).toBe(2512n);
  });
});
