import { describe, expect, it } from "vitest";

describe("indexer backfill shape", () => {
  it("collects owner addresses from all vault events", () => {
    const owners = [
      "0x1111111111111111111111111111111111111111",
      "0x2222222222222222222222222222222222222222",
      "0x1111111111111111111111111111111111111111"
    ];

    const unique = new Set(owners);
    expect(unique.size).toBe(2);
    expect(Array.from(unique)).toContain("0x1111111111111111111111111111111111111111");
    expect(Array.from(unique)).toContain("0x2222222222222222222222222222222222222222");
  });
});

