package handlers

import (
	"net/http/httptest"
	"testing"
	"time"
)

func TestPlannedActivityReferenceDateFromRequest(t *testing.T) {
	req := httptest.NewRequest(
		"GET",
		"/api/v1/activities/plan/today?date=2026-05-05&timezoneOffsetMinutes=-300",
		nil,
	)

	referenceTime, err := plannedActivityReferenceDateFromRequest(req)
	if err != nil {
		t.Fatalf("plannedActivityReferenceDateFromRequest() returned error: %v", err)
	}

	if referenceTime.Year() != 2026 || referenceTime.Month() != time.May || referenceTime.Day() != 5 {
		t.Fatalf("unexpected date returned: %s", referenceTime.Format(time.RFC3339))
	}

	if _, offsetSeconds := referenceTime.Zone(); offsetSeconds != -300*60 {
		t.Fatalf("unexpected timezone offset: got %d seconds", offsetSeconds)
	}
}

func TestPlannedActivityReferenceDateFromRequestRequiresDate(t *testing.T) {
	req := httptest.NewRequest(
		"GET",
		"/api/v1/activities/plan/today?timezoneOffsetMinutes=-300",
		nil,
	)

	if _, err := plannedActivityReferenceDateFromRequest(req); err == nil {
		t.Fatal("expected an error when date is missing")
	}
}

func TestPlannedActivityReferenceDateFromRequestRequiresTimezoneOffset(t *testing.T) {
	req := httptest.NewRequest(
		"GET",
		"/api/v1/activities/plan/today?date=2026-05-05",
		nil,
	)

	if _, err := plannedActivityReferenceDateFromRequest(req); err == nil {
		t.Fatal("expected an error when timezoneOffsetMinutes is missing")
	}
}
