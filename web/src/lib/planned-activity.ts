export type PlannedActivityType =
	| "running"
	| "road_biking"
	| "strength_training"
	| "mobility_training"
	| "cross_training"
	| "resting";

export type DistanceUnit = "km" | "mi";
export type ElevationUnit = "m" | "ft";
export type SpeedUnit = "kph" | "mph";
export type PaceUnit = "min_per_km" | "min_per_mile";

export type PlannedMetricField =
	| "duration"
	| "distance"
	| "elevation"
	| "pace"
	| "avg_speed"
	| "power";

export const PLANNED_ACTIVITY_TYPE_OPTIONS: Array<{
	value: PlannedActivityType;
	label: string;
}> = [
	{ value: "running", label: "Running" },
	{ value: "road_biking", label: "Cycling" },
	{ value: "strength_training", label: "Strength Training" },
	{ value: "mobility_training", label: "Mobility Training" },
	{ value: "cross_training", label: "Cross Training" },
	{ value: "resting", label: "Rest Day" },
];

const METRIC_FIELDS_BY_TYPE: Record<PlannedActivityType, PlannedMetricField[]> =
	{
		running: ["duration", "distance", "elevation", "pace"],
		road_biking: ["duration", "distance", "elevation", "avg_speed", "power"],
		cross_training: ["duration", "distance", "elevation", "avg_speed", "power"],
		strength_training: ["duration"],
		mobility_training: ["duration"],
		resting: [],
	};

export function supportsPlannedMetricField(
	activityType: PlannedActivityType,
	field: PlannedMetricField,
): boolean {
	return METRIC_FIELDS_BY_TYPE[activityType].includes(field);
}

export function formatPlannedActivityTypeLabel(activityType: string): string {
	return (
		PLANNED_ACTIVITY_TYPE_OPTIONS.find((opt) => opt.value === activityType)
			?.label ?? "Activity"
	);
}

export function parseOptionalNonNegativeNumber(
	value: string,
): number | undefined {
	const trimmed = value.trim();
	if (!trimmed) return undefined;

	const parsed = Number(trimmed);
	if (!Number.isFinite(parsed) || parsed < 0) return undefined;

	return parsed;
}

export function durationToSeconds(
	hours: number | undefined,
	minutes: number | undefined,
): number | undefined {
	const hrs = hours ?? 0;
	const mins = minutes ?? 0;

	if (hrs === 0 && mins === 0) return undefined;

	return Math.round(hrs * 3600 + mins * 60);
}

export function distanceToMeters(value: number, unit: DistanceUnit): number {
	if (unit === "mi") {
		return value * 1609.344;
	}
	return value * 1000;
}

export function elevationToMeters(value: number, unit: ElevationUnit): number {
	if (unit === "ft") {
		return value * 0.3048;
	}
	return value;
}

export function speedToMetersPerSecond(value: number, unit: SpeedUnit): number {
	if (unit === "mph") {
		return value * 0.44704;
	}
	return value / 3.6;
}

export function paceToMetersPerSecond(
	paceMinutes: number,
	paceSeconds: number,
	unit: PaceUnit,
): number {
	const totalSeconds = paceMinutes * 60 + paceSeconds;
	if (totalSeconds <= 0) {
		throw new Error("Pace must be greater than 0");
	}

	const distanceMeters = unit === "min_per_mile" ? 1609.344 : 1000;
	return distanceMeters / totalSeconds;
}
