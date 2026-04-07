import {
	addMonths,
	addDays,
	endOfMonth,
	endOfWeek,
	format,
	isAfter,
	isBefore,
	isSameMonth,
	parseISO,
	startOfMonth,
	startOfWeek,
} from "date-fns";
import { CalendarDays, ChevronLeft, ChevronRight } from "lucide-react";
import * as React from "react";

import { Button } from "@/components/ui/button";
import type { GetCalendarResponse } from "@/lib/api";
import { cn } from "@/lib/utils";

type PreviewItemKind = "completed" | "planned" | "import";

interface PreviewItem {
	id: string;
	title: string;
	start: Date;
	kind: PreviewItemKind;
}

interface TrainingPlanImportCalendarPreviewProps {
	data?: GetCalendarResponse;
	isLoading: boolean;
	errorMessage?: string;
	focusDate: string;
}

function parseLocalDay(value: string): Date {
	const parsed = parseISO(`${value}T00:00:00`);
	if (Number.isNaN(parsed.getTime())) {
		return startOfMonth(new Date());
	}
	return parsed;
}

function itemTone(kind: PreviewItemKind): string {
	switch (kind) {
		case "import":
			return "border-primary bg-primary text-primary-foreground";
		case "completed":
			return "border-chart-2/40 bg-chart-2/10 text-foreground";
		default:
			return "border-border bg-muted/50 text-foreground";
	}
}

export function TrainingPlanImportCalendarPreview({
	data,
	isLoading,
	errorMessage,
	focusDate,
}: TrainingPlanImportCalendarPreviewProps) {
	const focusedMonth = React.useMemo(
		() => startOfMonth(parseLocalDay(focusDate)),
		[focusDate],
	);
	const [visibleMonth, setVisibleMonth] = React.useState(focusedMonth);

	React.useEffect(() => {
		setVisibleMonth(focusedMonth);
	}, [focusedMonth]);

	const previewItems = React.useMemo<PreviewItem[]>(() => {
		if (!data) {
			return [];
		}

		const items: PreviewItem[] = [];

		for (const activity of data.activities) {
			const start = new Date(activity.start_time);
			if (Number.isNaN(start.getTime())) {
				continue;
			}

			items.push({
				id: activity.id,
				title: activity.title,
				start,
				kind: "completed",
			});
		}

		for (const planned of data.planned_activities) {
			if (planned.matched_activity_id) {
				continue;
			}

			const start = new Date(planned.start_time);
			if (Number.isNaN(start.getTime())) {
				continue;
			}

			items.push({
				id: planned.id,
				title: planned.title,
				start,
				kind: planned.is_dry_run ? "import" : "planned",
			});
		}

		items.sort((a, b) => a.start.getTime() - b.start.getTime());
		return items;
	}, [data]);

	const previewSummary = React.useMemo(() => {
		let imported = 0;
		let planned = 0;
		let completed = 0;

		for (const item of previewItems) {
			if (item.kind === "import") {
				imported += 1;
			} else if (item.kind === "planned") {
				planned += 1;
			} else {
				completed += 1;
			}
		}

		return { imported, planned, completed };
	}, [previewItems]);

	const monthBounds = React.useMemo(() => {
		if (previewItems.length === 0) {
			return { minMonth: focusedMonth, maxMonth: focusedMonth };
		}

		const first = startOfMonth(previewItems[0].start);
		const last = startOfMonth(previewItems[previewItems.length - 1].start);
		return { minMonth: first, maxMonth: last };
	}, [focusedMonth, previewItems]);

	const daysByKey = React.useMemo(() => {
		const map = new Map<string, PreviewItem[]>();
		for (const item of previewItems) {
			const key = format(item.start, "yyyy-MM-dd");
			const existing = map.get(key);
			if (existing) {
				existing.push(item);
			} else {
				map.set(key, [item]);
			}
		}
		return map;
	}, [previewItems]);

	const gridDays = React.useMemo(() => {
		const monthStart = startOfMonth(visibleMonth);
		const monthEnd = endOfMonth(visibleMonth);
		const gridStart = startOfWeek(monthStart, { weekStartsOn: 1 });
		const gridEnd = endOfWeek(monthEnd, { weekStartsOn: 1 });

		const dates: Date[] = [];
		for (let day = gridStart; !isAfter(day, gridEnd); day = addDays(day, 1)) {
			dates.push(day);
		}
		return dates;
	}, [visibleMonth]);

	const weekdayHeaders = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
	const canGoPrev = isAfter(visibleMonth, monthBounds.minMonth);
	const canGoNext = isBefore(visibleMonth, monthBounds.maxMonth);

	return (
		<div className="flex h-full min-h-130 flex-col rounded-xl border bg-card">
			<div className="border-b px-4 py-3">
				<div className="flex items-center justify-between gap-3">
					<div className="flex items-center gap-2 text-sm font-semibold">
						<CalendarDays className="h-4 w-4 text-primary" />
						Import Preview
					</div>
					<div className="flex items-center gap-1">
						<Button
							type="button"
							variant="outline"
							size="icon-sm"
							onClick={() => setVisibleMonth((month) => addMonths(month, -1))}
							disabled={!canGoPrev}
						>
							<ChevronLeft className="h-4 w-4" />
						</Button>
						<div className="min-w-30 text-center text-sm font-semibold">
							{format(visibleMonth, "MMMM yyyy")}
						</div>
						<Button
							type="button"
							variant="outline"
							size="icon-sm"
							onClick={() => setVisibleMonth((month) => addMonths(month, 1))}
							disabled={!canGoNext}
						>
							<ChevronRight className="h-4 w-4" />
						</Button>
					</div>
				</div>
				<div className="mt-3 flex flex-wrap gap-2 text-[11px]">
					<span className="rounded-md border border-primary/50 bg-primary/10 px-2 py-1 font-medium">
						Import: {previewSummary.imported}
					</span>
					<span className="rounded-md border border-border bg-muted/40 px-2 py-1 font-medium">
						Planned: {previewSummary.planned}
					</span>
					<span className="rounded-md border border-chart-2/50 bg-chart-2/10 px-2 py-1 font-medium">
						Completed: {previewSummary.completed}
					</span>
				</div>
			</div>

			<div className="flex-1 p-4">
				{isLoading ? (
					<div className="flex h-full items-center justify-center text-sm text-muted-foreground">
						Loading preview...
					</div>
				) : errorMessage ? (
					<div className="flex h-full items-center justify-center rounded-lg border border-destructive/30 bg-destructive/5 px-4 text-sm text-destructive">
						{errorMessage}
					</div>
				) : !data ? (
					<div className="flex h-full items-center justify-center text-sm text-muted-foreground">
						Adjust the import settings to see a calendar preview.
					</div>
				) : (
					<div className="grid h-full grid-cols-7 gap-2">
						{weekdayHeaders.map((dayName) => (
							<div
								key={dayName}
								className="text-center text-[11px] font-semibold uppercase tracking-wide text-muted-foreground"
							>
								{dayName}
							</div>
						))}
						{gridDays.map((day) => {
							const dayKey = format(day, "yyyy-MM-dd");
							const dayItems = daysByKey.get(dayKey) ?? [];
							const isInMonth = isSameMonth(day, visibleMonth);

							return (
								<div
									key={dayKey}
									className={cn(
										"min-h-21.5 rounded-md border p-1.5",
										isInMonth
											? "bg-background"
											: "bg-muted/25 text-muted-foreground",
									)}
								>
									<div className="mb-1 text-right text-[11px] font-semibold">
										{format(day, "d")}
									</div>
									<div className="space-y-1">
										{dayItems.slice(0, 2).map((item) => (
											<div
												key={item.id}
												title={item.title}
												className={cn(
													"truncate rounded border px-1 py-0.5 text-[10px] font-medium",
													itemTone(item.kind),
												)}
											>
												{item.title}
											</div>
										))}
										{dayItems.length > 2 && (
											<div className="text-[10px] text-muted-foreground">
												+{dayItems.length - 2} more
											</div>
										)}
									</div>
								</div>
							);
						})}
					</div>
				)}
			</div>
		</div>
	);
}
