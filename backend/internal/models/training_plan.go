package models

import (
"time"

"github.com/google/uuid"
)

type TrainingPlanDifficulty string

const (
TrainingPlanDifficultyBeginner     TrainingPlanDifficulty = "beginner"
TrainingPlanDifficultyIntermediate TrainingPlanDifficulty = "intermediate"
TrainingPlanDifficultyAdvanced     TrainingPlanDifficulty = "advanced"
)

type TrainingPlan struct {
	ID                         uuid.UUID              `json:"id" db:"id"`
	CreatedByUserID            *string                `json:"created_by_user_id" db:"created_by_user_id"`
	Title                      string                 `json:"title" db:"title"`
	Description                *string                `json:"description" db:"description"`
	PrimarySport               *ActivityType          `json:"primary_sport" db:"primary_sport"`
	Difficulty                 TrainingPlanDifficulty `json:"difficulty" db:"difficulty"`
	DurationWeeks              int                    `json:"duration_weeks" db:"duration_weeks"`
	RecommendedWorkoutsPerWeek int                    `json:"recommended_workouts_per_week" db:"recommended_workouts_per_week"`
	IsSystem                   bool                   `json:"is_system" db:"is_system"`
	CreatedAt                  time.Time              `json:"created_at" db:"created_at"`
	UpdatedAt                  time.Time              `json:"updated_at" db:"updated_at"`
}

type TrainingPlanWorkout struct {
	ID                    uuid.UUID           `json:"id" db:"id"`
	TrainingPlanID        uuid.UUID           `json:"training_plan_id" db:"training_plan_id"`
	SequenceIndex         int                 `json:"sequence_index" db:"sequence_index"`
	TemplateDayOffset     int                 `json:"template_day_offset" db:"template_day_offset"`
	Type                  PlannedActivityType `json:"type" db:"type"`
	Title                 string              `json:"title" db:"title"`
	Description           *string             `json:"description" db:"description"`
	PlannedDistanceM      *float64            `json:"planned_distance_m" db:"planned_distance_m"`
	PlannedDurationS      *int                `json:"planned_duration_s" db:"planned_duration_s"`
	PlannedElevationGainM *float64            `json:"planned_elevation_gain_m" db:"planned_elevation_gain_m"`
	TargetAvgSpeedMps     *float64            `json:"target_avg_speed_mps" db:"target_avg_speed_mps"`
	TargetPowerWatt       *int                `json:"target_power_watt" db:"target_power_watt"`
	CreatedAt             time.Time           `json:"created_at" db:"created_at"`
	UpdatedAt             time.Time           `json:"updated_at" db:"updated_at"`
}
