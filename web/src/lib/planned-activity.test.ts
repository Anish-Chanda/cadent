import { describe, expect, it } from "vitest";

import {
	distanceToMeters,
	durationToSeconds,
	elevationToMeters,
	paceToMetersPerSecond,
	parseOptionalNonNegativeNumber,
	speedToMetersPerSecond,
	supportsPlannedMetricField,
} from "./planned-activity";

describe("parseOptionalNonNegativeNumber", () => {
	it("returns undefined for empty values", () => {
		expect(parseOptionalNonNegativeNumber("")).toBeUndefined();
		expect(parseOptionalNonNegativeNumber("   ")).toBeUndefined();
	});

	it("returns undefined for invalid or negative values", () => {
		expect(parseOptionalNonNegativeNumber("abc")).toBeUndefined();
		expect(parseOptionalNonNegativeNumber("-1")).toBeUndefined();
	});

	it("parses valid non-negative numbers", () => {
		expect(parseOptionalNonNegativeNumber("0")).toBe(0);
		expect(parseOptionalNonNegativeNumber("12.5")).toBe(12.5);
	});
});

describe("durationToSeconds", () => {
	it("returns undefined when both are empty/zero", () => {
		expect(durationToSeconds(undefined, undefined)).toBeUndefined();
		expect(durationToSeconds(0, 0)).toBeUndefined();
	});

	it("converts hours and minutes to seconds", () => {
		expect(durationToSeconds(1, 30)).toBe(5400);
		expect(durationToSeconds(0, 45)).toBe(2700);
		expect(durationToSeconds(2, 0)).toBe(7200);
	});
});

describe("unit conversions", () => {
	it("converts distance to meters", () => {
		expect(distanceToMeters(10, "km")).toBe(10000);
		expect(distanceToMeters(1, "mi")).toBeCloseTo(1609.344, 3);
	});

	it("converts elevation to meters", () => {
		expect(elevationToMeters(100, "m")).toBe(100);
		expect(elevationToMeters(100, "ft")).toBeCloseTo(30.48, 2);
	});

	it("converts speed to m/s", () => {
		expect(speedToMetersPerSecond(36, "kmh")).toBeCloseTo(10, 4);
		expect(speedToMetersPerSecond(10, "mph")).toBeCloseTo(4.4704, 4);
	});

	it("converts pace to m/s", () => {
		// 5:00 /km => 1000 / 300 = 3.333...
		expect(paceToMetersPerSecond(5, 0, "min_per_km")).toBeCloseTo(3.3333, 4);
		// 8:00 /mi => 1609.344 / 480 = 3.3528
		expect(paceToMetersPerSecond(8, 0, "min_per_mile")).toBeCloseTo(3.3528, 4);
	});
});

describe("supportsPlannedMetricField", () => {
	it("hides all metric fields for rest day", () => {
		expect(supportsPlannedMetricField("rest", "duration")).toBe(false);
		expect(supportsPlannedMetricField("rest", "distance")).toBe(false);
		expect(supportsPlannedMetricField("rest", "power")).toBe(false);
	});

	it("allows only duration for mobility and strength", () => {
		expect(supportsPlannedMetricField("mobility", "duration")).toBe(true);
		expect(supportsPlannedMetricField("mobility", "distance")).toBe(false);
		expect(supportsPlannedMetricField("strength", "duration")).toBe(true);
		expect(supportsPlannedMetricField("strength", "avg_speed")).toBe(false);
	});

	it("uses pace instead of speed for running", () => {
		expect(supportsPlannedMetricField("running", "pace")).toBe(true);
		expect(supportsPlannedMetricField("running", "avg_speed")).toBe(false);
	});
});
