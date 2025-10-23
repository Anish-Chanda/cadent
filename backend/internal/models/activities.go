package models

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
)

type ActivityType string

const (
	ActivityTypeRun  ActivityType = "run"
	ActivityTypeRide ActivityType = "ride"
)

type Activities struct {
	ID uuid.UUID `json:"id" db:"id"`
	// we use this uuid v4 as an idempotency key to avoid duplicates on client retries
	ClientActivityID uuid.UUID `json:"client_activity_id" db:"client_activity_id"`
	// autogenerate title if not added by user (ex- Afternoon Run)
	Title       string  `json:"title" db:"title"`
	Description *string `json:"description" db:"description"`
	// enum for activity type supportby the server right now
	ActivityType ActivityType `json:"type" db:"type"`
	// start time in
	StartTime time.Time `json:"start_time" db:"start_time"`
	EndTime   time.Time `json:"end_time" db:"end_time"`
	// endtime - starttime
	ElapsedTime int `json:"elapsed_time" db:"elapsed_time"`
	// total moving time calculated from the gps points, this should not be nullable if gps points exists
	MovingTime *int    `json:"moving_time" db:"moving_time"`
	DistanceM  float64 `json:"distance_m" db:"distance_m"`
	// this might be null for virtual runs on threadmills and rides on dumb trainers, this should not be null if gps points exists
	ElevationGainM *float64 `json:"elevation_gain_m" db:"elevation_gain_m"`
	// nullable only if no gps tracking sensor activiated
	AvgSpeedMps *float64 `json:"avg_speed_mps" db:"avg_speed_mps"`
	MaxSpeedMps *float64 `json:"max_speed_mps" db:"max_speed_mps"`
	// hr points can be nullable if no sensor was connected
	AvgHRBpm *int16 `json:"avg_hr_bpm" db:"avg_hr_bpm"`
	MaxHRBpm *int16 `json:"max_hr_bpm" db:"max_hr_bpm"`
	// this is an int processing version of our algorithm, which will be used to reprocess once we improve our algorithms
	ProcessingVer int `json:"processing_ver" db:"processing_ver"`
	// this is the path of the ram data file stored in obj storage
	FileURL string `json:"file_url" db:"file_url"`
	// this would be raw json of the source, {app:{platform:"",version:""}, device:{""}, sensors:[{}]}
	Source json.RawMessage `json:"source" db:"source"`
}
