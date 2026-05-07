import {
	Activity,
	Bike,
	CircleDot,
	Dumbbell,
	PersonStanding,
} from "lucide-react";
import { formatElapsed } from "@/lib/format";
import { formatPlannedActivityTypeLabel } from "@/lib/planned-activity";
import { cn } from "@/lib/utils";

export interface CalendarEventData {
	id: string;
	title: string;
	type: string;
	start: Date;
	end: Date;
	isPlanned: boolean;
	distance?: number;
	duration?: number;
	elevationGain?: number;
	avgSpeedMps?: number;
	targetPower?: number;
}

function formatDistanceMeters(distanceMeters: number): string {
	const km = distanceMeters / 1000;
	return km >= 10 ? `${km.toFixed(0)} km` : `${km.toFixed(1)} km`;
}

function getTypeIcon(type: string) {
	switch (type) {
		case "road_biking":
			return Bike;
		case "strength_training":
			return Dumbbell;
		case "mobility_training":
			return PersonStanding;
		case "resting":
			return CircleDot;
		default:
			return Activity;
	}
}

export function CalendarEventWrapper({ event }: { event: CalendarEventData }) {
	const TypeIcon = getTypeIcon(event.type);
	const isPlanned = event.isPlanned;
	const metrics: string[] = [];

	if (event.duration != null && event.duration > 0) {
		metrics.push(formatElapsed(event.duration));
	}
	if (event.distance != null && event.distance > 0) {
		metrics.push(formatDistanceMeters(event.distance));
	}
	if (isPlanned && event.targetPower != null && event.targetPower > 0) {
		metrics.push(`${Math.round(event.targetPower)} W`);
	}

	return (
		<div
			className={cn(
				"w-full h-full flex flex-col gap-1 p-2 overflow-hidden rounded-md border text-[11px] leading-tight",
				isPlanned
					? "border-primary/40 bg-primary/10 text-foreground"
					: "border-chart-2/50 bg-chart-2/15 text-foreground",
			)}
		>
			<div className="flex items-center gap-1 text-[10px] font-semibold uppercase tracking-wide">
				<TypeIcon className="size-3 shrink-0" strokeWidth={2} />
				<span className="truncate">{isPlanned ? "Planned" : "Completed"}</span>
			</div>

			<div className="truncate text-xs font-semibold">{event.title}</div>

			{metrics.length > 0 ? (
				<div className="truncate opacity-90">
					{metrics.slice(0, 2).join(" • ")}
				</div>
			) : (
				<div className="truncate opacity-80">
					{formatPlannedActivityTypeLabel(event.type)}
				</div>
			)}
		</div>
	);
}
