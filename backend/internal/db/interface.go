package db

import (
	"context"
	"time"

	"github.com/anish-chanda/cadent/backend/internal/models"
)

type Database interface {
	// --- AUTH ---
	GetUserByEmail(ctx context.Context, email string) (*models.UserRecord, error)
	CreateUser(ctx context.Context, user *models.UserRecord) error

	// --- Activities stuff ----
	CreateActivity(ctx context.Context, activity *models.Activity) error
	GetActivitiesByUserID(ctx context.Context, userID string) ([]models.Activity, error)
	GetActivitiesByUserIDAndDate(ctx context.Context, userID string, start_date time.Time, end_date time.Time) ([]models.Activity, []models.PlannedActivity, error)
	CheckIdempotency(ctx context.Context, clientActivityID string) (bool, error)
	GetActivityByID(ctx context.Context, activityID string) (*models.Activity, error)
	CreatePlannedActivity(ctx context.Context, plan *models.PlannedActivity) (*models.PlannedActivity, error)

	// --- Activity Streams ---
	GetActivityStreams(ctx context.Context, activityID string, lod models.StreamLOD) ([]models.ActivityStream, error)
	CreateActivityStreams(ctx context.Context, streams []models.ActivityStream) error

	// --- Training Plans ---
	GetTrainingPlans(ctx context.Context, searchQuery string, sport string) ([]models.TrainingPlan, error)
	GetTrainingPlanWorkouts(ctx context.Context, planID string) ([]models.TrainingPlanWorkout, error)

	// --- User management methods ---
	GetUserByID(ctx context.Context, userID string) (*models.UserRecord, error)
	UpdateUser(ctx context.Context, userID string, updates map[string]interface{}) error

	// establishes a database connection
	Connect(dsn string) error
	// closes the database connection
	Close() error
	// runs database migrations
	Migrate() error
}
