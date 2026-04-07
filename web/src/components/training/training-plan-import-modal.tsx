import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { format } from "date-fns";
import { Minus, Plus } from "lucide-react";
import * as React from "react";
import { useDebounce } from "use-debounce";

import { TrainingPlanImportCalendarPreview } from "@/components/training/training-plan-import-calendar-preview";
import { Button } from "@/components/ui/button";
import { DatePicker } from "@/components/ui/date-picker";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
	type ImportTrainingPlanRequest,
	importTrainingPlanDryRun,
	importTrainingPlan,
	type TrainingPlan,
} from "@/lib/api";

interface TrainingPlanImportModalProps {
	isOpen: boolean;
	onClose: () => void;
	plan: TrainingPlan | null;
}

function clampWorkoutsPerWeek(value: number) {
	return Math.max(1, Math.min(7, value));
}

function toStartDateISO(value: string): string | null {
	if (!value) {
		return null;
	}

	const parsed = new Date(`${value}T09:00:00`);
	if (Number.isNaN(parsed.getTime())) {
		return null;
	}

	return parsed.toISOString();
}

export function TrainingPlanImportModal({
	isOpen,
	onClose,
	plan,
}: TrainingPlanImportModalProps) {
	const queryClient = useQueryClient();
	const startDateInputId = React.useId();
	const workoutsInputId = React.useId();
	const titleInputId = React.useId();
	const descriptionInputId = React.useId();

	const [startDate, setStartDate] = React.useState(format(new Date(), "yyyy-MM-dd"));
	const [workoutsPerWeekInput, setWorkoutsPerWeekInput] = React.useState("1");
	const [title, setTitle] = React.useState("");
	const [description, setDescription] = React.useState("");
	const [error, setError] = React.useState("");

	React.useEffect(() => {
		if (!isOpen || !plan) {
			return;
		}

		setStartDate(format(new Date(), "yyyy-MM-dd"));
		setWorkoutsPerWeekInput(String(clampWorkoutsPerWeek(plan.recommended_workouts_per_week)));
		setTitle(plan.title);
		setDescription(plan.description ?? "");
		setError("");
	}, [isOpen, plan]);

	const mutation = useMutation({
		mutationFn: async (payload: ImportTrainingPlanRequest) => {
			if (!plan) {
				throw new Error("No training plan selected");
			}
			return importTrainingPlan(plan.id, payload);
		},
		onSuccess: () => {
			queryClient.invalidateQueries({ queryKey: ["calendar"] });
			onClose();
		},
		onError: (mutationError) => {
			setError(
				mutationError instanceof Error
					? mutationError.message
					: "Failed to import training plan",
			);
		},
	});

	const parsedWorkouts = Number.parseInt(workoutsPerWeekInput, 10);
	const resolvedWorkoutsPerWeek = Number.isNaN(parsedWorkouts)
		? 1
		: clampWorkoutsPerWeek(parsedWorkouts);
	const [debouncedStartDate] = useDebounce(startDate, 250);
	const [debouncedWorkoutsPerWeek] = useDebounce(resolvedWorkoutsPerWeek, 250);
	const [debouncedTitle] = useDebounce(title, 250);
	const [debouncedDescription] = useDebounce(description, 250);
	const debouncedStartDateIso = React.useMemo(
		() => toStartDateISO(debouncedStartDate),
		[debouncedStartDate],
	);

	const dryRunQuery = useQuery({
		queryKey: [
			"training-plan-import-dry-run",
			plan?.id,
			debouncedStartDateIso,
			debouncedWorkoutsPerWeek,
			debouncedTitle,
			debouncedDescription,
		],
		queryFn: async () => {
			if (!plan || !debouncedStartDateIso) {
				throw new Error("Missing dry-run import inputs");
			}

			return importTrainingPlanDryRun(plan.id, {
				startDate: debouncedStartDateIso,
				selectedWorkoutsPerWeek: debouncedWorkoutsPerWeek,
				title: debouncedTitle.trim() || null,
				description: debouncedDescription.trim() || null,
			});
		},
		enabled:
			isOpen &&
			!!plan &&
			!!debouncedStartDateIso &&
			debouncedWorkoutsPerWeek >= 1 &&
			debouncedWorkoutsPerWeek <= 7,
	});

	if (!isOpen || !plan) {
		return null;
	}

	const handleDecrement = () => {
		setWorkoutsPerWeekInput(String(clampWorkoutsPerWeek(resolvedWorkoutsPerWeek - 1)));
	};

	const handleIncrement = () => {
		setWorkoutsPerWeekInput(String(clampWorkoutsPerWeek(resolvedWorkoutsPerWeek + 1)));
	};

	const handleWorkoutsBlur = () => {
		setWorkoutsPerWeekInput(String(resolvedWorkoutsPerWeek));
	};

	const handleSubmit = (event: React.FormEvent<HTMLFormElement>) => {
		event.preventDefault();

		if (!title.trim()) {
			setError("Title is required");
			return;
		}

		if (!startDate) {
			setError("Start date is required");
			return;
		}

		const normalizedWorkouts = Number.parseInt(workoutsPerWeekInput, 10);
		if (
			Number.isNaN(normalizedWorkouts) ||
			normalizedWorkouts < 1 ||
			normalizedWorkouts > 7
		) {
			setError("Selected workouts per week must be between 1 and 7");
			return;
		}

		const startDateIso = toStartDateISO(startDate);
		if (!startDateIso) {
			setError("Please provide a valid start date");
			return;
		}

		setError("");
		mutation.mutate({
			startDate: startDateIso,
			selectedWorkoutsPerWeek: normalizedWorkouts,
			title: title.trim(),
			description: description.trim() || null,
		});
	};

	return (
		<div
			className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4"
			onClick={onClose}
		>
			<div
				className="bg-card h-[88vh] w-[95vw] max-w-330 rounded-xl border shadow-lg"
				onClick={(event) => event.stopPropagation()}
			>
				<form onSubmit={handleSubmit} className="flex h-full flex-col overflow-hidden">
					<div className="flex items-start justify-between gap-3 border-b px-6 py-5">
						<div>
							<h2 className="text-xl font-bold">Import Training Plan</h2>
							<p className="mt-1 text-sm text-muted-foreground">
								Review and adjust details before adding workouts to calendar.
							</p>
						</div>
						<div className="flex items-center gap-2">
							<Button type="button" variant="outline" onClick={onClose}>
								Cancel
							</Button>
							<Button type="submit" disabled={mutation.isPending}>
								{mutation.isPending ? "Adding..." : "Add to Calendar"}
							</Button>
						</div>
					</div>

					<div className="grid flex-1 gap-6 overflow-y-auto p-6 md:grid-cols-[minmax(0,1.05fr)_minmax(0,1.25fr)]">
						<div className="space-y-5">
							<div className="grid gap-2">
								<Label htmlFor={startDateInputId}>Start Date</Label>
								<DatePicker
									id={startDateInputId}
									value={startDate}
									onChange={setStartDate}
								/>
							</div>

							<div className="grid gap-2">
								<Label htmlFor={workoutsInputId}>Selected Workouts Per Week</Label>
								<div className="grid grid-cols-[40px_minmax(0,1fr)_40px] gap-2">
									<Button
										type="button"
										variant="outline"
										size="icon-sm"
										onClick={handleDecrement}
									>
										<Minus className="h-4 w-4" />
									</Button>
									<Input
										id={workoutsInputId}
										type="number"
										inputMode="numeric"
										min={1}
										max={7}
										step={1}
										value={workoutsPerWeekInput}
										onChange={(event) => setWorkoutsPerWeekInput(event.target.value)}
										onBlur={handleWorkoutsBlur}
										className="text-center"
									/>
									<Button
										type="button"
										variant="outline"
										size="icon-sm"
										onClick={handleIncrement}
									>
										<Plus className="h-4 w-4" />
									</Button>
								</div>
							</div>

							<div className="grid gap-2">
								<Label htmlFor={titleInputId}>Title</Label>
								<Input
									id={titleInputId}
									value={title}
									onChange={(event) => setTitle(event.target.value)}
									placeholder="Plan title"
								/>
							</div>

							<div className="grid gap-2">
								<Label htmlFor={descriptionInputId}>Description</Label>
								<textarea
									id={descriptionInputId}
									value={description}
									onChange={(event) => setDescription(event.target.value)}
									placeholder="Plan description"
									rows={5}
									className="border-input focus-visible:border-ring focus-visible:ring-ring/50 w-full rounded-md border bg-transparent px-3 py-2 text-sm outline-none focus-visible:ring-[3px]"
								/>
							</div>
						</div>

						<TrainingPlanImportCalendarPreview
							data={dryRunQuery.data}
							isLoading={dryRunQuery.isLoading || dryRunQuery.isFetching}
							errorMessage={
								dryRunQuery.error instanceof Error
									? dryRunQuery.error.message
									: undefined
							}
							focusDate={startDate}
						/>
					</div>

					{error && (
						<div className="border-t px-6 py-4">
							<p className="rounded-md border border-destructive/30 bg-destructive/5 px-3 py-2 text-xs text-destructive">
								{error}
							</p>
						</div>
					)}
				</form>
			</div>
		</div>
	);
}
