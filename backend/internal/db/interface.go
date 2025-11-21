package db

import (
	"context"

	"github.com/anish-chanda/cadence/backend/internal/models"
)

type Database interface {
	// --- AUTH ---
	GetUserByEmail(ctx context.Context, email string) (*models.UserRecord, error)
	CreateUser(ctx context.Context, user *models.UserRecord) error
	// UpdateUser(ctx context.Context, user *UserRecord) error
	// DeleteUser(ctx context.Context, id string) error

	// --- Activities stuff ----
	CreateActivity(ctx context.Context, activity *models.Activity) error
	GetActivitiesByUserID(ctx context.Context, userID string) ([]models.Activity, error)
	CheckIdempotency(ctx context.Context, clientActivityID string) (bool, error)
	GetActivityByID(ctx context.Context, activityID string) (*models.Activity, error)
	
	// --- Activity Streams ---
	GetActivityStreams(ctx context.Context, activityID string, lod models.StreamLOD) ([]models.ActivityStream, error)
	CreateActivityStreams(ctx context.Context, streams []models.ActivityStream) error

	// --- Other stuff ---

	// establishes a database connection
	Connect(dsn string) error
	// closes the database connection
	Close() error
	// runs database migrations
	Migrate() error
}
