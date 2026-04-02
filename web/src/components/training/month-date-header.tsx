import { isSameDay } from "date-fns"
import { Plus } from "lucide-react"

interface MonthDateHeaderProps {
  label: string
  date: Date
  drilldownView: string | null
  isOffRange: boolean
  onDrillDown: (e: React.MouseEvent) => void
  onAddActivity: (date: Date) => void
}

/**
 * Custom date header for month view calendar cells.
 * Renders the date number (with a blue badge for today)
 * and a hidden "Add planned activity" button that appears
 * when the full cell is hovered (controlled via .rbc-cell-hovered
 * class set by DateCellWrapper).
 */
export function MonthDateHeader({
  label,
  date,
  drilldownView,
  isOffRange,
  onDrillDown,
  onAddActivity,
}: MonthDateHeaderProps) {
  const isToday = isSameDay(date, new Date())

  const handleAddActivity = (e: React.MouseEvent) => {
    e.stopPropagation()
    onAddActivity(date)
  }

  return (
    <div className="rbc-month-date-header">
      {drilldownView ? (
        <button
          type="button"
          className={`rbc-date-number ${isToday ? "rbc-date-today" : ""}`}
          onClick={onDrillDown}
        >
          {label}
        </button>
      ) : (
        <span className={`rbc-date-number ${isToday ? "rbc-date-today" : ""}`}>
          {label}
        </span>
      )}

      {!isOffRange && (
        <button
          type="button"
          className="rbc-add-activity-btn"
          onClick={handleAddActivity}
          aria-label={`Add planned activity for ${date.toLocaleDateString()}`}
        >
          <Plus className="size-3.5" strokeWidth={2.5} />
          <span>Add planned activity</span>
        </button>
      )}
    </div>
  )
}
