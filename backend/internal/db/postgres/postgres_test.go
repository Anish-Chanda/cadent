package postgres

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/anish-chanda/cadence/backend/internal/logger"
	"github.com/anish-chanda/cadence/backend/internal/models"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/pashagolub/pgxmock/v3"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// mockPoolAdapter adapts pgxmock.PgxConnIface to pgxPoolIface
type mockPoolAdapter struct {
	pgxmock.PgxConnIface
}

func (m *mockPoolAdapter) Close() {
	// Mock Close doesn't need to do anything for tests
}

func (m *mockPoolAdapter) Ping(ctx context.Context) error {
	// For tests, we can implement a simple ping by executing a trivial query
	// or just return nil for successful ping
	return nil
}

// setupMockDB creates a PostgresDB with a mock connection
func setupMockDB(t *testing.T) (*PostgresDB, pgxmock.PgxConnIface) {
	t.Helper()

	mock, err := pgxmock.NewConn()
	require.NoError(t, err)

	logConfig := logger.Config{
		Level:       "error", // Suppress logs in tests
		Environment: "test",
		ServiceName: "postgres-test",
	}

	db := &PostgresDB{
		pool: &mockPoolAdapter{PgxConnIface: mock},
		log:  *logger.New(logConfig),
	}

	return db, mock
}

// TestGetUserByEmail_Unit tests GetUserByEmail with mocked database
func TestGetUserByEmail_Unit(t *testing.T) {
	tests := []struct {
		name          string
		email         string
		setupMock     func(mock pgxmock.PgxConnIface)
		expectedUser  *models.UserRecord
		expectedError bool
	}{
		{
			name:  "user found with password",
			email: "test@example.com",
			setupMock: func(mock pgxmock.PgxConnIface) {
				passwordHash := "hashed_password"
				rows := pgxmock.NewRows([]string{
					"id", "email", "name", "password_hash", "auth_provider", "created_at", "updated_at",
				}).AddRow(
					"user-123",
					"test@example.com",
					"Test User",
					passwordHash,
					"local",
					int64(1609459200),
					int64(1609459200),
				)

				mock.ExpectQuery(`SELECT id, email, name, password_hash, auth_provider`).
					WithArgs("test@example.com").
					WithArgs(pgxmock.AnyArg()).WillReturnRows(rows)
			},
			expectedUser: &models.UserRecord{
				ID:           "user-123",
				Email:        "test@example.com",
				Name:         "Test User",
				PasswordHash: func() *string { s := "hashed_password"; return &s }(),
				AuthProvider: models.AuthProviderLocal,
				CreatedAt:    1609459200,
				UpdatedAt:    1609459200,
			},
			expectedError: false,
		},
		{
			name:  "user found without password (OAuth)",
			email: "oauth@example.com",
			setupMock: func(mock pgxmock.PgxConnIface) {
				rows := pgxmock.NewRows([]string{
					"id", "email", "name", "password_hash", "auth_provider", "created_at", "updated_at",
				}).AddRow(
					"user-456",
					"oauth@example.com",
					"OAuth User",
					nil, // NULL password_hash
					"local",
					int64(1609459200),
					int64(1609459200),
				)

				mock.ExpectQuery(`SELECT id, email, name, password_hash, auth_provider`).
					WithArgs("oauth@example.com").
					WithArgs(pgxmock.AnyArg()).WillReturnRows(rows)
			},
			expectedUser: &models.UserRecord{
				ID:           "user-456",
				Email:        "oauth@example.com",
				Name:         "OAuth User",
				PasswordHash: nil,
				AuthProvider: models.AuthProviderLocal,
				CreatedAt:    1609459200,
				UpdatedAt:    1609459200,
			},
			expectedError: false,
		},
		{
			name:  "user not found",
			email: "notfound@example.com",
			setupMock: func(mock pgxmock.PgxConnIface) {
				mock.ExpectQuery(`SELECT id, email, name, password_hash, auth_provider`).
					WithArgs("notfound@example.com").
					WillReturnError(pgx.ErrNoRows)
			},
			expectedUser:  nil,
			expectedError: false, // Returns nil user, not error
		},
		{
			name:  "database error",
			email: "error@example.com",
			setupMock: func(mock pgxmock.PgxConnIface) {
				mock.ExpectQuery(`SELECT id, email, name, password_hash, auth_provider`).
					WithArgs("error@example.com").
					WillReturnError(fmt.Errorf("database connection lost"))
			},
			expectedUser:  nil,
			expectedError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			db, mock := setupMockDB(t)
			defer mock.Close(context.Background())

			tt.setupMock(mock)

			user, err := db.GetUserByEmail(context.Background(), tt.email)

			if tt.expectedError {
				assert.Error(t, err)
				assert.Nil(t, user)
			} else {
				assert.NoError(t, err)
				if tt.expectedUser == nil {
					assert.Nil(t, user)
				} else {
					require.NotNil(t, user)
					assert.Equal(t, tt.expectedUser.ID, user.ID)
					assert.Equal(t, tt.expectedUser.Email, user.Email)
					assert.Equal(t, tt.expectedUser.Name, user.Name)

					if tt.expectedUser.PasswordHash == nil {
						assert.Nil(t, user.PasswordHash)
					} else {
						require.NotNil(t, user.PasswordHash)
						assert.Equal(t, *tt.expectedUser.PasswordHash, *user.PasswordHash)
					}
				}
			}

			// Verify all expectations were met
			assert.NoError(t, mock.ExpectationsWereMet())
		})
	}
}

// TestGetUserByID_Unit tests GetUserByID with mocked database
func TestGetUserByID_Unit(t *testing.T) {
	tests := []struct {
		name          string
		userID        string
		setupMock     func(mock pgxmock.PgxConnIface)
		expectedUser  *models.UserRecord
		expectedError bool
	}{
		{
			name:   "user found",
			userID: "user-123",
			setupMock: func(mock pgxmock.PgxConnIface) {
				passwordHash := "hashed_password"
				rows := pgxmock.NewRows([]string{
					"id", "email", "name", "password_hash", "auth_provider", "created_at", "updated_at",
				}).AddRow(
					"user-123",
					"test@example.com",
					"Test User",
					passwordHash,
					"local",
					int64(1609459200),
					int64(1609459200),
				)

				mock.ExpectQuery(`SELECT id, email, name, password_hash, auth_provider`).
					WithArgs("user-123").
					WithArgs(pgxmock.AnyArg()).WillReturnRows(rows)
			},
			expectedUser: &models.UserRecord{
				ID:           "user-123",
				Email:        "test@example.com",
				Name:         "Test User",
				PasswordHash: func() *string { s := "hashed_password"; return &s }(),
				AuthProvider: models.AuthProviderLocal,
				CreatedAt:    1609459200,
				UpdatedAt:    1609459200,
			},
			expectedError: false,
		},
		{
			name:   "user not found",
			userID: "nonexistent",
			setupMock: func(mock pgxmock.PgxConnIface) {
				mock.ExpectQuery(`SELECT id, email, name, password_hash, auth_provider`).
					WithArgs("nonexistent").
					WillReturnError(pgx.ErrNoRows)
			},
			expectedUser:  nil,
			expectedError: false,
		},
		{
			name:   "database error",
			userID: "error-id",
			setupMock: func(mock pgxmock.PgxConnIface) {
				mock.ExpectQuery(`SELECT id, email, name, password_hash, auth_provider`).
					WithArgs("error-id").
					WillReturnError(fmt.Errorf("connection timeout"))
			},
			expectedUser:  nil,
			expectedError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			db, mock := setupMockDB(t)
			defer mock.Close(context.Background())

			tt.setupMock(mock)

			user, err := db.GetUserByID(context.Background(), tt.userID)

			if tt.expectedError {
				assert.Error(t, err)
			} else {
				assert.NoError(t, err)
			}

			if tt.expectedUser == nil {
				assert.Nil(t, user)
			} else {
				require.NotNil(t, user)
				assert.Equal(t, tt.expectedUser.ID, user.ID)
			}

			assert.NoError(t, mock.ExpectationsWereMet())
		})
	}
}

// TestCreateUser_Unit tests CreateUser with mocked database
func TestCreateUser_Unit(t *testing.T) {
	tests := []struct {
		name          string
		user          *models.UserRecord
		setupMock     func(mock pgxmock.PgxConnIface, user *models.UserRecord)
		expectedError bool
	}{
		{
			name: "successful creation",
			user: &models.UserRecord{
				ID:           "new-user-123",
				Email:        "new@example.com",
				Name:         "New User",
				PasswordHash: func() *string { s := "hashed"; return &s }(),
				AuthProvider: models.AuthProviderLocal,
				CreatedAt:    time.Now().Unix(),
				UpdatedAt:    time.Now().Unix(),
			},
			setupMock: func(mock pgxmock.PgxConnIface, user *models.UserRecord) {
				mock.ExpectExec(`INSERT INTO users`).
					WithArgs(
						user.ID,
						user.Email,
						user.Name,
						user.PasswordHash,
						user.AuthProvider,
						user.CreatedAt,
						user.UpdatedAt,
					).
					WillReturnResult(pgxmock.NewResult("INSERT", 1))
			},
			expectedError: false,
		},
		{
			name: "database error",
			user: &models.UserRecord{
				ID:           "error-user",
				Email:        "error@example.com",
				Name:         "Error User",
				PasswordHash: func() *string { s := "hashed"; return &s }(),
				AuthProvider: models.AuthProviderLocal,
				CreatedAt:    time.Now().Unix(),
				UpdatedAt:    time.Now().Unix(),
			},
			setupMock: func(mock pgxmock.PgxConnIface, user *models.UserRecord) {
				mock.ExpectExec(`INSERT INTO users`).
					WithArgs(
						user.ID,
						user.Email,
						user.Name,
						user.PasswordHash,
						user.AuthProvider,
						user.CreatedAt,
						user.UpdatedAt,
					).
					WillReturnError(fmt.Errorf("unique constraint violation"))
			},
			expectedError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			db, mock := setupMockDB(t)
			defer mock.Close(context.Background())

			tt.setupMock(mock, tt.user)

			err := db.CreateUser(context.Background(), tt.user)

			if tt.expectedError {
				assert.Error(t, err)
			} else {
				assert.NoError(t, err)
			}

			assert.NoError(t, mock.ExpectationsWereMet())
		})
	}
}

// TestUpdateUser_Unit tests UpdateUser with mocked database
func TestUpdateUser_Unit(t *testing.T) {
	tests := []struct {
		name          string
		userID        string
		updates       map[string]interface{}
		setupMock     func(mock pgxmock.PgxConnIface)
		expectedError bool
	}{
		{
			name:   "update name",
			userID: "user-123",
			updates: map[string]interface{}{
				"name": "Updated Name",
			},
			setupMock: func(mock pgxmock.PgxConnIface) {
				mock.ExpectExec(`UPDATE users`).
					WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
					WillReturnResult(pgxmock.NewResult("UPDATE", 1))
			},
			expectedError: false,
		},
		{
			name:   "update email",
			userID: "user-123",
			updates: map[string]interface{}{
				"email": "newemail@example.com",
			},
			setupMock: func(mock pgxmock.PgxConnIface) {
				mock.ExpectExec(`UPDATE users`).
					WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
					WillReturnResult(pgxmock.NewResult("UPDATE", 1))
			},
			expectedError: false,
		},
		{
			name:   "update multiple fields",
			userID: "user-123",
			updates: map[string]interface{}{
				"name":  "New Name",
				"email": "new@example.com",
			},
			setupMock: func(mock pgxmock.PgxConnIface) {
				mock.ExpectExec(`UPDATE users`).
					WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
					WillReturnResult(pgxmock.NewResult("UPDATE", 1))
			},
			expectedError: false,
		},
		{
			name:    "empty updates",
			userID:  "user-123",
			updates: map[string]interface{}{},
			setupMock: func(mock pgxmock.PgxConnIface) {
				// No mock needed, should fail before query
			},
			expectedError: true,
		},
		{
			name:   "invalid field",
			userID: "user-123",
			updates: map[string]interface{}{
				"invalid_field": "value",
			},
			setupMock: func(mock pgxmock.PgxConnIface) {
				// No mock needed, should fail validation
			},
			expectedError: true,
		},
		{
			name:   "user not found",
			userID: "nonexistent",
			updates: map[string]interface{}{
				"name": "Test",
			},
			setupMock: func(mock pgxmock.PgxConnIface) {
				mock.ExpectExec(`UPDATE users`).
					WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
					WillReturnResult(pgxmock.NewResult("UPDATE", 0)) // 0 rows affected
			},
			expectedError: true,
		},
		{
			name:   "database error",
			userID: "user-123",
			updates: map[string]interface{}{
				"name": "Test",
			},
			setupMock: func(mock pgxmock.PgxConnIface) {
				mock.ExpectExec(`UPDATE users`).
					WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
					WillReturnError(fmt.Errorf("connection lost"))
			},
			expectedError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			db, mock := setupMockDB(t)
			defer mock.Close(context.Background())

			tt.setupMock(mock)

			err := db.UpdateUser(context.Background(), tt.userID, tt.updates)

			if tt.expectedError {
				assert.Error(t, err)
			} else {
				assert.NoError(t, err)
			}

			assert.NoError(t, mock.ExpectationsWereMet())
		})
	}
}

// TestCreateActivity_Unit tests CreateActivity with mocked database
func TestCreateActivity_Unit(t *testing.T) {
	activityID := uuid.New()
	clientActivityID := uuid.New()
	distance := 5000.0
	elevation := 150.5
	avgSpeed := 3.5
	polyline := "encoded_polyline"
	description := "Morning run"
	endTime := time.Now()

	tests := []struct {
		name          string
		activity      *models.Activity
		setupMock     func(mock pgxmock.PgxConnIface)
		expectedError bool
	}{
		{
			name: "successful creation",
			activity: &models.Activity{
				ID:               activityID,
				UserID:           "user-123",
				ClientActivityID: clientActivityID,
				Title:            "Morning Run",
				Description:      &description,
				ActivityType:     models.ActivityTypeRun,
				StartTime:        time.Now().Add(-1 * time.Hour),
				EndTime:          &endTime,
				ElapsedTime:      3600,
				DistanceM:        distance,
				ElevationGainM:   &elevation,
				ElevationLossM:   &elevation,
				MaxHeightM:       &elevation,
				MinHeightM:       &elevation,
				AvgSpeedMps:      &avgSpeed,
				Polyline:         &polyline,
				ProcessingVer:    1,
				CreatedAt:        time.Now(),
				UpdatedAt:        time.Now(),
			},
			setupMock: func(mock pgxmock.PgxConnIface) {
				mock.ExpectExec(`INSERT INTO activities`).
					WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(),
						pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(),
						pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(),
						pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(),
						pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(),
						pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(),
						pgxmock.AnyArg()).
					WillReturnResult(pgxmock.NewResult("INSERT", 1))
			},
			expectedError: false,
		},
		{
			name: "database error",
			activity: &models.Activity{
				ID:               activityID,
				UserID:           "user-123",
				ClientActivityID: clientActivityID,
				Title:            "Error Run",
				ActivityType:     models.ActivityTypeRun,
				StartTime:        time.Now(),
				ElapsedTime:      3600,
				DistanceM:        distance,
				ProcessingVer:    1,
				CreatedAt:        time.Now(),
				UpdatedAt:        time.Now(),
			},
			setupMock: func(mock pgxmock.PgxConnIface) {
				mock.ExpectExec(`INSERT INTO activities`).
					WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(),
						pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(),
						pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(),
						pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(),
						pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(),
						pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(),
						pgxmock.AnyArg()).
					WillReturnError(fmt.Errorf("foreign key constraint violation"))
			},
			expectedError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			db, mock := setupMockDB(t)
			defer mock.Close(context.Background())

			tt.setupMock(mock)

			err := db.CreateActivity(context.Background(), tt.activity)

			if tt.expectedError {
				assert.Error(t, err)
			} else {
				assert.NoError(t, err)
			}

			assert.NoError(t, mock.ExpectationsWereMet())
		})
	}
}

// TestGetActivityByID_Unit tests GetActivityByID with mocked database
func TestGetActivityByID_Unit(t *testing.T) {
	activityID := uuid.New()
	clientActivityID := uuid.New()
	distance := 1000.0
	endTimeVal := time.Now()
	endTime := &endTimeVal

	tests := []struct {
		name          string
		activityID    string
		setupMock     func(mock pgxmock.PgxConnIface)
		expectNil     bool
		expectedError bool
	}{
		{
			name:       "activity found",
			activityID: activityID.String(),
			setupMock: func(mock pgxmock.PgxConnIface) {
				rows := pgxmock.NewRows([]string{
					"id", "user_id", "client_activity_id", "title", "description", "type",
					"start_time", "end_time", "elapsed_time", "distance_m", "elevation_gain_m",
					"elevation_loss_m", "max_height_m", "min_height_m",
					"avg_speed_mps", "max_speed_mps", "avg_hr_bpm", "max_hr_bpm", "processing_ver",
					"polyline", "bbox_min_lat", "bbox_min_lon", "bbox_max_lat", "bbox_max_lon",
					"start_lat", "start_lon", "end_lat", "end_lon", "file_url", "created_at", "updated_at",
				}).AddRow(
					activityID, "user-123", clientActivityID, "Test Activity", nil, models.ActivityTypeRun,
					time.Now(), endTime, 1800, distance, nil,
					nil, nil, nil,
					nil, nil, nil, nil, 1,
					nil, nil, nil, nil, nil,
					nil, nil, nil, nil, nil, time.Now(), time.Now(),
				)

				mock.ExpectQuery(`SELECT`).
					WithArgs(pgxmock.AnyArg()).
					WillReturnRows(rows)
			},
			expectNil:     false,
			expectedError: false,
		},
		{
			name:       "activity not found",
			activityID: uuid.New().String(),
			setupMock: func(mock pgxmock.PgxConnIface) {
				mock.ExpectQuery(`SELECT`).
					WithArgs(pgxmock.AnyArg()).
					WillReturnError(pgx.ErrNoRows)
			},
			expectNil:     true,
			expectedError: false,
		},
		{
			name:       "database error",
			activityID: uuid.New().String(),
			setupMock: func(mock pgxmock.PgxConnIface) {
				mock.ExpectQuery(`SELECT`).
					WithArgs(pgxmock.AnyArg()).
					WillReturnError(fmt.Errorf("connection lost"))
			},
			expectNil:     true,
			expectedError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			db, mock := setupMockDB(t)
			defer mock.Close(context.Background())

			tt.setupMock(mock)

			activity, err := db.GetActivityByID(context.Background(), tt.activityID)

			if tt.expectedError {
				assert.Error(t, err)
			} else {
				assert.NoError(t, err)
			}

			if tt.expectNil {
				assert.Nil(t, activity)
			} else {
				assert.NotNil(t, activity)
			}

			assert.NoError(t, mock.ExpectationsWereMet())
		})
	}
}

// TestGetActivitiesByUserID_Unit tests GetActivitiesByUserID with mocked database
func TestGetActivitiesByUserID_Unit(t *testing.T) {
	userID := "user-123"
	activityID1 := uuid.New()
	activityID2 := uuid.New()
	clientActivityID1 := uuid.New()
	clientActivityID2 := uuid.New()
	distance := 1000.0
	endTimeVal := time.Now()
	endTime := &endTimeVal

	tests := []struct {
		name          string
		userID        string
		setupMock     func(mock pgxmock.PgxConnIface)
		expectedCount int
		expectedError bool
	}{
		{
			name:   "multiple activities found",
			userID: userID,
			setupMock: func(mock pgxmock.PgxConnIface) {
				rows := pgxmock.NewRows([]string{
					"id", "user_id", "client_activity_id", "title", "description", "type",
					"start_time", "end_time", "elapsed_time", "distance_m", "elevation_gain_m",
					"elevation_loss_m", "max_height_m", "min_height_m",
					"avg_speed_mps", "max_speed_mps", "avg_hr_bpm", "max_hr_bpm", "processing_ver",
					"polyline", "bbox_min_lat", "bbox_min_lon", "bbox_max_lat", "bbox_max_lon",
					"start_lat", "start_lon", "end_lat", "end_lon", "file_url", "created_at", "updated_at",
				}).
					AddRow(
						activityID1, userID, clientActivityID1, "Activity 1", nil, models.ActivityTypeRun,
						time.Now(), endTime, 1800, distance, nil,
						nil, nil, nil,
						nil, nil, nil, nil, 1,
						nil, nil, nil, nil, nil,
						nil, nil, nil, nil, nil, time.Now(), time.Now(),
					).
					AddRow(
						activityID2, userID, clientActivityID2, "Activity 2", nil, models.ActivityTypeRun,
						time.Now(), endTime, 1800, distance, nil,
						nil, nil, nil,
						nil, nil, nil, nil, 1,
						nil, nil, nil, nil, nil,
						nil, nil, nil, nil, nil, time.Now(), time.Now(),
					)

				mock.ExpectQuery(`SELECT`).
					WithArgs(userID).
					WithArgs(pgxmock.AnyArg()).WillReturnRows(rows)
			},
			expectedCount: 2,
			expectedError: false,
		},
		{
			name:   "no activities found",
			userID: "user-no-activities",
			setupMock: func(mock pgxmock.PgxConnIface) {
				rows := pgxmock.NewRows([]string{
					"id", "user_id", "client_activity_id", "title", "description", "type",
					"start_time", "end_time", "elapsed_time", "distance_m", "elevation_gain_m",
					"elevation_loss_m", "max_height_m", "min_height_m",
					"avg_speed_mps", "max_speed_mps", "avg_hr_bpm", "max_hr_bpm", "processing_ver",
					"polyline", "bbox_min_lat", "bbox_min_lon", "bbox_max_lat", "bbox_max_lon",
					"start_lat", "start_lon", "end_lat", "end_lon", "file_url", "created_at", "updated_at",
				})

				mock.ExpectQuery(`SELECT`).
					WithArgs("user-no-activities").
					WithArgs(pgxmock.AnyArg()).WillReturnRows(rows)
			},
			expectedCount: 0,
			expectedError: false,
		},
		{
			name:   "database error",
			userID: "user-error",
			setupMock: func(mock pgxmock.PgxConnIface) {
				mock.ExpectQuery(`SELECT`).
					WithArgs(pgxmock.AnyArg()).
					WillReturnError(fmt.Errorf("connection timeout"))
			},
			expectedCount: 0,
			expectedError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			db, mock := setupMockDB(t)
			defer mock.Close(context.Background())

			tt.setupMock(mock)

			activities, err := db.GetActivitiesByUserID(context.Background(), tt.userID)

			if tt.expectedError {
				assert.Error(t, err)
			} else {
				assert.NoError(t, err)
				assert.Len(t, activities, tt.expectedCount)
			}

			assert.NoError(t, mock.ExpectationsWereMet())
		})
	}
}

// TestCheckIdempotency_Unit tests CheckIdempotency with mocked database
func TestCheckIdempotency_Unit(t *testing.T) {
	tests := []struct {
		name             string
		clientActivityID string
		setupMock        func(mock pgxmock.PgxConnIface)
		expectedExists   bool
		expectedError    bool
	}{
		{
			name:             "activity exists",
			clientActivityID: uuid.New().String(),
			setupMock: func(mock pgxmock.PgxConnIface) {
				rows := pgxmock.NewRows([]string{"exists"}).AddRow(true)
				mock.ExpectQuery(`SELECT EXISTS`).
					WithArgs(pgxmock.AnyArg()).WillReturnRows(rows)
			},
			expectedExists: true,
			expectedError:  false,
		},
		{
			name:             "activity does not exist",
			clientActivityID: uuid.New().String(),
			setupMock: func(mock pgxmock.PgxConnIface) {
				rows := pgxmock.NewRows([]string{"exists"}).AddRow(false)
				mock.ExpectQuery(`SELECT EXISTS`).
					WithArgs(pgxmock.AnyArg()).WillReturnRows(rows)
			},
			expectedExists: false,
			expectedError:  false,
		},
		{
			name:             "database error",
			clientActivityID: uuid.New().String(),
			setupMock: func(mock pgxmock.PgxConnIface) {
				mock.ExpectQuery(`SELECT EXISTS`).
					WithArgs(pgxmock.AnyArg()).
					WillReturnError(fmt.Errorf("connection lost"))
			},
			expectedExists: false,
			expectedError:  true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			db, mock := setupMockDB(t)
			defer mock.Close(context.Background())

			tt.setupMock(mock)

			exists, err := db.CheckIdempotency(context.Background(), tt.clientActivityID)

			if tt.expectedError {
				assert.Error(t, err)
			} else {
				assert.NoError(t, err)
				assert.Equal(t, tt.expectedExists, exists)
			}

			assert.NoError(t, mock.ExpectationsWereMet())
		})
	}
}

// TestGetActivityStreams_Unit tests GetActivityStreams with mocked database
func TestGetActivityStreams_Unit(t *testing.T) {
	activityID := uuid.New()

	tests := []struct {
		name          string
		activityID    string
		lod           models.StreamLOD
		setupMock     func(mock pgxmock.PgxConnIface)
		expectedCount int
		expectedError bool
	}{
		{
			name:       "streams found",
			activityID: activityID.String(),
			lod:        models.StreamLODMedium,
			setupMock: func(mock pgxmock.PgxConnIface) {
				codecJSON := []byte(`{"type":"delta","compression":"gzip"}`)
				rows := pgxmock.NewRows([]string{
					"activity_id", "lod", "index_by", "num_points", "original_num_points",
					"time_s_bytes", "distance_m_bytes", "speed_mps_bytes", "elevation_m_bytes",
					"codec", "created_at", "updated_at",
				}).AddRow(
					activityID, models.StreamLODMedium, models.StreamIndexByDistance, 100, 1000,
					[]byte{1, 2, 3}, []byte{10, 20, 30}, []byte{5, 6, 7}, []byte{100, 101, 102},
					codecJSON, time.Now(), time.Now(),
				)

				mock.ExpectQuery(`SELECT`).
					WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
					WillReturnRows(rows)
			},
			expectedCount: 1,
			expectedError: false,
		},
		{
			name:       "no streams found",
			activityID: uuid.New().String(),
			lod:        models.StreamLODLow,
			setupMock: func(mock pgxmock.PgxConnIface) {
				rows := pgxmock.NewRows([]string{
					"activity_id", "lod", "index_by", "num_points", "original_num_points",
					"time_s_bytes", "distance_m_bytes", "speed_mps_bytes", "elevation_m_bytes",
					"codec", "created_at", "updated_at",
				})

				mock.ExpectQuery(`SELECT`).
					WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
					WillReturnRows(rows)
			},
			expectedCount: 0,
			expectedError: false,
		},
		{
			name:       "database error",
			activityID: uuid.New().String(),
			lod:        models.StreamLODMedium,
			setupMock: func(mock pgxmock.PgxConnIface) {
				mock.ExpectQuery(`SELECT`).
					WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
					WillReturnError(fmt.Errorf("query timeout"))
			},
			expectedCount: 0,
			expectedError: true,
		},
		{
			name:       "invalid codec JSON",
			activityID: activityID.String(),
			lod:        models.StreamLODMedium,
			setupMock: func(mock pgxmock.PgxConnIface) {
				invalidJSON := []byte(`{invalid json}`)
				rows := pgxmock.NewRows([]string{
					"activity_id", "lod", "index_by", "num_points", "original_num_points",
					"time_s_bytes", "distance_m_bytes", "speed_mps_bytes", "elevation_m_bytes",
					"codec", "created_at", "updated_at",
				}).AddRow(
					activityID, models.StreamLODMedium, models.StreamIndexByDistance, 100, 1000,
					[]byte{1, 2, 3}, []byte{10, 20, 30}, []byte{5, 6, 7}, []byte{100, 101, 102},
					invalidJSON, time.Now(), time.Now(),
				)

				mock.ExpectQuery(`SELECT`).
					WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
					WillReturnRows(rows)
			},
			expectedCount: 0,
			expectedError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			db, mock := setupMockDB(t)
			defer mock.Close(context.Background())

			tt.setupMock(mock)

			streams, err := db.GetActivityStreams(context.Background(), tt.activityID, tt.lod)

			if tt.expectedError {
				assert.Error(t, err)
			} else {
				assert.NoError(t, err)
				assert.Len(t, streams, tt.expectedCount)

				if tt.expectedCount > 0 {
					assert.NotNil(t, streams[0].Codec)
				}
			}

			assert.NoError(t, mock.ExpectationsWereMet())
		})
	}
}

// TestCreateActivityStreams_Unit tests CreateActivityStreams with mocked database
func TestCreateActivityStreams_Unit(t *testing.T) {
	activityID := uuid.New()

	tests := []struct {
		name          string
		streams       []models.ActivityStream
		setupMock     func(mock pgxmock.PgxConnIface, streams []models.ActivityStream)
		expectedError bool
	}{
		{
			name: "successful creation",
			streams: []models.ActivityStream{
				{
					ActivityID:        activityID,
					LOD:               models.StreamLODMedium,
					IndexBy:           models.StreamIndexByDistance,
					NumPoints:         100,
					OriginalNumPoints: 1000,
					TimeSBytes:        []byte{1, 2, 3},
					DistanceMBytes:    []byte{10, 20, 30},
					SpeedMpsBytes:     []byte{5, 6, 7},
					ElevationMBytes:   []byte{100, 101, 102},
					Codec: map[string]interface{}{
						"type":        "delta",
						"compression": "gzip",
					},
					CreatedAt: time.Now(),
					UpdatedAt: time.Now(),
				},
			},
			setupMock: func(mock pgxmock.PgxConnIface, streams []models.ActivityStream) {
				mock.ExpectExec(`INSERT INTO activity_streams`).
					WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(),
						pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(),
						pgxmock.AnyArg(), pgxmock.AnyArg()).
					WillReturnResult(pgxmock.NewResult("INSERT", 1))
			},
			expectedError: false,
		},
		{
			name:    "empty streams list",
			streams: []models.ActivityStream{},
			setupMock: func(mock pgxmock.PgxConnIface, streams []models.ActivityStream) {
				// No mock expectations needed
			},
			expectedError: false,
		},
		{
			name: "database error",
			streams: []models.ActivityStream{
				{
					ActivityID:        activityID,
					LOD:               models.StreamLODMedium,
					IndexBy:           models.StreamIndexByDistance,
					NumPoints:         100,
					OriginalNumPoints: 1000,
					TimeSBytes:        []byte{1, 2, 3},
					DistanceMBytes:    []byte{10, 20, 30},
					SpeedMpsBytes:     []byte{5, 6, 7},
					ElevationMBytes:   []byte{100, 101, 102},
					Codec: map[string]interface{}{
						"type": "delta",
					},
					CreatedAt: time.Now(),
					UpdatedAt: time.Now(),
				},
			},
			setupMock: func(mock pgxmock.PgxConnIface, streams []models.ActivityStream) {
				mock.ExpectExec(`INSERT INTO activity_streams`).
					WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(),
						pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(),
						pgxmock.AnyArg(), pgxmock.AnyArg()).
					WillReturnError(fmt.Errorf("constraint violation"))
			},
			expectedError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			db, mock := setupMockDB(t)
			defer mock.Close(context.Background())

			tt.setupMock(mock, tt.streams)

			err := db.CreateActivityStreams(context.Background(), tt.streams)

			if tt.expectedError {
				assert.Error(t, err)
			} else {
				assert.NoError(t, err)
			}

			assert.NoError(t, mock.ExpectationsWereMet())
		})
	}
}

// TestCreateActivityStreams_MarshalError tests codec marshaling errors
func TestCreateActivityStreams_MarshalError_Unit(t *testing.T) {
	activityID := uuid.New()

	// Create a codec with an un-marshalable value (channels can't be JSON marshaled)
	unmarshalableCodec := map[string]interface{}{
		"channel": make(chan int),
	}

	streams := []models.ActivityStream{
		{
			ActivityID:        activityID,
			LOD:               models.StreamLODMedium,
			IndexBy:           models.StreamIndexByDistance,
			NumPoints:         100,
			OriginalNumPoints: 1000,
			TimeSBytes:        []byte{1, 2, 3},
			DistanceMBytes:    []byte{10, 20, 30},
			SpeedMpsBytes:     []byte{5, 6, 7},
			ElevationMBytes:   []byte{100, 101, 102},
			Codec:             unmarshalableCodec,
			CreatedAt:         time.Now(),
			UpdatedAt:         time.Now(),
		},
	}

	db, mock := setupMockDB(t)
	defer mock.Close(context.Background())

	// No mock expectation needed since it should fail before hitting the database

	err := db.CreateActivityStreams(context.Background(), streams)

	// Should fail with JSON marshaling error
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "failed to marshal codec JSON")

	assert.NoError(t, mock.ExpectationsWereMet())
}
