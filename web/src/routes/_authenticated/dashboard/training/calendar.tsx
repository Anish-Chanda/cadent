import { useQuery } from "@tanstack/react-query";
import { createFileRoute, useRouter } from "@tanstack/react-router";
import { endOfWeek, format, getDay, parse, startOfWeek } from "date-fns";
import { enUS } from "date-fns/locale";
import { useCallback, useEffect, useMemo, useState } from "react";
import { Calendar, dateFnsLocalizer } from "react-big-calendar";
import {
	type CalendarEventData,
	CalendarEventWrapper,
} from "@/components/training/calendar-event";
import { CalendarToolbar } from "@/components/training/calendar-toolbar";
import { DateCellWrapper } from "@/components/training/date-cell-wrapper";
import { MonthDateHeader } from "@/components/training/month-date-header";
import { PlannedActivityModal } from "@/components/training/planned-activity-modal";
import { getCalendar } from "@/lib/api";
import "react-big-calendar/lib/css/react-big-calendar.css";
import "@/styles/training-calendar.css";

export const Route = createFileRoute(
	"/_authenticated/dashboard/training/calendar",
)({
	validateSearch: (search: Record<string, unknown>) => ({
		openCreate: search.openCreate === "1" ? "1" : undefined,
		date: typeof search.date === "string" ? search.date : undefined,
	}),
	component: TrainingCalendarPage,
});

const localizer = dateFnsLocalizer({
	format,
	parse,
	startOfWeek: (date: Date) => startOfWeek(date, { weekStartsOn: 1 }),
	getDay,
	locales: { "en-US": enUS },
});

function parseIsoDate(isoString: string): Date | undefined {
	const parsed = new Date(isoString);
	return Number.isNaN(parsed.getTime()) ? undefined : parsed;
}

function TrainingCalendarPage() {
	const router = useRouter();
	const { openCreate, date: modalDateFromSearch } = Route.useSearch();

	const [currentDate, setCurrentDate] = useState(new Date());
	const [isModalOpen, setIsModalOpen] = useState(false);
	const [modalDate, setModalDate] = useState<Date | undefined>(undefined);

	const startOfMonth = new Date(
		currentDate.getFullYear(),
		currentDate.getMonth(),
		1,
	);
	const endOfMonth = new Date(
		currentDate.getFullYear(),
		currentDate.getMonth() + 1,
		0,
	);

	// Format for API
	const startDateStr = format(
		startOfWeek(startOfMonth, { weekStartsOn: 1 }),
		"yyyy-MM-dd",
	);
	const endDateStr = format(
		endOfWeek(endOfMonth, { weekStartsOn: 1 }),
		"yyyy-MM-dd",
	);

	const { data, isLoading } = useQuery({
		queryKey: ["calendar", startDateStr, endDateStr],
		queryFn: () => getCalendar(startDateStr, endDateStr),
	});

	const events = useMemo(() => {
		const list: CalendarEventData[] = [];

		if (!data) return list;

		// Past actuals
		data.activities.forEach((act) => {
			const start = parseIsoDate(act.start_time);
			if (!start) return;

			const elapsedSeconds = act.stats.elapsed_seconds;
			const distanceMeters = act.stats.distance_m;

			list.push({
				id: act.id,
				title: act.title,
				type: act.type,
				start,
				end: new Date(start.getTime() + elapsedSeconds * 1000),
				isPlanned: false,
				distance: distanceMeters,
				duration: elapsedSeconds,
				elevationGain: act.stats.elevation_gain_m,
				avgSpeedMps: act.stats.avg_speed_ms,
			});
		});

		// Planned
		data.planned_activities.forEach((act) => {
			if (act.matched_activity_id) return; // Don't show planned if matched

			const start = parseIsoDate(act.start_time);
			if (!start) return;

			const duration = act.planned_duration_s ?? 0;

			list.push({
				id: act.id,
				title: act.title,
				type: act.type,
				start,
				end: new Date(start.getTime() + duration * 1000),
				isPlanned: true,
				distance: act.planned_distance_m ?? undefined,
				duration: act.planned_duration_s ?? undefined,
				elevationGain: act.planned_elevation_gain_m ?? undefined,
				avgSpeedMps: act.target_avg_speed_mps ?? undefined,
				targetPower: act.target_power_watt ?? undefined,
			});
		});

		return list;
	}, [data]);

	const handleNavigate = useCallback((newDate: Date) => {
		setCurrentDate(newDate);
	}, []);

	const openModalForDate = useCallback((selectedDate: Date) => {
		setModalDate(selectedDate);
		setIsModalOpen(true);
	}, []);

	useEffect(() => {
		if (openCreate !== "1") return;

		const parsedDate = modalDateFromSearch
			? parseIsoDate(modalDateFromSearch)
			: undefined;
		openModalForDate(parsedDate ?? new Date());

		router.navigate({
			to: "/dashboard/training/calendar",
			search: {
				openCreate: undefined,
				date: undefined,
			},
			replace: true,
		});
	}, [modalDateFromSearch, openCreate, openModalForDate, router]);

	const handleSelectSlot = useCallback(
		(slotInfo: { start: Date }) => {
			openModalForDate(slotInfo.start);
		},
		[openModalForDate],
	);

	return (
		<div className="px-6 py-8">
			<div className="mx-auto max-w-7xl">
				<div className="flex items-center justify-between mb-6">
					<h1 className="text-2xl font-bold tracking-tight">
						Training Calendar
					</h1>
				</div>

				<div className="rounded-xl border bg-card shadow-sm p-6 relative overflow-hidden">
					{isLoading && (
						<div className="absolute inset-0 bg-background/50 z-10 flex items-center justify-center backdrop-blur-sm">
							<div className="w-8 h-8 rounded-full border-4 border-primary border-t-transparent animate-spin" />
						</div>
					)}

					<Calendar
						localizer={localizer}
						events={events}
						startAccessor="start"
						endAccessor="end"
						date={currentDate}
						onNavigate={handleNavigate}
						selectable
						onSelectSlot={handleSelectSlot}
						style={{ height: "calc(100vh - 240px)", minHeight: "680px" }}
						views={["month"]}
						defaultView="month"
						components={{
							toolbar: CalendarToolbar,
							dateCellWrapper: DateCellWrapper,
							event: CalendarEventWrapper,
							month: {
								dateHeader: (props) => (
									<MonthDateHeader
										{...props}
										onAddActivity={openModalForDate}
										onDrillDown={(e) => {
											e.preventDefault();
											e.stopPropagation();
											openModalForDate(props.date);
										}}
									/>
								),
							},
						}}
						eventPropGetter={(event) => ({
							className: event.isPlanned
								? "cadent-event-planned"
								: "cadent-event-completed",
						})}
						popup
					/>
				</div>
			</div>
			<PlannedActivityModal
				isOpen={isModalOpen}
				onClose={() => setIsModalOpen(false)}
				initialDate={modalDate}
			/>
		</div>
	);
}
