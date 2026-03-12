import {
	Bike,
	Calendar,
	Clock,
	Footprints,
	Ruler,
	TrendingUp,
} from "lucide-react";
import type { Activity } from "@/lib/api";
import { cn } from "@/lib/utils";

// ---- Week bounds ----

function getWeekBounds(): { start: Date; end: Date; label: string } {
	const now = new Date();
	// ISO week: Monday = day 1
	const dayOfWeek = now.getDay(); // 0=Sun
	const monday = new Date(now);
	monday.setDate(now.getDate() - ((dayOfWeek + 6) % 7));
	monday.setHours(0, 0, 0, 0);

	const sunday = new Date(monday);
	sunday.setDate(monday.getDate() + 6);
	sunday.setHours(23, 59, 59, 999);

	const fmt = (d: Date) =>
		d.toLocaleDateString(undefined, { month: "short", day: "numeric" });

	return {
		start: monday,
		end: sunday,
		label: `${fmt(monday)} – ${fmt(sunday)}`,
	};
}

// ---- Stats aggregation ----

interface WeekStats {
	total: number;
	runs: number;
	rides: number;
	distanceKm: number;
	elapsedSeconds: number;
	elevationM: number;
}

function computeWeekStats(activities: Activity[]): WeekStats {
	const { start, end } = getWeekBounds();

	const week = activities.filter((a) => {
		const t = new Date(a.start_time);
		return t >= start && t <= end;
	});

	return week.reduce<WeekStats>(
		(acc, a) => ({
			total: acc.total + 1,
			runs: acc.runs + (a.type === "run" ? 1 : 0),
			rides: acc.rides + (a.type === "road_bike" ? 1 : 0),
			distanceKm: acc.distanceKm + a.stats.derived.distance_km,
			elapsedSeconds: acc.elapsedSeconds + a.stats.elapsed_seconds,
			elevationM: acc.elevationM + a.stats.elevation_gain_m,
		}),
		{
			total: 0,
			runs: 0,
			rides: 0,
			distanceKm: 0,
			elapsedSeconds: 0,
			elevationM: 0,
		},
	);
}

// ---- Formatting ----

function formatDuration(seconds: number): string {
	const h = Math.floor(seconds / 3600);
	const m = Math.floor((seconds % 3600) / 60);
	if (h > 0) return `${h}h ${m}m`;
	return `${m}m`;
}

// ---- Sub-components ----

function StatRow({
	icon: Icon,
	label,
	value,
}: {
	icon: React.ElementType;
	label: string;
	value: string;
}) {
	return (
		<div className="flex items-center justify-between gap-3">
			<div className="flex items-center gap-2 text-muted-foreground">
				<Icon className="size-3.5 shrink-0" strokeWidth={1.75} />
				<span className="text-xs">{label}</span>
			</div>
			<span className="text-sm font-semibold tabular-nums">{value}</span>
		</div>
	);
}

function Skeleton({ className }: { className?: string }) {
	return <div className={cn("animate-pulse rounded bg-muted", className)} />;
}

function WeekSummaryPanelSkeleton() {
	return (
		<div className="rounded-xl border bg-card shadow-sm p-5 space-y-4">
			<div className="flex items-center gap-2">
				<Skeleton className="size-4 rounded" />
				<Skeleton className="h-4 w-20" />
			</div>
			<Skeleton className="h-3 w-32" />
			<div className="pt-1 space-y-3">
				<Skeleton className="h-6 w-24" />
				<div className="space-y-2.5 pt-1">
					{(["distance", "time", "elevation"] as const).map((key) => (
						<div key={key} className="flex justify-between">
							<Skeleton className="h-3 w-16" />
							<Skeleton className="h-3 w-12" />
						</div>
					))}
				</div>
			</div>
		</div>
	);
}

// ---- Main component ----

interface WeekSummaryPanelProps {
	activities: Activity[];
	isLoading: boolean;
}

export function WeekSummaryPanel({
	activities,
	isLoading,
}: WeekSummaryPanelProps) {
	if (isLoading) return <WeekSummaryPanelSkeleton />;

	const { label } = getWeekBounds();
	const stats = computeWeekStats(activities);

	// TODO: replace aggregated stats with a dedicated /v1/stats endpoint when available
	// we would rpobably use this for more complex stat related queries from clients

	return (
		<div className="rounded-xl border bg-card shadow-sm p-5">
			{/* Header */}
			<div className="flex items-center gap-2 mb-1">
				<Calendar className="size-4 text-muted-foreground" strokeWidth={1.75} />
				<span className="text-sm font-semibold">This Week</span>
			</div>
			<p className="text-xs text-muted-foreground mb-4 pl-6">{label}</p>

			{stats.total === 0 ? (
				<p className="text-sm text-muted-foreground leading-relaxed">
					No activities recorded this week yet.
				</p>
			) : (
				<div className="space-y-4">
					{/* Activity type breakdown */}
					<div className="flex items-center gap-3">
						{stats.runs > 0 && (
							<div className="flex items-center gap-1.5">
								<Footprints
									className="size-3.5 text-orange-500"
									strokeWidth={1.75}
								/>
								<span className="text-sm font-semibold">
									{stats.runs} {stats.runs === 1 ? "run" : "runs"}
								</span>
							</div>
						)}
						{stats.rides > 0 && (
							<div className="flex items-center gap-1.5">
								<Bike className="size-3.5 text-blue-500" strokeWidth={1.75} />
								<span className="text-sm font-semibold">
									{stats.rides} {stats.rides === 1 ? "ride" : "rides"}
								</span>
							</div>
						)}
					</div>

					{/* Divider */}
					<div className="border-t" />

					{/* Stat rows */}
					<div className="space-y-2.5">
						<StatRow
							icon={Ruler}
							label="Distance"
							// TODO: respect user unit preference (metric/imperial) once settings screen exists
							value={`${stats.distanceKm.toFixed(1)} km`}
						/>
						<StatRow
							icon={Clock}
							label="Time"
							value={formatDuration(stats.elapsedSeconds)}
						/>
						<StatRow
							icon={TrendingUp}
							label="Elevation"
							value={`+${Math.round(stats.elevationM)} m`}
						/>
					</div>
				</div>
			)}
		</div>
	);
}
