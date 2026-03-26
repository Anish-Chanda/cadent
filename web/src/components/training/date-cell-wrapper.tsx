import { useRef, useCallback } from "react"
import { isSameDay } from "date-fns"

interface DateCellWrapperProps {
  value: Date
  range: Date[]
  children: React.ReactNode
}

/**
 * Wraps each .rbc-day-bg cell in the background layer.
 * These cells span the full height of the week row, so we use them
 * for hover detection and bridge the hover state to the corresponding
 * .rbc-date-cell in the content layer via a CSS class toggle.
 */
export function DateCellWrapper({ value, range, children }: DateCellWrapperProps) {
  const wrapperRef = useRef<HTMLDivElement>(null)

  const getColumnIndex = useCallback(() => {
    return range.findIndex((d) => isSameDay(d, value))
  }, [range, value])

  const handleMouseEnter = useCallback(() => {
    const monthRow = wrapperRef.current?.closest(".rbc-month-row")
    if (!monthRow) return

    const columnIndex = getColumnIndex()
    if (columnIndex < 0) return

    const dateCells = monthRow.querySelectorAll(
      ".rbc-row-content .rbc-date-cell"
    )
    dateCells[columnIndex]?.classList.add("rbc-cell-hovered")
  }, [getColumnIndex])

  const handleMouseLeave = useCallback(() => {
    const monthRow = wrapperRef.current?.closest(".rbc-month-row")
    if (!monthRow) return

    monthRow
      .querySelectorAll(".rbc-cell-hovered")
      .forEach((el) => el.classList.remove("rbc-cell-hovered"))
  }, [])

  return (
    <div
      ref={wrapperRef}
      onMouseEnter={handleMouseEnter}
      onMouseLeave={handleMouseLeave}
      style={{ flex: "1 1 0%", display: "flex", position: "relative" }}
    >
      {children}
    </div>
  )
}
