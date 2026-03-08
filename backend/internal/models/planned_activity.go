package models

import (
	"time"

	"github.com/google/uuid"
)

// PlannedActivity represents a scheduled or intended activity in the calendar.
// It is kept separate from the real 'Activity' table to allow for
// "Planned vs. Actual" comparison logic.
type PlannedActivity struct {
	// Identity and User Reference
	ID     uuid.UUID `json:"id" db:"id"`
	UserID string    `json:"userId" db:"user_id"`

	// Descriptive Fields
	Title       string  `json:"title" db:"title"`
	Description *string `json:"description" db:"description"`

	// Activity Metadata
	Type      ActivityType `json:"activityType" db:"type"`
	StartTime time.Time    `json:"startTime" db:"start_time"`

	// Planned Metrics (Using pointers to allow for NULL values in DB)
	PlannedDistanceM      *float64 `json:"plannedDistanceMeter" db:"planned_distance_m"`
	PlannedDurationS      *int     `json:"plannedDurationSecond" db:"planned_duration_s"`
	PlannedElevationGainM *float64 `json:"plannedElevationGainMeter" db:"planned_elevation_gain_m"`
	TargetAvgSpeedMps     *float64 `json:"targetAverageSpeedMeterPerSecond" db:"target_avg_speed_mps"`
	TargetPowerWatt       *int     `json:"targetPowerWatt" db:"target_power_watt"`

	// Timestamps
	CreatedAt time.Time `json:"createdAt" db:"created_at"`
	UpdatedAt time.Time `json:"updated_at" db:"updated_at"`
}
