package models

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
)

// TrainingType captures supported template/workout intent categories.
type TrainingType string

const (
	TrainingTypeRun   TrainingType = "run"
	TrainingTypeCross TrainingType = "cross"
	TrainingTypeBike  TrainingType = "bike"
	TrainingTypeRest  TrainingType = "rest"
)

// TrainingPlanActivity represents one planned training session item.
type TrainingPlanActivity struct {
	TrainingType TrainingType   `json:"trainingType"`
	Title        string         `json:"title"`
	Description  *string        `json:"description,omitempty"`
	Steps        []ActivityStep `json:"steps"`
}

// TrainingPlan stores a reusable set of planned activities.
type TrainingPlan struct {
	ID                uuid.UUID       `json:"id" db:"id"`
	UserID            *string         `json:"userId,omitempty" db:"user_id"`
	Title             string          `json:"title" db:"title"`
	Description       *string         `json:"description,omitempty" db:"description"`
	IsSystem          bool            `json:"isSystem" db:"is_system"`
	PlannedActivities json.RawMessage `json:"plannedActivities" db:"planned_activities"`
	CreatedAt         time.Time       `json:"createdAt" db:"created_at"`
	UpdatedAt         time.Time       `json:"updatedAt" db:"updated_at"`
}
