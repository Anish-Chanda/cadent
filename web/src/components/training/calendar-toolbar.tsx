import { ChevronLeft, ChevronRight } from "lucide-react"
import type { ToolbarProps } from "react-big-calendar"
import { Button } from "@/components/ui/button"
import { Select } from "@/components/ui/select"
import { cn } from "@/lib/utils"

export interface CalendarToolbarProps extends ToolbarProps {
  className?: string
}

export function CalendarToolbar({
  date,
  onNavigate,
  className,
}: CalendarToolbarProps) {
  const currentYear = date.getFullYear()
  const currentMonthIndex = date.getMonth()

  const months = [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
  ]

  const years = Array.from({ length: 10 }, (_, i) => currentYear - 5 + i)

  const handleMonthChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    const newMonth = Number.parseInt(e.target.value)
    const newDate = new Date(date)
    newDate.setMonth(newMonth)
    onNavigate("DATE", newDate)
  }

  const handleYearChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    const newYear = Number.parseInt(e.target.value)
    const newDate = new Date(date)
    newDate.setFullYear(newYear)
    onNavigate("DATE", newDate)
  }

  return (
    <div className={cn("flex items-center justify-between gap-4 mb-4", className)}>
      {/* Month/Year Selector */}
      <div className="flex items-center gap-2">
        <Select
          value={currentMonthIndex}
          onChange={handleMonthChange}
          className="w-35"
        >
          {months.map((month, index) => (
            <option key={month} value={index}>
              {month}
            </option>
          ))}
        </Select>
        <Select
          value={currentYear}
          onChange={handleYearChange}
          className="w-25"
        >
          {years.map((year) => (
            <option key={year} value={year}>
              {year}
            </option>
          ))}
        </Select>
      </div>

      {/* Navigation Controls */}
      <div className="flex items-center gap-2">
        <Button
          variant="outline"
          size="sm"
          onClick={() => onNavigate("TODAY")}
        >
          Today
        </Button>
        <div className="flex items-center gap-1">
          <Button
            variant="outline"
            size="icon-sm"
            onClick={() => onNavigate("PREV")}
            aria-label="Previous month"
          >
            <ChevronLeft />
          </Button>
          <Button
            variant="outline"
            size="icon-sm"
            onClick={() => onNavigate("NEXT")}
            aria-label="Next month"
          >
            <ChevronRight />
          </Button>
        </div>
      </div>
    </div>
  )
}
