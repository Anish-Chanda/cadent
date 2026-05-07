package postgres

import (
	"testing"
	"time"
)

func TestPlannedActivityDayBoundsUsesReferenceTimezone(t *testing.T) {
	location := time.FixedZone("cdt", -5*60*60)
	referenceTime := time.Date(2026, time.May, 5, 20, 30, 0, 0, location)

	dayStart, dayEnd := plannedActivityDayBounds(referenceTime)

	expectedStart := time.Date(2026, time.May, 5, 5, 0, 0, 0, time.UTC)
	expectedEnd := time.Date(2026, time.May, 6, 5, 0, 0, 0, time.UTC)

	if !dayStart.Equal(expectedStart) {
		t.Fatalf("unexpected day start: got %s want %s", dayStart.Format(time.RFC3339), expectedStart.Format(time.RFC3339))
	}

	if !dayEnd.Equal(expectedEnd) {
		t.Fatalf("unexpected day end: got %s want %s", dayEnd.Format(time.RFC3339), expectedEnd.Format(time.RFC3339))
	}
}
