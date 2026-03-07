import {
	Activity,
	Bike,
	Clock,
	Footprints,
	Ruler,
	TrendingUp,
} from "lucide-react";
import type { Activity as ActivityType } from "@/lib/api";
import {
	formatActivityDate,
	formatDistance,
	formatElapsed,
	formatElevation,
	formatPace,
	formatSpeed,
} from "@/lib/format";
import { cn } from "@/lib/utils";
import { ActivityMapPreview } from "./activity-map-preview";

// ---- Activity type meta ----

function getActivityMeta(type: string): {
	label: string;
	Icon: React.ElementType;
	color: string;
} {
	switch (type) {
		case "run":
			return { label: "Run", Icon: Footprints, color: "text-orange-500" };
		case "road_bike":
			return { label: "Road Ride", Icon: Bike, color: "text-blue-500" };
		default:
			return { label: type, Icon: Activity, color: "text-muted-foreground" };
	}
}

// ---- Stat cell ----

function StatCell({
	icon: Icon,
	value,
	label,
}: {
	icon: React.ElementType;
	value: string;
	label: string;
}) {
	return (
		<div className="flex flex-col gap-0.5 min-w-0">
			<div className="flex items-baseline gap-1.5">
				<Icon
					className="size-3.5 text-muted-foreground shrink-0 self-center"
					strokeWidth={2}
				/>
				<span className="text-base font-semibold tabular-nums leading-none">
					{value}
				</span>
			</div>
			<span className="text-xs text-muted-foreground pl-5">{label}</span>
		</div>
	);
}

// ---- Activity Card ----

interface ActivityCardProps {
	activity: ActivityType;
	className?: string;
}

export function ActivityCard({ activity, className }: ActivityCardProps) {
	const { label, Icon, color } = getActivityMeta(activity.type);
	const { stats } = activity;

	const hasMap = Boolean(activity.polyline);

	return (
		<article
			className={cn(
				"bg-card text-card-foreground rounded-xl border shadow-sm overflow-hidden",
				className,
			)}
		>
			{/* Header */}
			<div className="flex items-start gap-3 px-5 pt-5 pb-4">
				<div
					className={cn(
						"mt-0.5 flex size-9 shrink-0 items-center justify-center rounded-lg bg-muted",
						color,
					)}
				>
					<Icon className="size-5" strokeWidth={1.75} />
				</div>
				<div className="min-w-0 flex-1">
					<h2 className="truncate text-base font-semibold leading-tight">
						{activity.title}
					</h2>
					<p className="mt-0.5 flex items-center gap-1 text-xs text-muted-foreground">
						<span>{label}</span>
						<span className="opacity-40">·</span>
						<span>{formatActivityDate(activity.start_time)}</span>
					</p>
				</div>
			</div>

			{/* Divider */}
			<div className="mx-5 border-t" />

			{/* Stats */}
			{/* TODO: respect user unit preferences (metric/imperial) once settings screen is added */}
			<div className="grid grid-cols-4 gap-4 px-5 py-4">
				<StatCell
					icon={Ruler}
					value={formatDistance(stats.derived.distance_km)}
					label="Distance"
				/>
				{activity.type === "road_bike" ? (
					<StatCell
						icon={Activity}
						value={formatSpeed(stats.derived.speed_kmh)}
						label="Avg Speed"
					/>
				) : (
					<StatCell
						icon={Clock}
						value={formatPace(stats.derived.pace_s_per_km)}
						label="Pace"
					/>
				)}
				<StatCell
					icon={Clock}
					value={formatElapsed(stats.elapsed_seconds)}
					label="Time"
				/>
				<StatCell
					icon={TrendingUp}
					value={formatElevation(stats.elevation_gain_m)}
					label="Elevation"
				/>
			</div>

			{/* Map */}
			{hasMap && <ActivityMapPreview activity={activity} className="h-44" />}
		</article>
	);
}
