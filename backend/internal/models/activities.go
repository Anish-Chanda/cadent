package models

import (
	"time"

	"github.com/google/uuid"
)

type ActivityType string

const (
	ActivityTypeRun      ActivityType = "running"
	ActivityTypeRoadBike ActivityType = "road_biking"
)

type Activity struct {
	// Core identifiers
	ID               uuid.UUID `json:"id" db:"id"`
	UserID           string    `json:"user_id" db:"user_id"`
	ClientActivityID uuid.UUID `json:"client_activity_id" db:"client_activity_id"`

	// Basic activity information
	Title        string       `json:"title" db:"title"`
	Description  *string      `json:"description" db:"description"`
	ActivityType ActivityType `json:"type" db:"type"`

	// Time information
	StartTime   time.Time  `json:"start_time" db:"start_time"`
	EndTime     *time.Time `json:"end_time" db:"end_time"`
	ElapsedTime int        `json:"elapsed_time" db:"elapsed_time"` // seconds

	// Distance and performance metrics
	DistanceM      float64  `json:"distance_m" db:"distance_m"`
	ElevationGainM *float64 `json:"elevation_gain_m" db:"elevation_gain_m"`
	ElevationLossM *float64 `json:"elevation_loss_m" db:"elevation_loss_m"`
	MaxHeightM     *float64 `json:"max_height_m" db:"max_height_m"`
	MinHeightM     *float64 `json:"min_height_m" db:"min_height_m"`
	AvgSpeedMps    *float64 `json:"avg_speed_mps" db:"avg_speed_mps"`
	MaxSpeedMps    *float64 `json:"max_speed_mps" db:"max_speed_mps"`

	// Heart rate data (nullable if no HR sensor)
	AvgHRBpm *int16 `json:"avg_hr_bpm" db:"avg_hr_bpm"`
	MaxHRBpm *int16 `json:"max_hr_bpm" db:"max_hr_bpm"`

	// Processing metadata
	ProcessingVer int `json:"processing_ver" db:"processing_ver"`

	// Route data
	Polyline *string `json:"polyline" db:"polyline"`

	// Bounding box coordinates
	BBoxMinLat *float64 `json:"bbox_min_lat" db:"bbox_min_lat"`
	BBoxMinLon *float64 `json:"bbox_min_lon" db:"bbox_min_lon"`
	BBoxMaxLat *float64 `json:"bbox_max_lat" db:"bbox_max_lat"`
	BBoxMaxLon *float64 `json:"bbox_max_lon" db:"bbox_max_lon"`

	// Start and end coordinates
	StartLat *float64 `json:"start_lat" db:"start_lat"`
	StartLon *float64 `json:"start_lon" db:"start_lon"`
	EndLat   *float64 `json:"end_lat" db:"end_lat"`
	EndLon   *float64 `json:"end_lon" db:"end_lon"`

	// File storage
	FileURL *string `json:"file_url" db:"file_url"`

	// Timestamps
	CreatedAt time.Time `json:"created_at" db:"created_at"`
	UpdatedAt time.Time `json:"updated_at" db:"updated_at"`
}

// Stream data types
type StreamLOD string

const (
	StreamLODMedium StreamLOD = "medium"
	StreamLODLow    StreamLOD = "low"  // calculated on the fly based on medium
	StreamLODFull   StreamLOD = "full" // original data, FIT file from objstore has to be read
)

type StreamIndexBy string

const (
	StreamIndexByDistance StreamIndexBy = "distance" // downsampled by distance
	// In future: StreamIndexByTime StreamIndexBy = "time", maybe
)

type ActivityStream struct {
	ActivityID        uuid.UUID     `json:"activity_id" db:"activity_id"`
	LOD               StreamLOD     `json:"lod" db:"lod"`
	IndexBy           StreamIndexBy `json:"index_by" db:"index_by"`
	NumPoints         int           `json:"num_points" db:"num_points"`
	OriginalNumPoints int           `json:"original_num_points" db:"original_num_points"`

	// Compressed stream data (stored as bytea in postgres DB)
	TimeSBytes      []byte `json:"-" db:"time_s_bytes"`      // seconds since start
	DistanceMBytes  []byte `json:"-" db:"distance_m_bytes"`  // distance in meters
	SpeedMpsBytes   []byte `json:"-" db:"speed_mps_bytes"`   // speed in meters per second
	ElevationMBytes []byte `json:"-" db:"elevation_m_bytes"` // elevation in meters

	// Compression metadata
	Codec map[string]interface{} `json:"codec" db:"codec"` // JSON metadata about compression

	// Timestamps
	CreatedAt time.Time `json:"created_at" db:"created_at"`
	UpdatedAt time.Time `json:"updated_at" db:"updated_at"`
}

// StreamType represents the type of stream data requested
type StreamType string

const (
	StreamTypeTime      StreamType = "time"
	StreamTypeDistance  StreamType = "distance"
	StreamTypeElevation StreamType = "elevation"
	StreamTypeSpeed     StreamType = "speed"
)
