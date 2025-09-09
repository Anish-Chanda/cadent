package postgres

import (
	"context"
	"database/sql"
	"fmt"

	"github.com/anish-chanda/cadence/backend/internal/logger"
	"github.com/anish-chanda/cadence/backend/internal/models"
	"github.com/anish-chanda/cadence/backend/migrations"
	"github.com/golang-migrate/migrate/v4"
	"github.com/golang-migrate/migrate/v4/database/postgres"
	"github.com/golang-migrate/migrate/v4/source/iofs"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/stdlib"
)

type PostgresDB struct {
	db    *pgx.Conn
	sqlDB *sql.DB
	log   logger.ServiceLogger
}

func NewPostgresDB(log logger.ServiceLogger) *PostgresDB {
	return &PostgresDB{
		log: log,
	}
}

// GetUserByEmail retrieves a user by their email address
func (s *PostgresDB) GetUserByEmail(ctx context.Context, email string) (*models.UserRecord, error) {
	s.log.Debug(fmt.Sprintf("Fetching user by email: %s", email))

	// resason as why we are using extract epoch is because we are storing timestamps as int64 in the models
	query := `
		SELECT id, email, password_hash, auth_provider, 
		       EXTRACT(EPOCH FROM created_at)::bigint as created_at,
		       EXTRACT(EPOCH FROM updated_at)::bigint as updated_at
		FROM users WHERE email = $1
	`

	var user models.UserRecord
	var passwordHash sql.NullString

	err := s.db.QueryRow(ctx, query, email).Scan(
		&user.ID,
		&user.Email,
		&passwordHash,
		&user.AuthProvider,
		&user.CreatedAt,
		&user.UpdatedAt,
	)

	if err != nil {
		if err == pgx.ErrNoRows {
			s.log.Debug(fmt.Sprintf("User not found with email: %s", email))
			return nil, nil // User not found
		}
		s.log.Error(fmt.Sprintf("Database error while fetching user by email: %s", email), err)
		return nil, fmt.Errorf("failed to get user by email: %w", err)
	}

	// we check if passwordHas is not null, because this will only be availabel for 'local' auth provider
	if passwordHash.Valid {
		user.PasswordHash = &passwordHash.String
	}

	s.log.Debug(fmt.Sprintf("Successfully retrieved user: %s", user.ID))
	return &user, nil
}

// CreateUser creates a new user in the database
func (s *PostgresDB) CreateUser(ctx context.Context, user *models.UserRecord) error {
	s.log.Debug(fmt.Sprintf("Creating new user with email: %s", user.Email))

	query := `
		INSERT INTO users (id, email, password_hash, auth_provider, created_at, updated_at)
		VALUES ($1, $2, $3, $4, to_timestamp($5), to_timestamp($6))
	`

	_, err := s.db.Exec(ctx, query,
		user.ID,
		user.Email,
		user.PasswordHash,
		user.AuthProvider,
		user.CreatedAt,
		user.UpdatedAt,
	)

	if err != nil {
		s.log.Error(fmt.Sprintf("Database error while creating user: %s", user.Email), err)
		return fmt.Errorf("failed to create user: %w", err)
	}

	s.log.Info(fmt.Sprintf("Successfully created user: %s (%s)", user.ID, user.Email))
	return nil
}

// --- Other stuff ---

func (s *PostgresDB) Connect(dsn string) error {
	parsedDSN, err := pgx.ParseConfig(dsn)
	if err != nil {
		return fmt.Errorf("failed to parse DSN: %w", err)
	}
	s.log.Debug(fmt.Sprintf("Connecting to Postgres at: %s:%d", parsedDSN.Host, parsedDSN.Port))

	conn, err := pgx.Connect(context.TODO(), dsn)
	if err != nil {
		s.log.Error("Failed to connect to PostgreSQL", err)
		return fmt.Errorf("failed to connect to database: %w", err)
	}
	s.db = conn
	s.log.Info("Successfully connected to PostgreSQL")

	// Create sql.DB for migrations
	s.sqlDB = stdlib.OpenDB(*parsedDSN)
	return nil
}

func (s *PostgresDB) Migrate() error {
	s.log.Info("Starting database migration process")

	config := &postgres.Config{}
	conn, err := s.sqlDB.Conn(context.TODO())
	if err != nil {
		return fmt.Errorf("failed to get sql connection: %w", err)
	}
	driver, err := postgres.WithConnection(context.TODO(), conn, config)
	if err != nil {
		return fmt.Errorf("failed to create postgres driver: %w", err)
	}

	fs, path, err := migrations.GetMigrationsFS("postgres")
	if err != nil {
		return fmt.Errorf("failed to get migrations filesystem: %w", err)
	}

	sourceDriver, err := iofs.New(fs, path)
	if err != nil {
		return fmt.Errorf("failed to create source driver: %w", err)
	}

	m, err := migrate.NewWithInstance("iofs", sourceDriver, "postgres", driver)
	if err != nil {
		return fmt.Errorf("failed to create migration instance: %w", err)
	}

	err = m.Up()
	if err != nil && err != migrate.ErrNoChange {
		s.log.Error("Failed to apply database migrations", err)
		return fmt.Errorf("failed to apply migrations: %w", err)
	}

	if err == migrate.ErrNoChange {
		s.log.Info("No new migrations to apply")
	} else {
		s.log.Info("Database migrations applied successfully")
	}

	return nil
}

// Close function
func (s *PostgresDB) Close() error {
	if s.db != nil {
		if err := s.db.Close(context.TODO()); err != nil {
			return fmt.Errorf("failed to close database connection: %w", err)
		}
		return nil
	}
	return nil
}
