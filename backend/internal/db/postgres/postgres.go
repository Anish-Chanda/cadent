package postgres

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/anish-chanda/cadence/backend/internal/logger"
	"github.com/anish-chanda/cadence/backend/internal/models"
	"github.com/anish-chanda/cadence/backend/migrations"
	"github.com/golang-migrate/migrate/v4"
	"github.com/golang-migrate/migrate/v4/database/postgres"
	"github.com/golang-migrate/migrate/v4/source/iofs"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/jackc/pgx/v5/stdlib"
)

// pgxPoolIface is a package-private interface for pgxpool methods
// This allows for easy mocking in tests
type pgxPoolIface interface {
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
	Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
	Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
	Close()
	Ping(ctx context.Context) error
}

type PostgresDB struct {
	pool  pgxPoolIface
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
		SELECT id, email, name, password_hash, auth_provider,
		       EXTRACT(EPOCH FROM created_at)::bigint as created_at,
		       EXTRACT(EPOCH FROM updated_at)::bigint as updated_at
		FROM users WHERE email = $1
	`

	var user models.UserRecord
	var passwordHash sql.NullString

	err := s.pool.QueryRow(ctx, query, email).Scan(
		&user.ID,
		&user.Email,
		&user.Name,
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
		INSERT INTO users (id, email, name, password_hash, auth_provider, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, to_timestamp($6), to_timestamp($7))
	`

	_, err := s.pool.Exec(ctx, query,
		user.ID,
		user.Email,
		user.Name,
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
			elevation_loss_m, max_height_m, min_height_m,
			avg_speed_mps, max_speed_mps, avg_hr_bpm, max_hr_bpm, processing_ver,
			polyline, bbox_min_lat, bbox_min_lon, bbox_max_lat, bbox_max_lon,
			start_lat, start_lon, end_lat, end_lon, file_url, created_at, updated_at
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20,
			$21, $22, $23, $24, $25, $26, $27, $28, $29, $30, $31
		)
	`

	_, err := s.pool.Exec(ctx, query,
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
		activity.ElevationLossM,
		activity.MaxHeightM,
		activity.MinHeightM,
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
			elevation_loss_m, max_height_m, min_height_m,
			avg_speed_mps, max_speed_mps, avg_hr_bpm, max_hr_bpm, processing_ver,
			polyline, bbox_min_lat, bbox_min_lon, bbox_max_lat, bbox_max_lon,
			start_lat, start_lon, end_lat, end_lon, file_url, created_at, updated_at
		FROM activities 
		WHERE user_id = $1
		ORDER BY start_time DESC
	`

	rows, err := s.pool.Query(ctx, query, userID)
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
			&activity.ElevationLossM,
			&activity.MaxHeightM,
			&activity.MinHeightM,
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
	err := s.pool.QueryRow(ctx, query, clientActivityID).Scan(&exists)
	if err != nil {
		s.log.Error(fmt.Sprintf("Database error while checking idempotency for: %s", clientActivityID), err)
		return false, fmt.Errorf("failed to check idempotency: %w", err)
	}

	s.log.Debug(fmt.Sprintf("Idempotency check result for %s: %t", clientActivityID, exists))
	return exists, nil
}

func (s *PostgresDB) GetUserByID(ctx context.Context, userID string) (*models.UserRecord, error) {
	s.log.Debug(fmt.Sprintf("Fetching user by ID: %s", userID))

	query := `
		SELECT id, email, name, password_hash, auth_provider,
		       EXTRACT(EPOCH FROM created_at)::bigint as created_at,
		       EXTRACT(EPOCH FROM updated_at)::bigint as updated_at
		FROM users WHERE id = $1
	`

	var user models.UserRecord
	var passwordHash sql.NullString

	err := s.pool.QueryRow(ctx, query, userID).Scan(
		&user.ID,
		&user.Email,
		&user.Name,
		&passwordHash,
		&user.AuthProvider,
		&user.CreatedAt,
		&user.UpdatedAt,
	)

	if err != nil {
		if err == pgx.ErrNoRows {
			s.log.Debug(fmt.Sprintf("User not found with ID: %s", userID))
			return nil, nil // User not found
		}
		s.log.Error(fmt.Sprintf("Database error while fetching user by ID: %s", userID), err)
		return nil, fmt.Errorf("failed to get user by ID: %w", err)
	}

	// Handle nullable password hash (this will only be available for 'local' auth provider)
	if passwordHash.Valid {
		user.PasswordHash = &passwordHash.String
	}

	s.log.Debug(fmt.Sprintf("Successfully retrieved user: %s", userID))
	return &user, nil
}

// GetActivityByID retrieves a specific activity by its ID
func (s *PostgresDB) GetActivityByID(ctx context.Context, activityID string) (*models.Activity, error) {
	s.log.Debug(fmt.Sprintf("Fetching activity by ID: %s", activityID))

	query := `
		SELECT 
			id, user_id, client_activity_id, title, description, type,
			start_time, end_time, elapsed_time, distance_m, elevation_gain_m,
			elevation_loss_m, max_height_m, min_height_m,
			avg_speed_mps, max_speed_mps, avg_hr_bpm, max_hr_bpm, processing_ver,
			polyline, bbox_min_lat, bbox_min_lon, bbox_max_lat, bbox_max_lon,
			start_lat, start_lon, end_lat, end_lon, file_url, created_at, updated_at
		FROM activities 
		WHERE id = $1
	`

	var activity models.Activity
	err := s.pool.QueryRow(ctx, query, activityID).Scan(
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
		&activity.ElevationLossM,
		&activity.MaxHeightM,
		&activity.MinHeightM,
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
		&activity.FileURL,
		&activity.CreatedAt,
		&activity.UpdatedAt,
	)

	if err != nil {
		if err == pgx.ErrNoRows {
			s.log.Debug(fmt.Sprintf("Activity not found: %s", activityID))
			return nil, nil
		}
		s.log.Error(fmt.Sprintf("Database error while fetching activity: %s", activityID), err)
		return nil, fmt.Errorf("failed to get activity: %w", err)
	}

	s.log.Debug(fmt.Sprintf("Successfully retrieved activity: %s", activityID))
	return &activity, nil
}

func (s *PostgresDB) UpdateUser(ctx context.Context, userID string, updates map[string]interface{}) error {
	s.log.Debug(fmt.Sprintf("Updating user ID: %s with %d fields", userID, len(updates)))

	if len(updates) == 0 {
		return fmt.Errorf("no updates provided")
	}

	// Build dynamic query
	setClauses := make([]string, 0, len(updates))
	args := make([]interface{}, 0, len(updates)+1)
	argIndex := 1

	for field, value := range updates {
		switch field {
		case "name", "email":
			setClauses = append(setClauses, fmt.Sprintf("%s = $%d", field, argIndex))
			args = append(args, value)
			argIndex++
		default:
			return fmt.Errorf("invalid field for update: %s", field)
		}
	}

	// Add updated_at timestamp
	setClauses = append(setClauses, fmt.Sprintf("updated_at = to_timestamp($%d)", argIndex))
	args = append(args, time.Now().Unix())
	argIndex++

	// Add user ID for WHERE clause
	args = append(args, userID)

	query := fmt.Sprintf(`
		UPDATE users
		SET %s
		WHERE id = $%d
	`, strings.Join(setClauses, ", "), argIndex)

	cmdTag, err := s.pool.Exec(ctx, query, args...)
	if err != nil {
		s.log.Error(fmt.Sprintf("Database error while updating user ID: %s", userID), err)
		return fmt.Errorf("failed to update user: %w", err)
	}

	if cmdTag.RowsAffected() == 0 {
		s.log.Debug(fmt.Sprintf("User not found with ID: %s", userID))
		return fmt.Errorf("user not found")
	}

	s.log.Debug(fmt.Sprintf("Successfully updated user: %s", userID))
	return nil
}

// GetActivityStreams retrieves activity streams for a given activity and LOD
func (s *PostgresDB) GetActivityStreams(ctx context.Context, activityID string, lod models.StreamLOD) ([]models.ActivityStream, error) {
	s.log.Debug(fmt.Sprintf("Fetching activity streams for activity: %s, LOD: %s", activityID, lod))

	query := `
		SELECT 
			activity_id, lod, index_by, num_points, original_num_points,
			time_s_bytes, distance_m_bytes, speed_mps_bytes, elevation_m_bytes,
			codec, created_at, updated_at
		FROM activity_streams 
		WHERE activity_id = $1 AND lod = $2
		ORDER BY index_by
	`

	rows, err := s.pool.Query(ctx, query, activityID, lod)
	if err != nil {
		s.log.Error(fmt.Sprintf("Database error while fetching streams for activity: %s", activityID), err)
		return nil, fmt.Errorf("failed to get activity streams: %w", err)
	}
	defer rows.Close()

	var streams []models.ActivityStream
	for rows.Next() {
		var stream models.ActivityStream
		var codecJSON []byte

		err := rows.Scan(
			&stream.ActivityID,
			&stream.LOD,
			&stream.IndexBy,
			&stream.NumPoints,
			&stream.OriginalNumPoints,
			&stream.TimeSBytes,
			&stream.DistanceMBytes,
			&stream.SpeedMpsBytes,
			&stream.ElevationMBytes,
			&codecJSON,
			&stream.CreatedAt,
			&stream.UpdatedAt,
		)
		if err != nil {
			s.log.Error(fmt.Sprintf("Error scanning stream row for activity: %s", activityID), err)
			return nil, fmt.Errorf("failed to scan activity stream: %w", err)
		}

		// Parse codec JSON
		if len(codecJSON) > 0 {
			var codec map[string]interface{}
			if err := json.Unmarshal(codecJSON, &codec); err != nil {
				s.log.Error(fmt.Sprintf("Error parsing codec JSON for activity: %s", activityID), err)
				return nil, fmt.Errorf("failed to parse codec JSON: %w", err)
			}
			stream.Codec = codec
		}

		streams = append(streams, stream)
	}

	if err = rows.Err(); err != nil {
		s.log.Error(fmt.Sprintf("Row iteration error for streams of activity: %s", activityID), err)
		return nil, fmt.Errorf("failed to iterate activity streams: %w", err)
	}

	s.log.Debug(fmt.Sprintf("Successfully retrieved %d streams for activity: %s", len(streams), activityID))
	return streams, nil
}

// CreateActivityStreams creates multiple activity streams in the database
func (s *PostgresDB) CreateActivityStreams(ctx context.Context, streams []models.ActivityStream) error {
	if len(streams) == 0 {
		return nil // No streams to create
	}

	activityID := streams[0].ActivityID // All streams should be for same activity
	s.log.Debug(fmt.Sprintf("Creating %d streams for activity: %s", len(streams), activityID))

	query := `
		INSERT INTO activity_streams (
			activity_id, lod, index_by, num_points, original_num_points,
			time_s_bytes, distance_m_bytes, speed_mps_bytes, elevation_m_bytes,
			codec, created_at, updated_at
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12
		)
	`

	for _, stream := range streams {
		codecJSON, err := json.Marshal(stream.Codec)
		if err != nil {
			s.log.Error(fmt.Sprintf("Error marshaling codec for activity: %s", activityID), err)
			return fmt.Errorf("failed to marshal codec JSON: %w", err)
		}

		_, err = s.pool.Exec(ctx, query,
			stream.ActivityID,
			stream.LOD,
			stream.IndexBy,
			stream.NumPoints,
			stream.OriginalNumPoints,
			stream.TimeSBytes,
			stream.DistanceMBytes,
			stream.SpeedMpsBytes,
			stream.ElevationMBytes,
			codecJSON,
			stream.CreatedAt,
			stream.UpdatedAt,
		)

		if err != nil {
			s.log.Error(fmt.Sprintf("Database error while creating stream for activity: %s", activityID), err)
			return fmt.Errorf("failed to create activity stream: %w", err)
		}
	}

	s.log.Debug(fmt.Sprintf("Successfully created %d streams for activity: %s", len(streams), activityID))
	return nil
}

// --- Other stuff ---

func (s *PostgresDB) Connect(dsn string) error {
	return s.ConnectWithPoolConfig(dsn, nil)
}

func (s *PostgresDB) ConnectWithPoolConfig(dsn string, poolConfig *pgxpool.Config) error {
	var config *pgxpool.Config
	var err error

	if poolConfig != nil {
		config = poolConfig
	} else {
		config, err = pgxpool.ParseConfig(dsn)
		if err != nil {
			return fmt.Errorf("failed to parse DSN: %w", err)
		}
	}

	s.log.Debug(fmt.Sprintf("Connecting to Postgres at: %s:%d", config.ConnConfig.Host, config.ConnConfig.Port))
	s.log.Debug(fmt.Sprintf("Pool config - MaxConns: %d, MinConns: %d", config.MaxConns, config.MinConns))

	pool, err := pgxpool.NewWithConfig(context.Background(), config)
	if err != nil {
		s.log.Error("Failed to create connection pool", err)
		return fmt.Errorf("failed to create connection pool: %w", err)
	}

	// Test the connection
	if err := pool.Ping(context.Background()); err != nil {
		s.log.Error("Failed to ping database", err)
		pool.Close()
		return fmt.Errorf("failed to ping database: %w", err)
	}

	s.pool = pool
	s.log.Info("Successfully connected to PostgreSQL with connection pool")

	// Create sql.DB for migrations
	s.sqlDB = stdlib.OpenDB(*config.ConnConfig)
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
	if s.pool != nil {
		s.pool.Close()
		s.log.Info("Database connection pool closed")
	}
	if s.sqlDB != nil {
		if err := s.sqlDB.Close(); err != nil {
			return fmt.Errorf("failed to close sql.DB: %w", err)
		}
	}
	return nil
}
