import { useState, useMemo } from "react";
import { createFileRoute } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import {
	Search,
	Loader2,
	Dumbbell,
	Route as RouteIcon,
	ArrowDownToLine,
	Clock,
	CalendarDays,
} from "lucide-react";
import { TrainingPlanImportModal } from "@/components/training/training-plan-import-modal";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { getTrainingPlans, getTrainingPlanWorkouts } from "@/lib/api";
import { cn } from "@/lib/utils";
import { useDebounce } from "use-debounce";

export const Route = createFileRoute("/_authenticated/training/plans")({
	component: TrainingPlansPage,
});

function TrainingPlansPage() {
	const [search, setSearch] = useState("");
	const [debouncedSearch] = useDebounce(search, 300);
	const [sport, setSport] = useState("all");
	const [selectedPlanId, setSelectedPlanId] = useState<string | null>(null);
	const [isImportModalOpen, setImportModalOpen] = useState(false);

	const { data: plans, isLoading: isPlansLoading } = useQuery({
		queryKey: ["training-plans", debouncedSearch, sport],
		queryFn: () => getTrainingPlans(debouncedSearch, sport),
	});

	const selectedPlan = plans?.find((p) => p.id === selectedPlanId) || null;

	const { data: workouts, isLoading: isWorkoutsLoading } = useQuery({
		queryKey: ["training-plans", selectedPlanId, "workouts"],
		queryFn: () => getTrainingPlanWorkouts(selectedPlanId!),
		enabled: !!selectedPlanId,
	});

	const weeks = useMemo(() => {
		if (!workouts || workouts.length === 0) return [];
		const maxIndex = Math.max(...workouts.map((w) => w.sequence_index), 1);
		const totalWeeks = Math.ceil(maxIndex / 7);

		const weeksArray = Array.from({ length: totalWeeks }, (_, i) => ({
			weekNumber: i + 1,
			workouts: [] as typeof workouts,
		}));

		workouts.forEach((w) => {
			const wk = Math.max(0, Math.floor((w.sequence_index - 1) / 7));
			if (weeksArray[wk]) {
				weeksArray[wk].workouts.push(w);
			}
		});

		weeksArray.forEach((w) =>
			w.workouts.sort((a, b) => a.sequence_index - b.sequence_index),
		);
		return weeksArray;
	}, [workouts]);

	return (
		<div className="flex h-[calc(100vh-theme(spacing.16))] w-full">
			{/* LEFT COLUMN - Narrow sidebar for plans */}
			<div className="w-[340px] border-r bg-muted/20 flex flex-col h-full shrink-0">
				<div className="p-5 border-b space-y-4">
					<h1 className="text-xl font-bold tracking-tight">Training Plans</h1>

					<div className="space-y-3">
						<div className="relative">
							<Search className="absolute left-3 top-2.5 h-4 w-4 text-muted-foreground" />
							<Input
								type="search"
								placeholder="Search plans..."
								className="pl-9 bg-background h-9"
								value={search}
								onChange={(e) => setSearch(e.target.value)}
							/>
						</div>
						<div className="flex gap-2 text-sm overflow-x-auto pb-1 no-scrollbar">
							{(["all", "running", "road_biking"] as const).map((s) => (
								<button
									key={s}
									onClick={() => setSport(s)}
									className={cn(
										"px-3.5 py-1.5 rounded-full capitalize transition-colors font-medium border text-[13px] whitespace-nowrap",
										sport === s
											? "bg-primary text-primary-foreground border-primary"
											: "bg-background text-muted-foreground hover:bg-muted border-border",
									)}
								>
									{s.replace("_", " ")}
								</button>
							))}
						</div>
					</div>
				</div>

				<div className="flex-1 overflow-y-auto p-4 space-y-2.5">
					{isPlansLoading ? (
						<div className="flex justify-center p-8 text-muted-foreground">
							<Loader2 className="h-5 w-5 animate-spin" />
						</div>
					) : plans?.length === 0 ? (
						<div className="text-center p-8 text-sm text-muted-foreground">
							No training plans found.
						</div>
					) : (
						plans?.map((plan) => (
							<button
								key={plan.id}
								onClick={() => setSelectedPlanId(plan.id)}
								className={cn(
									"w-full text-left p-4 rounded-xl border transition-all hover:border-primary/40 flex flex-col items-start gap-1 cursor-pointer",
									selectedPlanId === plan.id
										? "bg-primary/[0.03] border-primary shadow-sm ring-1 ring-primary"
										: "bg-card hover:bg-muted/30",
								)}
							>
								<div className="flex items-center gap-1.5 text-[11px] text-muted-foreground font-semibold uppercase tracking-wider mb-0.5">
									{plan.primary_sport === "run" ||
									plan.primary_sport === "run" ||
									plan.primary_sport === "running" ? (
										<RouteIcon className="h-3 w-3" />
									) : (
										<Dumbbell className="h-3 w-3" />
									)}
									{plan.primary_sport
										? plan.primary_sport.replace("_", " ")
										: ""}
								</div>
								<h3 className="font-semibold text-[15px] leading-tight line-clamp-1 text-foreground">
									{plan.title}
								</h3>
								<p className="text-xs text-muted-foreground line-clamp-2 mt-1 leading-relaxed">
									{plan.description}
								</p>
							</button>
						))
					)}
				</div>
			</div>

			{/* RIGHT COLUMN - Plan details & Timeline */}
			<div className="flex-1 min-w-0 flex flex-col overflow-hidden bg-background">
				{!selectedPlan ? (
					<div className="flex-1 flex flex-col items-center justify-center text-muted-foreground p-8 bg-muted/5">
						<div className="h-20 w-20 mb-6 rounded-3xl bg-muted/50 flex items-center justify-center rotate-3 transition-transform hover:rotate-6">
							<CalendarDays className="h-10 w-10 text-muted-foreground/40" />
						</div>
						<p className="text-xl font-semibold text-foreground">
							Select a Plan
						</p>
						<p className="text-sm mt-2 max-w-[280px] text-center leading-relaxed">
							Choose a training plan from the sidebar to inspect its schedule
							and workouts.
						</p>
					</div>
				) : (
					<>
						<div className="border-b px-10 py-8 flex items-start justify-between gap-6 shrink-0 bg-card">
							<div className="pt-1">
								<div className="flex items-center gap-3 mb-3">
									<span className="text-[11px] font-bold px-2.5 py-1 rounded-md bg-primary/10 text-primary uppercase tracking-widest">
										{selectedPlan.primary_sport
											? selectedPlan.primary_sport
												? selectedPlan.primary_sport.replace("_", " ")
												: ""
											: ""}
									</span>
								</div>
								<h2 className="text-3xl font-black tracking-tight mb-3 text-foreground">
									{selectedPlan.title}
								</h2>
								<p className="text-muted-foreground max-w-3xl text-[15px] leading-relaxed">
									{selectedPlan.description}
								</p>
							</div>
							<div className="flex shrink-0 gap-3 pt-2">
								<Button
									className="rounded-full px-6 gap-2 shadow-sm font-semibold"
									variant="default"
									onClick={() => setImportModalOpen(true)}
								>
									<ArrowDownToLine className="h-4 w-4" />
									Import Plan
								</Button>
							</div>
						</div>

						<div className="flex-1 overflow-y-auto px-10 py-8 bg-muted/10 relative">
							<div className="max-w-4xl mx-auto relative z-10">
								<div className="flex items-center justify-between mb-8">
									<h3 className="text-xl font-bold tracking-tight text-foreground flex items-center gap-2.5">
										<CalendarDays className="h-5 w-5 text-primary" />
										Plan Timeline
									</h3>
									<div className="text-sm font-medium text-muted-foreground">
										{weeks.length > 0
											? `${weeks.length} Week${weeks.length > 1 ? "s" : ""}`
											: ""}
									</div>
								</div>

								{isWorkoutsLoading ? (
									<div className="flex justify-center py-20 text-muted-foreground">
										<Loader2 className="h-8 w-8 animate-spin" />
									</div>
								) : weeks.length === 0 ? (
									<div className="text-center py-16 border-2 rounded-2xl border-dashed bg-card/50 text-muted-foreground">
										<div className="mx-auto w-12 h-12 bg-muted rounded-full flex items-center justify-center mb-4">
											<CalendarDays className="h-6 w-6 opacity-30" />
										</div>
										<p className="font-medium text-foreground">
											No Workouts Found
										</p>
										<p className="text-sm mt-1">
											This plan has no scheduled workouts.
										</p>
									</div>
								) : (
									<div className="space-y-12">
										{weeks.map((week) => (
											<div key={week.weekNumber} className="relative">
												<div className="flex items-center gap-4 mb-6 relative z-10">
													<div className="w-10 h-10 rounded-full bg-primary text-primary-foreground flex items-center justify-center font-bold text-sm shrink-0 border-[3px] shadow-sm border-background">
														W{week.weekNumber}
													</div>
													<h4 className="text-lg font-bold text-foreground">
														Week {week.weekNumber}
													</h4>
													<div className="flex-1 border-t border-dashed border-border/60 ml-2" />
												</div>

												<div className="grid grid-cols-1 md:grid-cols-2 gap-4 md:pl-16">
													{week.workouts.map((workout) => (
														<div
															key={workout.id}
															className="group relative flex flex-col bg-card rounded-2xl border p-5 shadow-sm hover:shadow-md hover:border-primary/30 hover:ring-1 hover:ring-primary/20 transition-all"
														>
															<div className="flex items-start justify-between gap-3 mb-3">
																<div className="flex items-center gap-3">
																	<span className="inline-flex items-center justify-center px-3 h-8 rounded-full bg-muted/80 text-foreground text-xs font-bold">
																		Day {((workout.sequence_index - 1) % 7) + 1}
																	</span>
																	<h5 className="font-bold text-[15px] leading-tight text-foreground group-hover:text-primary transition-colors">
																		{workout.title}
																	</h5>
																</div>
															</div>

															<p className="text-sm text-muted-foreground flex-1 mb-4 line-clamp-3">
																{workout.description}
															</p>

															<div className="flex flex-wrap items-center gap-x-4 gap-y-2 mt-auto pt-3 border-t border-border/50">
																{workout.planned_duration_s != null && (
																	<div className="flex items-center gap-1.5 text-[13px] font-medium text-foreground bg-muted/40 px-2 py-1 rounded-md">
																		<Clock className="h-3.5 w-3.5 text-muted-foreground" />
																		{Math.round(
																			workout.planned_duration_s! / 60,
																		)}
																		m
																	</div>
																)}
																{workout.planned_distance_m != null && (
																	<div className="flex items-center gap-1.5 text-[13px] font-medium text-foreground bg-muted/40 px-2 py-1 rounded-md">
																		<RouteIcon className="h-3.5 w-3.5 text-muted-foreground" />
																		{(workout.planned_distance_m / 1000).toFixed(
																			1,
																		)}
																		km
																	</div>
																)}
																{workout.type && (
																	<div className="ml-auto text-[10px] font-bold uppercase tracking-wider text-muted-foreground px-2.5 py-1 bg-muted/80 rounded-md shrink-0">
																		{workout.type.replace("_", " ")}
																	</div>
																)}
															</div>
														</div>
													))}
												</div>
											</div>
										))}
									</div>
								)}
							</div>
						</div>
					</>
				)}
				<TrainingPlanImportModal
					isOpen={isImportModalOpen}
					onClose={() => setImportModalOpen(false)}
					plan={selectedPlan}
				/>
			</div>
		</div>
	);
}
