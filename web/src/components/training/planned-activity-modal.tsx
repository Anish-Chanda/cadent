import { useMutation, useQueryClient } from "@tanstack/react-query";
import { format } from "date-fns";
import * as React from "react";
import { Button } from "@/components/ui/button";
import { DatePicker } from "@/components/ui/date-picker";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select } from "@/components/ui/select";
import { createPlannedActivity } from "@/lib/api";
import {
	type DistanceUnit,
	distanceToMeters,
	durationToSeconds,
	type ElevationUnit,
	elevationToMeters,
	formatPlannedActivityTypeLabel,
	type PaceUnit,
	PLANNED_ACTIVITY_TYPE_OPTIONS,
	type PlannedActivityType,
	paceToMetersPerSecond,
	parseOptionalNonNegativeNumber,
	type SpeedUnit,
	speedToMetersPerSecond,
	supportsPlannedMetricField,
} from "@/lib/planned-activity";

interface PlannedActivityModalProps {
	isOpen: boolean;
	onClose: () => void;
	initialDate?: Date;
}

export function PlannedActivityModal({
	isOpen,
	onClose,
	initialDate,
}: PlannedActivityModalProps) {
	const queryClient = useQueryClient();
	const titleInputId = React.useId();
	const activityTypeInputId = React.useId();
	const dateInputId = React.useId();
	const timeInputId = React.useId();
	const distanceInputId = React.useId();
	const elevationInputId = React.useId();
	const avgSpeedInputId = React.useId();
	const targetPowerInputId = React.useId();
	const descriptionInputId = React.useId();

	const [title, setTitle] = React.useState("");
	const [description, setDescription] = React.useState("");
	const [activityType, setActivityType] =
		React.useState<PlannedActivityType>("running");
	const [date, setDate] = React.useState(format(new Date(), "yyyy-MM-dd"));
	const [time, setTime] = React.useState("12:00");
	const [durationHours, setDurationHours] = React.useState("");
	const [durationMinutes, setDurationMinutes] = React.useState("");
	const [distance, setDistance] = React.useState("");
	const [distanceUnit, setDistanceUnit] = React.useState<DistanceUnit>("km");
	const [elevationGain, setElevationGain] = React.useState("");
	const [elevationUnit, setElevationUnit] = React.useState<ElevationUnit>("m");
	const [paceMinutes, setPaceMinutes] = React.useState("");
	const [paceSeconds, setPaceSeconds] = React.useState("");
	const [paceUnit, setPaceUnit] = React.useState<PaceUnit>("min_per_km");
	const [avgSpeed, setAvgSpeed] = React.useState("");
	const [speedUnit, setSpeedUnit] = React.useState<SpeedUnit>("kmh");
	const [targetPower, setTargetPower] = React.useState("");
	const [error, setError] = React.useState("");

	React.useEffect(() => {
		if (isOpen && initialDate) {
			setDate(format(initialDate, "yyyy-MM-dd"));
		}
	}, [isOpen, initialDate]);

	const mutation = useMutation({
		mutationFn: createPlannedActivity,
		onSuccess: () => {
			queryClient.invalidateQueries({ queryKey: ["calendar"] });
			setTitle("");
			setDescription("");
			setActivityType("running");
			setDurationHours("");
			setDurationMinutes("");
			setDistance("");
			setDistanceUnit("km");
			setElevationGain("");
			setElevationUnit("m");
			setPaceMinutes("");
			setPaceSeconds("");
			setPaceUnit("min_per_km");
			setAvgSpeed("");
			setSpeedUnit("kmh");
			setTargetPower("");
			setError("");
			onClose();
		},
	});

	const supportsDuration = supportsPlannedMetricField(activityType, "duration");
	const supportsDistance = supportsPlannedMetricField(activityType, "distance");
	const supportsElevation = supportsPlannedMetricField(
		activityType,
		"elevation",
	);
	const supportsPace = supportsPlannedMetricField(activityType, "pace");
	const supportsAvgSpeed = supportsPlannedMetricField(
		activityType,
		"avg_speed",
	);
	const supportsPower = supportsPlannedMetricField(activityType, "power");

	const typeSpecificHint = React.useMemo(() => {
		if (activityType === "rest") {
			return "Rest days only need a title and schedule.";
		}
		if (activityType === "strength" || activityType === "mobility") {
			return "For this activity type, only duration targets are shown.";
		}
		if (activityType === "running") {
			return "Use target pace for running. Pace is converted automatically for backend storage.";
		}

		return `${formatPlannedActivityTypeLabel(activityType)} targets are optional. Enter only what matters for this session.`;
	}, [activityType]);

	const parseWholeNumberField = (
		value: string,
		label: string,
	): number | undefined => {
		const trimmed = value.trim();
		if (!trimmed) return undefined;

		const parsed = Number(trimmed);
		if (!Number.isInteger(parsed) || parsed < 0) {
			throw new Error(`${label} must be a non-negative whole number`);
		}

		return parsed;
	};

	const handleSubmit = (e: React.FormEvent) => {
		e.preventDefault();

		if (!title.trim()) {
			setError("Title is required");
			return;
		}

		const localStartTime = new Date(`${date}T${time}`);
		if (Number.isNaN(localStartTime.getTime())) {
			setError("Please provide a valid date and time");
			return;
		}

		try {
			const hours = supportsDuration
				? parseWholeNumberField(durationHours, "Duration hours")
				: undefined;
			const minutes = supportsDuration
				? parseWholeNumberField(durationMinutes, "Duration minutes")
				: undefined;

			if (minutes !== undefined && minutes >= 60) {
				setError("Duration minutes must be less than 60");
				return;
			}

			const distanceValue = supportsDistance
				? parseOptionalNonNegativeNumber(distance)
				: undefined;
			if (supportsDistance && distance.trim() && distanceValue === undefined) {
				throw new Error("Distance must be a non-negative number");
			}

			const elevationValue = supportsElevation
				? parseOptionalNonNegativeNumber(elevationGain)
				: undefined;
			if (
				supportsElevation &&
				elevationGain.trim() &&
				elevationValue === undefined
			) {
				throw new Error("Elevation gain must be a non-negative number");
			}

			const paceMinValue = supportsPace
				? parseWholeNumberField(paceMinutes, "Pace minutes")
				: undefined;
			const paceSecValue = supportsPace
				? parseWholeNumberField(paceSeconds, "Pace seconds")
				: undefined;

			if (paceSecValue !== undefined && paceSecValue >= 60) {
				setError("Pace seconds must be less than 60");
				return;
			}

			const hasPaceInput = Boolean(paceMinutes.trim() || paceSeconds.trim());
			const targetPaceAsSpeedMps =
				supportsPace && hasPaceInput
					? paceToMetersPerSecond(
							paceMinValue ?? 0,
							paceSecValue ?? 0,
							paceUnit,
						)
					: undefined;

			const avgSpeedValue = supportsAvgSpeed
				? parseOptionalNonNegativeNumber(avgSpeed)
				: undefined;
			if (supportsAvgSpeed && avgSpeed.trim() && avgSpeedValue === undefined) {
				throw new Error("Target average speed must be a non-negative number");
			}

			const powerValue = supportsPower
				? parseWholeNumberField(targetPower, "Target power")
				: undefined;

			const payload = {
				title: title.trim(),
				description: description.trim() || undefined,
				activityType,
				startTime: localStartTime.toISOString(),
				plannedDurationSecond: supportsDuration
					? durationToSeconds(hours, minutes)
					: undefined,
				plannedDistanceMeter:
					distanceValue !== undefined
						? distanceToMeters(distanceValue, distanceUnit)
						: undefined,
				plannedElevationGainMeter:
					elevationValue !== undefined
						? elevationToMeters(elevationValue, elevationUnit)
						: undefined,
				targetAverageSpeedMeterPerSecond:
					targetPaceAsSpeedMps !== undefined
						? targetPaceAsSpeedMps
						: avgSpeedValue !== undefined
							? speedToMetersPerSecond(avgSpeedValue, speedUnit)
							: undefined,
				targetPowerWatt: powerValue,
			};

			setError("");
			mutation.mutate(payload);
		} catch (err) {
			setError(
				err instanceof Error ? err.message : "Please fix invalid field values",
			);
		}
	};

	if (!isOpen) return null;

	return (
		<div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4 transition-all">
			<div className="bg-card w-full max-w-3xl rounded-xl shadow-lg border relative flex flex-col max-h-[92vh] text-foreground">
				<form
					onSubmit={handleSubmit}
					className="flex flex-col h-full overflow-hidden"
				>
					<div className="p-6 border-b shrink-0">
						<h2 className="text-xl font-bold text-foreground">
							Add Planned Activity
						</h2>
						<p className="text-sm text-muted-foreground mt-1">
							Plan your next workout to stay on track.
						</p>
					</div>

					<div className="p-6 md:p-7 grid gap-6 overflow-y-auto">
						<div className="grid gap-4 md:grid-cols-2">
							<div className="grid gap-2 md:col-span-2">
								<Label htmlFor={titleInputId}>Title *</Label>
								<Input
									id={titleInputId}
									value={title}
									onChange={(e) => setTitle(e.target.value)}
									placeholder="Morning Run"
								/>
							</div>

							<div className="grid gap-2">
								<Label htmlFor={activityTypeInputId}>Type *</Label>
								<div className="min-w-0">
									<Select
										id={activityTypeInputId}
										value={activityType}
										onChange={(e) =>
											setActivityType(e.target.value as PlannedActivityType)
										}
									>
										{PLANNED_ACTIVITY_TYPE_OPTIONS.map((option) => (
											<option key={option.value} value={option.value}>
												{option.label}
											</option>
										))}
									</Select>
								</div>
							</div>

							<div className="grid min-w-0 grid-cols-1 gap-3 sm:grid-cols-2">
								<div className="grid gap-2">
									<Label htmlFor={dateInputId}>Date</Label>
									<DatePicker
										id={dateInputId}
										value={date}
										onChange={setDate}
									/>
								</div>
								<div className="grid gap-2">
									<Label htmlFor={timeInputId}>Time</Label>
									<Input
										id={timeInputId}
										type="time"
										value={time}
										onChange={(e) => setTime(e.target.value)}
									/>
								</div>
							</div>
						</div>

						<div className="rounded-lg border border-border bg-muted/30 p-5">
							<div className="mb-4">
								<h3 className="text-sm font-semibold text-foreground">
									Workout Targets
								</h3>
								<p className="mt-1 text-xs text-muted-foreground">
									{typeSpecificHint}
								</p>
							</div>

							{!supportsDuration &&
								!supportsDistance &&
								!supportsElevation &&
								!supportsPace &&
								!supportsAvgSpeed &&
								!supportsPower && (
									<div className="rounded-md border border-dashed border-border bg-background/60 p-3 text-sm text-muted-foreground">
										No performance targets are needed for this activity type.
									</div>
								)}

							<div className="grid gap-4 md:grid-cols-2">
								{supportsDuration && (
									<div className="grid gap-2">
										<Label>Duration</Label>
										<div className="grid grid-cols-2 gap-2">
											<Input
												type="number"
												inputMode="numeric"
												min={0}
												step={1}
												value={durationHours}
												onChange={(e) => setDurationHours(e.target.value)}
												placeholder="Hours"
											/>
											<Input
												type="number"
												inputMode="numeric"
												min={0}
												max={59}
												step={1}
												value={durationMinutes}
												onChange={(e) => setDurationMinutes(e.target.value)}
												placeholder="Minutes"
											/>
										</div>
									</div>
								)}

								{supportsDistance && (
									<div className="grid gap-2">
										<Label htmlFor={distanceInputId}>Distance</Label>
										<div className="grid grid-cols-[minmax(0,1fr)_112px] gap-2">
											<Input
												id={distanceInputId}
												type="number"
												inputMode="decimal"
												min={0}
												step="0.01"
												value={distance}
												onChange={(e) => setDistance(e.target.value)}
												placeholder="10"
											/>
											<Select
												value={distanceUnit}
												onChange={(e) =>
													setDistanceUnit(e.target.value as DistanceUnit)
												}
											>
												<option value="km">km</option>
												<option value="mi">mi</option>
											</Select>
										</div>
									</div>
								)}

								{supportsElevation && (
									<div className="grid gap-2">
										<Label htmlFor={elevationInputId}>Elevation Gain</Label>
										<div className="grid grid-cols-[minmax(0,1fr)_112px] gap-2">
											<Input
												id={elevationInputId}
												type="number"
												inputMode="decimal"
												min={0}
												step="1"
												value={elevationGain}
												onChange={(e) => setElevationGain(e.target.value)}
												placeholder="300"
											/>
											<Select
												value={elevationUnit}
												onChange={(e) =>
													setElevationUnit(e.target.value as ElevationUnit)
												}
											>
												<option value="m">m</option>
												<option value="ft">ft</option>
											</Select>
										</div>
									</div>
								)}

								{supportsPace && (
									<div className="grid gap-2 md:col-span-2">
										<Label>Target Pace</Label>
										<div className="grid grid-cols-[minmax(0,1fr)_minmax(0,1fr)_128px] gap-2">
											<Input
												type="number"
												inputMode="numeric"
												min={0}
												step={1}
												value={paceMinutes}
												onChange={(e) => setPaceMinutes(e.target.value)}
												placeholder="Minutes"
											/>
											<Input
												type="number"
												inputMode="numeric"
												min={0}
												max={59}
												step={1}
												value={paceSeconds}
												onChange={(e) => setPaceSeconds(e.target.value)}
												placeholder="Seconds"
											/>
											<Select
												value={paceUnit}
												onChange={(e) =>
													setPaceUnit(e.target.value as PaceUnit)
												}
											>
												<option value="min_per_km">/km</option>
												<option value="min_per_mile">/mi</option>
											</Select>
										</div>
									</div>
								)}

								{supportsAvgSpeed && (
									<div className="grid gap-2">
										<Label htmlFor={avgSpeedInputId}>Target Avg Speed</Label>
										<div className="grid grid-cols-[minmax(0,1fr)_112px] gap-2">
											<Input
												id={avgSpeedInputId}
												type="number"
												inputMode="decimal"
												min={0}
												step="0.1"
												value={avgSpeed}
												onChange={(e) => setAvgSpeed(e.target.value)}
												placeholder="28"
											/>
											<Select
												value={speedUnit}
												onChange={(e) =>
													setSpeedUnit(e.target.value as SpeedUnit)
												}
											>
												<option value="kmh">km/h</option>
												<option value="mph">mph</option>
											</Select>
										</div>
									</div>
								)}

								{supportsPower && (
									<div className="grid gap-2">
										<Label htmlFor={targetPowerInputId}>Target Power (W)</Label>
										<Input
											id={targetPowerInputId}
											type="number"
											inputMode="numeric"
											min={0}
											step={1}
											value={targetPower}
											onChange={(e) => setTargetPower(e.target.value)}
											placeholder="220"
										/>
									</div>
								)}
							</div>
						</div>

						<div className="grid gap-2">
							<Label htmlFor={descriptionInputId}>Description</Label>
							<textarea
								id={descriptionInputId}
								value={description}
								onChange={(e) => setDescription(e.target.value)}
								placeholder="Workout details, perceived effort, notes..."
								className="flex min-h-28 w-full rounded-md border border-input bg-transparent px-3 py-2 text-sm shadow-sm placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:cursor-not-allowed disabled:opacity-50 resize-none"
							/>
						</div>

						{error && (
							<p className="rounded-md border border-destructive/30 bg-destructive/5 px-3 py-2 text-xs text-destructive">
								{error}
							</p>
						)}
					</div>

					<div className="p-6 border-t shrink-0 flex items-center justify-end gap-2 bg-muted/40">
						<Button type="button" variant="outline" onClick={onClose}>
							Cancel
						</Button>
						<Button type="submit" disabled={mutation.isPending}>
							{mutation.isPending ? "Saving..." : "Save Activity"}
						</Button>
					</div>
				</form>
			</div>
		</div>
	);
}
