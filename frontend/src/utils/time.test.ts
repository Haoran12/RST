import { describe, expect, it } from "vitest";

import {
  formatTimestampLocal,
  parseTimestamp,
  timestampToEpochMs,
  toLocalIsoString,
} from "@/utils/time";

describe("time utils", () => {
  it("creates local ISO timestamps with timezone offset", () => {
    const value = toLocalIsoString(new Date("2026-03-05T03:02:03.616Z"));
    expect(value).toMatch(
      /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}[+\-]\d{2}:\d{2}$/,
    );
  });

  it("parses ISO datetime with 6-digit fractions and compact offset", () => {
    const parsed = parseTimestamp("2026-03-05T03:02:03.616089+0000");
    expect(parsed).not.toBeNull();
    expect(parsed?.toISOString()).toBe("2026-03-05T03:02:03.616Z");
  });

  it("parses 'UTC' suffix timestamps", () => {
    const parsed = parseTimestamp("2026-03-05 03:03:06 UTC");
    expect(parsed).not.toBeNull();
    expect(parsed?.toISOString()).toBe("2026-03-05T03:03:06.000Z");
  });

  it("formats timestamps in local timezone", () => {
    const input = "2026-03-05T03:02:03.616089+00:00";
    const expected = new Date("2026-03-05T03:02:03.616+00:00").toLocaleString();
    expect(formatTimestampLocal(input, "-")).toBe(expected);
  });

  it("returns NaN epoch for invalid timestamps", () => {
    expect(Number.isNaN(timestampToEpochMs("invalid-time"))).toBe(true);
  });
});
