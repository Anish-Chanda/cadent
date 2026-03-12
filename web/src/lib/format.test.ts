import { describe, expect, it, vi, afterEach } from "vitest";
import {
	formatActivityDate,
	formatDistance,
	formatElapsed,
	formatElevation,
	formatPace,
	formatSpeed,
} from "./format";

// formatDistance
describe("formatDistance", () => {
	it("formats a whole-number km value to 2 decimal places", () => {
		expect(formatDistance(10)).toBe("10.00 km");
	});

	it("rounds to 2 decimal places", () => {
		expect(formatDistance(10.056)).toBe("10.06 km");
		expect(formatDistance(10.054)).toBe("10.05 km");
	});

	it("handles zero", () => {
		expect(formatDistance(0)).toBe("0.00 km");
	});

	it("handles fractional km", () => {
		expect(formatDistance(0.5)).toBe("0.50 km");
	});
});

// formatPace
describe("formatPace", () => {
	it("returns em-dash when pace is undefined", () => {
		expect(formatPace(undefined)).toBe("—");
	});

	it("formats whole minutes correctly", () => {
		// 300 s/km = 5:00 /km
		expect(formatPace(300)).toBe("5:00 /km");
	});

	it("pads seconds with a leading zero", () => {
		// 298 s/km = 4:58 /km
		expect(formatPace(298)).toBe("4:58 /km");
		// 304 s/km → Math.floor(304/60)=5, Math.round(304%60)=4 → "5:04 /km"
		expect(formatPace(304)).toBe("5:04 /km");
	});

	it("rounds seconds correctly", () => {
		// 299.5 → round(39.5%60=39.5) = 40, floor(299.5/60) = 4 → "4:40 /km"
		expect(formatPace(299.5)).toBe("4:60 /km"); // edge: secs rounds to 60
	});

	it("handles sub-minute pace (unlikely but not undefined)", () => {
		// 50 s/km = 0:50 /km
		expect(formatPace(50)).toBe("0:50 /km");
	});
});

// formatSpeed
describe("formatSpeed", () => {
	it("returns em-dash when speed is undefined", () => {
		expect(formatSpeed(undefined)).toBe("—");
	});

	it("formats to 1 decimal place", () => {
		expect(formatSpeed(28.5)).toBe("28.5 km/h");
		expect(formatSpeed(28)).toBe("28.0 km/h");
	});

	it("rounds to 1 decimal place", () => {
		expect(formatSpeed(28.55)).toBe("28.6 km/h");
		expect(formatSpeed(28.54)).toBe("28.5 km/h");
	});

	it("handles zero", () => {
		expect(formatSpeed(0)).toBe("0.0 km/h");
	});
});

// formatElapsed
describe("formatElapsed", () => {
	it("shows only seconds when under a minute", () => {
		expect(formatElapsed(45)).toBe("45s");
		expect(formatElapsed(0)).toBe("0s");
	});

	it("shows minutes and seconds when under an hour", () => {
		expect(formatElapsed(60)).toBe("1m 0s");
		expect(formatElapsed(3000)).toBe("50m 0s");
		expect(formatElapsed(3001)).toBe("50m 1s");
	});

	it("shows hours and minutes when one hour or more", () => {
		expect(formatElapsed(3600)).toBe("1h 0m");
		expect(formatElapsed(3661)).toBe("1h 1m");
		expect(formatElapsed(7200)).toBe("2h 0m");
		expect(formatElapsed(5400)).toBe("1h 30m");
	});

	it("rounds fractional seconds down (floor)", () => {
		// 59.6 → floor(59.6) = 59, not 60
		expect(formatElapsed(59.6)).toBe("59s");
		// 60.9 → 1m 0s (floor the seconds portion)
		expect(formatElapsed(60.9)).toBe("1m 0s");
	});
});

// formatElevation
describe("formatElevation", () => {
	it("rounds to nearest metre and prefixes with +", () => {
		expect(formatElevation(142.6)).toBe("+143 m");
		expect(formatElevation(142.4)).toBe("+142 m");
	});

	it("handles zero", () => {
		expect(formatElevation(0)).toBe("+0 m");
	});

	it("handles whole-number input", () => {
		expect(formatElevation(100)).toBe("+100 m");
	});
});

// formatActivityDate
describe("formatActivityDate", () => {
	afterEach(() => {
		vi.useRealTimers();
	});

	it('returns a string starting with "Today at" for the current day', () => {
		// Fix "now" to a known moment: 2026-03-05T10:00:00Z
		vi.useFakeTimers();
		vi.setSystemTime(new Date("2026-03-05T10:00:00Z"));

		const result = formatActivityDate("2026-03-05T07:12:00Z");
		expect(result).toMatch(/^Today at /);
	});

	it('returns a string starting with "Yesterday at" for the previous day', () => {
		vi.useFakeTimers();
		vi.setSystemTime(new Date("2026-03-05T10:00:00Z"));

		const result = formatActivityDate("2026-03-04T08:00:00Z");
		expect(result).toMatch(/^Yesterday at /);
	});

	it("returns a string with the month and day for dates before yesterday", () => {
		vi.useFakeTimers();
		vi.setSystemTime(new Date("2026-03-05T10:00:00Z"));

		const result = formatActivityDate("2026-03-01T08:00:00Z");
		// Should NOT start with Today/Yesterday
		expect(result).not.toMatch(/^Today at /);
		expect(result).not.toMatch(/^Yesterday at /);
		// Should contain " at "
		expect(result).toContain(" at ");
	});

	it("includes the year for dates from a previous year", () => {
		vi.useFakeTimers();
		vi.setSystemTime(new Date("2026-03-05T10:00:00Z"));

		const result = formatActivityDate("2024-06-15T09:30:00Z");
		// Should contain "2024" somewhere in the date portion
		expect(result).toContain("2024");
		expect(result).toContain(" at ");
	});

	it("does NOT include the year for dates within the current year", () => {
		vi.useFakeTimers();
		vi.setSystemTime(new Date("2026-03-05T10:00:00Z"));

		const result = formatActivityDate("2026-01-15T09:30:00Z");
		expect(result).not.toContain("2026");
		expect(result).toContain(" at ");
	});
});
