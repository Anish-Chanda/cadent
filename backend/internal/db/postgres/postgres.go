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

// --- Activities stuff ---

// CreateActivity creates a new activity in the database
func (s *PostgresDB) CreateActivity(ctx context.Context, activity *models.Activity) error {
	s.log.Debug(fmt.Sprintf("Creating new activity for user: %s", activity.UserID))

	query := `
		INSERT INTO activities (
			id, user_id, client_activity_id, title, description, type,
			start_time, end_time, elapsed_time, distance_m, elevation_gain_m,
			avg_speed_mps, max_speed_mps, avg_hr_bpm, max_hr_bpm, processing_ver,
			polyline, bbox_min_lat, bbox_min_lon, bbox_max_lat, bbox_max_lon,
			start_lat, start_lon, end_lat, end_lon, num_legs, num_alternates,
			num_points_poly, val_duration_seconds, file_url, created_at, updated_at
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16,
			$17, $18, $19, $20, $21, $22, $23, $24, $25, $26, $27, $28, $29, $30, $31, $32
		)
	`

	_, err := s.db.Exec(ctx, query,
		activity.ID,
		activity.UserID,
		activity.ClientActivityID,
		activity.Title,
		activity.Description,
		activity.ActivityType,
		activity.StartTime,
		activity.EndTime,
		activity.ElapsedTime,
		activity.DistanceM,
		activity.ElevationGainM,
		activity.AvgSpeedMps,
		activity.MaxSpeedMps,
		activity.AvgHRBpm,
		activity.MaxHRBpm,
		activity.ProcessingVer,
		activity.Polyline,
		activity.BBoxMinLat,
		activity.BBoxMinLon,
		activity.BBoxMaxLat,
		activity.BBoxMaxLon,
		activity.StartLat,
		activity.StartLon,
		activity.EndLat,
		activity.EndLon,
		activity.NumLegs,
		activity.NumAlternates,
		activity.NumPointsPoly,
		activity.ValDurationSeconds,
		activity.FileURL,
		activity.CreatedAt,
		activity.UpdatedAt,
	)

	if err != nil {
		s.log.Error(fmt.Sprintf("Database error while creating activity for user: %s", activity.UserID), err)
		return fmt.Errorf("failed to create activity: %w", err)
	}

	s.log.Debug(fmt.Sprintf("Created activity: %s for user: %s", activity.ID, activity.UserID))
	return nil
}

// GetActivitiesByUserID retrieves all activities for a specific user
func (s *PostgresDB) GetActivitiesByUserID(ctx context.Context, userID string) ([]models.Activity, error) {
	s.log.Debug(fmt.Sprintf("Fetching activities for user: %s", userID))

	query := `
		SELECT 
			id, user_id, client_activity_id, title, description, type,
			start_time, end_time, elapsed_time, distance_m, elevation_gain_m,
			avg_speed_mps, max_speed_mps, avg_hr_bpm, max_hr_bpm, processing_ver,
			polyline, bbox_min_lat, bbox_min_lon, bbox_max_lat, bbox_max_lon,
			start_lat, start_lon, end_lat, end_lon, num_legs, num_alternates,
			num_points_poly, val_duration_seconds, file_url, created_at, updated_at
		FROM activities 
		WHERE user_id = $1
		ORDER BY start_time DESC
	`

	rows, err := s.db.Query(ctx, query, userID)
	if err != nil {
		s.log.Error(fmt.Sprintf("Database error while fetching activities for user: %s", userID), err)
		return nil, fmt.Errorf("failed to get activities: %w", err)
	}
	defer rows.Close()

	var activities []models.Activity
	for rows.Next() {
		var activity models.Activity
		err := rows.Scan(
			&activity.ID,
			&activity.UserID,
			&activity.ClientActivityID,
			&activity.Title,
			&activity.Description,
			&activity.ActivityType,
			&activity.StartTime,
			&activity.EndTime,
			&activity.ElapsedTime,
			&activity.DistanceM,
			&activity.ElevationGainM,
			&activity.AvgSpeedMps,
			&activity.MaxSpeedMps,
			&activity.AvgHRBpm,
			&activity.MaxHRBpm,
			&activity.ProcessingVer,
			&activity.Polyline,
			&activity.BBoxMinLat,
			&activity.BBoxMinLon,
			&activity.BBoxMaxLat,
			&activity.BBoxMaxLon,
			&activity.StartLat,
			&activity.StartLon,
			&activity.EndLat,
			&activity.EndLon,
			&activity.NumLegs,
			&activity.NumAlternates,
			&activity.NumPointsPoly,
			&activity.ValDurationSeconds,
			&activity.FileURL,
			&activity.CreatedAt,
			&activity.UpdatedAt,
		)
		if err != nil {
			s.log.Error(fmt.Sprintf("Error scanning activity row for user: %s", userID), err)
			return nil, fmt.Errorf("failed to scan activity: %w", err)
		}
		activities = append(activities, activity)
	}

	if err = rows.Err(); err != nil {
		s.log.Error(fmt.Sprintf("Row iteration error for user: %s", userID), err)
		return nil, fmt.Errorf("failed to iterate activities: %w", err)
	}

	s.log.Debug(fmt.Sprintf("Successfully retrieved %d activities for user: %s", len(activities), userID))
	return activities, nil
}

// CheckIdempotency checks if a client activity ID already exists
func (s *PostgresDB) CheckIdempotency(ctx context.Context, clientActivityID string) (bool, error) {
	s.log.Debug(fmt.Sprintf("Checking idempotency for client activity ID: %s", clientActivityID))

	query := `SELECT EXISTS(SELECT 1 FROM activities WHERE client_activity_id = $1)`

	var exists bool
	err := s.db.QueryRow(ctx, query, clientActivityID).Scan(&exists)
	if err != nil {
		s.log.Error(fmt.Sprintf("Database error while checking idempotency for: %s", clientActivityID), err)
		return false, fmt.Errorf("failed to check idempotency: %w", err)
	}

	s.log.Debug(fmt.Sprintf("Idempotency check result for %s: %t", clientActivityID, exists))
	return exists, nil
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
