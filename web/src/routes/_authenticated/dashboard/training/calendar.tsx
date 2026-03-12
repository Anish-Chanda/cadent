import { createFileRoute } from "@tanstack/react-router"
import { Calendar, dateFnsLocalizer } from "react-big-calendar"
import { format, parse, startOfWeek, getDay } from "date-fns"
import { enUS } from "date-fns/locale"
import { CalendarToolbar } from "@/components/training/calendar-toolbar"
import { DateCellWrapper } from "@/components/training/date-cell-wrapper"
import { MonthDateHeader } from "@/components/training/month-date-header"
import "react-big-calendar/lib/css/react-big-calendar.css"
import "@/styles/training-calendar.css"

export const Route = createFileRoute("/_authenticated/dashboard/training/calendar")({
  component: TrainingCalendarPage,
})

const locales = {
  "en-US": enUS,
}

const localizer = dateFnsLocalizer({
  format,
  parse,
  startOfWeek: (date: Date) => startOfWeek(date, { weekStartsOn: 1 }),
  getDay,
  locales,
})

function TrainingCalendarPage() {
  const events: never[] = []

  return (
    <div className="px-6 py-8">
      <div className="mx-auto max-w-7xl">
        <h1 className="text-2xl font-semibold mb-6">Training Calendar</h1>

        <div className="rounded-xl border bg-card shadow-sm p-6">
          <Calendar
            localizer={localizer}
            events={events}
            startAccessor="start"
            endAccessor="end"
            style={{ height: "calc(100vh - 240px)", minHeight: "680px" }}
            views={["month"]}
            defaultView="month"
            components={{
              toolbar: CalendarToolbar,
              dateCellWrapper: DateCellWrapper,
              month: {
                dateHeader: MonthDateHeader,
              },
            }}
            popup
          />
        </div>
      </div>
    </div>
  )
}
