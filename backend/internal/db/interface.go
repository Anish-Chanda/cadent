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

	// other stuff

	// establishes a database connection
	Connect(dsn string) error
	// closes the database connection
	Close() error
	// runs database migrations
	Migrate() error
}
