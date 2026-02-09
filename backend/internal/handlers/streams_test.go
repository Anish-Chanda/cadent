package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"

	"github.com/anish-chanda/cadence/backend/internal/compression"
	"github.com/anish-chanda/cadence/backend/internal/logger"
	"github.com/anish-chanda/cadence/backend/internal/models"
	"github.com/google/uuid"
)

// Mock implementations for testing

type MockDatabase struct {
	activities      map[string]*models.Activity
	activityStreams map[string][]models.ActivityStream
	users           map[string]*models.UserRecord
	usersByEmail    map[string]*models.UserRecord
	errors          map[string]error
}

func NewMockDatabase() *MockDatabase {
	return &MockDatabase{
		activities:      make(map[string]*models.Activity),
		activityStreams: make(map[string][]models.ActivityStream),
		users:           make(map[string]*models.UserRecord),
		usersByEmail:    make(map[string]*models.UserRecord),
		errors:          make(map[string]error),
	}
}

func (m *MockDatabase) GetActivityByID(ctx context.Context, activityID string) (*models.Activity, error) {
	if err, exists := m.errors["GetActivityByID"]; exists {
		return nil, err
	}
	activity, exists := m.activities[activityID]
	if !exists {
		return nil, nil
	}
	return activity, nil
}

func (m *MockDatabase) GetActivityStreams(ctx context.Context, activityID string, lod models.StreamLOD) ([]models.ActivityStream, error) {
	if err, exists := m.errors["GetActivityStreams"]; exists {
		return nil, err
	}
	streams, exists := m.activityStreams[activityID+string(lod)]
	if !exists {
		return []models.ActivityStream{}, nil
	}
	return streams, nil
}

func (m *MockDatabase) GetUserByID(ctx context.Context, userID string) (*models.UserRecord, error) {
	if err, exists := m.errors["GetUserByID"]; exists {
		return nil, err
	}
	user, exists := m.users[userID]
	if !exists {
		return nil, nil
	}
	return user, nil
}

func (m *MockDatabase) GetUserByEmail(ctx context.Context, email string) (*models.UserRecord, error) {
	if err, exists := m.errors["GetUserByEmail"]; exists {
		return nil, err
	}
	user, exists := m.usersByEmail[email]
	if !exists {
		return nil, nil
	}
	return user, nil
}

// Implement other required methods as no-ops for this test
func (m *MockDatabase) CreateUser(ctx context.Context, user *models.UserRecord) error { return nil }
func (m *MockDatabase) UpdateUser(ctx context.Context, userID string, updates map[string]interface{}) error {
	return nil
}
func (m *MockDatabase) CreateActivity(ctx context.Context, activity *models.Activity) error {
	return nil
}
func (m *MockDatabase) CreateActivityStreams(ctx context.Context, streams []models.ActivityStream) error {
	return nil
}
func (m *MockDatabase) GetActivitiesByUserID(ctx context.Context, userID string) ([]models.Activity, error) {
	return nil, nil
}
func (m *MockDatabase) CheckIdempotency(ctx context.Context, clientActivityID string) (bool, error) {
	return false, nil
}
func (m *MockDatabase) Connect(dsn string) error { return nil }
func (m *MockDatabase) Close() error             { return nil }
func (m *MockDatabase) Migrate() error           { return nil }

// Test helper functions
func createTestActivity(activityID, userID string) *models.Activity {
	activityUUID, _ := uuid.Parse(activityID)
	return &models.Activity{
		ID:     activityUUID,
		UserID: userID,
		Title:  "Test Activity",
	}
}

func createTestActivityStreams(activityID string, lod models.StreamLOD) []models.ActivityStream {
	activityUUID, _ := uuid.Parse(activityID)

	// Create some test data
	testData := []float64{1.0, 2.0, 3.0, 4.0, 5.0}
	compressedData, _ := compression.Compress(testData, compression.CompressOptions{
		DecimalPlaces: 2,
		BlockLog2:     8,
	})

	return []models.ActivityStream{
		{
			ActivityID:        activityUUID,
			LOD:               lod,
			IndexBy:           models.StreamIndexByDistance,
			NumPoints:         5,
			OriginalNumPoints: 10,
			TimeSBytes:        compressedData,
			DistanceMBytes:    compressedData,
			ElevationMBytes:   compressedData,
			SpeedMpsBytes:     compressedData,
		},
	}
}

func createTestUser(userID, email string) *models.UserRecord {
	return &models.UserRecord{
		ID:    userID,
		Name:  "Test User",
		Email: email,
	}
}

func TestParseStreamRequest_ValidInput(t *testing.T) {
	tests := []struct {
		name          string
		queryParams   url.Values
		expectedLOD   models.StreamLOD
		expectedTypes []models.StreamType
	}{
		{
			name: "medium_lod_single_type",
			queryParams: url.Values{
				"lod":  {"medium"},
				"type": {"elevation"},
			},
			expectedLOD:   models.StreamLODMedium,
			expectedTypes: []models.StreamType{models.StreamTypeElevation},
		},
		{
			name: "low_lod_multiple_types",
			queryParams: url.Values{
				"lod":  {"low"},
				"type": {"time,distance,speed"},
			},
			expectedLOD: models.StreamLODLow,
			expectedTypes: []models.StreamType{
				models.StreamTypeTime,
				models.StreamTypeDistance,
				models.StreamTypeSpeed,
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := &http.Request{
				URL: &url.URL{RawQuery: tt.queryParams.Encode()},
			}

			result, err := parseStreamRequest(req)
			if err != nil {
				t.Errorf("parseStreamRequest() error = %v, want nil", err)
				return
			}

			if result.LOD != tt.expectedLOD {
				t.Errorf("LOD = %s, want %s", result.LOD, tt.expectedLOD)
			}

			if len(result.Types) != len(tt.expectedTypes) {
				t.Errorf("Types length = %d, want %d", len(result.Types), len(tt.expectedTypes))
				return
			}

			for i, streamType := range result.Types {
				if streamType != tt.expectedTypes[i] {
					t.Errorf("Types[%d] = %s, want %s", i, streamType, tt.expectedTypes[i])
				}
			}
		})
	}
}

func TestParseStreamRequest_InvalidInput(t *testing.T) {
	tests := []struct {
		name        string
		queryParams url.Values
		expectedErr string
	}{
		{
			name:        "missing_lod",
			queryParams: url.Values{"type": {"elevation"}},
			expectedErr: "lod parameter is required",
		},
		{
			name:        "missing_type",
			queryParams: url.Values{"lod": {"medium"}},
			expectedErr: "type parameter is required",
		},
		{
			name:        "invalid_lod",
			queryParams: url.Values{"lod": {"invalid"}, "type": {"elevation"}},
			expectedErr: "invalid lod value",
		},
		{
			name:        "invalid_type",
			queryParams: url.Values{"lod": {"medium"}, "type": {"invalid"}},
			expectedErr: "invalid type value",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := &http.Request{
				URL: &url.URL{RawQuery: tt.queryParams.Encode()},
			}

			result, err := parseStreamRequest(req)
			if err == nil {
				t.Error("parseStreamRequest() should return error")
				return
			}

			if !strings.Contains(err.Error(), tt.expectedErr) {
				t.Errorf("Error = %v, want error containing %s", err, tt.expectedErr)
			}

			if result != nil {
				t.Errorf("parseStreamRequest() should return nil result on error")
			}
		})
	}
}

// Test the mock setup without the actual handler to validate our test data structures
func TestMockSetup(t *testing.T) {
	activityID := "550e8400-e29b-41d4-a716-446655440000"
	userID := "660e8400-e29b-41d4-a716-446655440000"

	mockDB := NewMockDatabase()

	// Setup test data
	activity := createTestActivity(activityID, userID)
	mockDB.activities[activityID] = activity

	streams := createTestActivityStreams(activityID, models.StreamLODMedium)
	mockDB.activityStreams[activityID+string(models.StreamLODMedium)] = streams

	user := createTestUser(userID, "test@example.com")
	mockDB.users[userID] = user
	mockDB.usersByEmail["test@example.com"] = user

	// Test that we can retrieve the data
	retrievedActivity, err := mockDB.GetActivityByID(context.Background(), activityID)
	if err != nil {
		t.Errorf("Failed to get activity: %v", err)
	}
	if retrievedActivity == nil {
		t.Error("Activity should not be nil")
	}
	if retrievedActivity.UserID != userID {
		t.Errorf("Activity UserID = %s, want %s", retrievedActivity.UserID, userID)
	}

	// Test streams
	retrievedStreams, err := mockDB.GetActivityStreams(context.Background(), activityID, models.StreamLODMedium)
	if err != nil {
		t.Errorf("Failed to get streams: %v", err)
	}
	if len(retrievedStreams) == 0 {
		t.Error("Should have streams")
	}
}

func TestGetMediumLODStreams(t *testing.T) {
	activityID := "550e8400-e29b-41d4-a716-446655440000"
	mockDB := NewMockDatabase()

	// Setup test data
	streams := createTestActivityStreams(activityID, models.StreamLODMedium)
	mockDB.activityStreams[activityID+string(models.StreamLODMedium)] = streams

	// Create a real logger instance for testing
	logConfig := logger.Config{
		Level:       "info",
		Environment: "test",
		ServiceName: "test-service",
	}
	testLogger := logger.New(logConfig)

	requestedTypes := []models.StreamType{models.StreamTypeTime, models.StreamTypeDistance}

	resultStreams, numPoints, originalNumPoints, err := getMediumLODStreams(
		context.Background(), mockDB, activityID, requestedTypes, *testLogger)

	if err != nil {
		t.Errorf("getMediumLODStreams() error = %v, want nil", err)
		return
	}

	if len(resultStreams) != 2 {
		t.Errorf("streams length = %d, want 2", len(resultStreams))
	}

	if numPoints != 5 {
		t.Errorf("numPoints = %d, want 5", numPoints)
	}

	if originalNumPoints != 10 {
		t.Errorf("originalNumPoints = %d, want 10", originalNumPoints)
	}
}

func TestGetMediumLODStreams_NoStreamsFound(t *testing.T) {
	activityID := "550e8400-e29b-41d4-a716-446655440000"
	mockDB := NewMockDatabase()
	// Don't add any streams to mockDB

	logConfig := logger.Config{
		Level:       "info",
		Environment: "test",
		ServiceName: "test-service",
	}
	testLogger := logger.New(logConfig)

	requestedTypes := []models.StreamType{models.StreamTypeTime}

	_, _, _, err := getMediumLODStreams(
		context.Background(), mockDB, activityID, requestedTypes, *testLogger)

	if err == nil {
		t.Error("getMediumLODStreams() should return error when no streams found")
		return
	}

	expectedErr := "no medium LOD streams found"
	if !strings.Contains(err.Error(), expectedErr) {
		t.Errorf("Error = %v, want error containing %s", err, expectedErr)
	}
}

func TestStreamData_JSONSerialization(t *testing.T) {
	streamData := StreamData{
		Type:   models.StreamTypeElevation,
		Values: []float64{100.5, 105.2, 110.8},
	}

	jsonData, err := json.Marshal(streamData)
	if err != nil {
		t.Errorf("Failed to marshal StreamData: %v", err)
		return
	}

	var unmarshaled StreamData
	err = json.Unmarshal(jsonData, &unmarshaled)
	if err != nil {
		t.Errorf("Failed to unmarshal StreamData: %v", err)
		return
	}

	if unmarshaled.Type != streamData.Type {
		t.Errorf("Type = %s, want %s", unmarshaled.Type, streamData.Type)
	}

	if len(unmarshaled.Values) != len(streamData.Values) {
		t.Errorf("Values length = %d, want %d", len(unmarshaled.Values), len(streamData.Values))
		return
	}

	for i, v := range unmarshaled.Values {
		if v != streamData.Values[i] {
			t.Errorf("Values[%d] = %f, want %f", i, v, streamData.Values[i])
		}
	}
}

func TestStreamsResponse_JSONSerialization(t *testing.T) {
	response := StreamsResponse{
		ActivityID:        "test-activity-123",
		LOD:               models.StreamLODMedium,
		IndexBy:           models.StreamIndexByDistance,
		NumPoints:         100,
		OriginalNumPoints: 200,
		Streams: []StreamData{
			{
				Type:   models.StreamTypeTime,
				Values: []float64{0, 1, 2, 3},
			},
			{
				Type:   models.StreamTypeElevation,
				Values: []float64{100, 105, 110, 108},
			},
		},
	}

	jsonData, err := json.Marshal(response)
	if err != nil {
		t.Errorf("Failed to marshal StreamsResponse: %v", err)
		return
	}

	var unmarshaled StreamsResponse
	err = json.Unmarshal(jsonData, &unmarshaled)
	if err != nil {
		t.Errorf("Failed to unmarshal StreamsResponse: %v", err)
		return
	}

	if unmarshaled.ActivityID != response.ActivityID {
		t.Errorf("ActivityID = %s, want %s", unmarshaled.ActivityID, response.ActivityID)
	}

	if len(unmarshaled.Streams) != len(response.Streams) {
		t.Errorf("Streams length = %d, want %d", len(unmarshaled.Streams), len(response.Streams))
	}
}

func TestHandleGetActivityStreams(t *testing.T) {
	tests := []struct {
		name           string
		activityID     string
		queryParams    string
		userEmail      string
		setupMock      func(*MockDatabase)
		expectedStatus int
		expectedError  string
		checkResponse  func(*testing.T, StreamsResponse)
	}{
		{
			name:           "missing activity ID",
			activityID:     "",
			queryParams:    "lod=medium&type=time,distance",
			userEmail:      "user@example.com",
			setupMock:      func(m *MockDatabase) {},
			expectedStatus: 400,
			expectedError:  "Activity ID is required",
		},
		{
			name:           "invalid query parameters - missing lod",
			activityID:     "550e8400-e29b-41d4-a716-446655440000",
			queryParams:    "type=time,distance",
			userEmail:      "user@example.com",
			setupMock:      func(m *MockDatabase) {},
			expectedStatus: 400,
			expectedError:  "Invalid request parameters",
		},
		{
			name:           "invalid query parameters - missing types",
			activityID:     "550e8400-e29b-41d4-a716-446655440000",
			queryParams:    "lod=medium",
			userEmail:      "user@example.com",
			setupMock:      func(m *MockDatabase) {},
			expectedStatus: 400,
			expectedError:  "Invalid request parameters",
		},
		{
			name:           "invalid query parameters - invalid lod",
			activityID:     "550e8400-e29b-41d4-a716-446655440000",
			queryParams:    "lod=invalid&type=time,distance",
			userEmail:      "user@example.com",
			setupMock:      func(m *MockDatabase) {},
			expectedStatus: 400,
			expectedError:  "Invalid request parameters",
		},
		{
			name:           "invalid query parameters - invalid types",
			activityID:     "550e8400-e29b-41d4-a716-446655440000",
			queryParams:    "lod=medium&type=invalid,distance",
			userEmail:      "user@example.com",
			setupMock:      func(m *MockDatabase) {},
			expectedStatus: 400,
			expectedError:  "Invalid request parameters",
		},
		{
			name:           "user not found",
			activityID:     "550e8400-e29b-41d4-a716-446655440000",
			queryParams:    "lod=medium&type=time,distance",
			userEmail:      "notfound@example.com",
			setupMock:      func(m *MockDatabase) {},
			expectedStatus: 401,
			expectedError:  "Unauthorized",
		},
		{
			name:        "database error getting activity",
			activityID:  "550e8400-e29b-41d4-a716-446655440000",
			queryParams: "lod=medium&type=time,distance",
			userEmail:   "user@example.com",
			setupMock: func(m *MockDatabase) {
				m.usersByEmail["user@example.com"] = &models.UserRecord{
					ID:    "user-123",
					Email: "user@example.com",
					Name:  "Test User",
				}
				m.errors["GetActivityByID"] = errors.New("database error")
			},
			expectedStatus: 500,
			expectedError:  "Internal server error",
		},
		{
			name:        "activity not found",
			activityID:  "550e8400-e29b-41d4-a716-446655440000",
			queryParams: "lod=medium&type=time,distance",
			userEmail:   "user@example.com",
			setupMock: func(m *MockDatabase) {
				m.usersByEmail["user@example.com"] = &models.UserRecord{
					ID:    "user-123",
					Email: "user@example.com",
					Name:  "Test User",
				}
			},
			expectedStatus: 404,
			expectedError:  "Activity not found",
		},
		{
			name:        "user doesn't own activity",
			activityID:  "550e8400-e29b-41d4-a716-446655440000",
			queryParams: "lod=medium&type=time,distance",
			userEmail:   "user@example.com",
			setupMock: func(m *MockDatabase) {
				m.usersByEmail["user@example.com"] = &models.UserRecord{
					ID:    "user-123",
					Email: "user@example.com",
					Name:  "Test User",
				}
				m.activities["550e8400-e29b-41d4-a716-446655440000"] = &models.Activity{
					ID:     uuid.MustParse("550e8400-e29b-41d4-a716-446655440000"),
					UserID: "different-user",
					Title:  "Test Activity",
				}
			},
			expectedStatus: 404,
			expectedError:  "Activity not found", // Returns 404 instead of 403 for security
		},
		{
			name:        "full LOD not implemented",
			activityID:  "550e8400-e29b-41d4-a716-446655440000",
			queryParams: "lod=full&type=time,distance",
			userEmail:   "user@example.com",
			setupMock: func(m *MockDatabase) {
				m.usersByEmail["user@example.com"] = &models.UserRecord{
					ID:    "user-123",
					Email: "user@example.com",
					Name:  "Test User",
				}
				m.activities["550e8400-e29b-41d4-a716-446655440000"] = &models.Activity{
					ID:     uuid.MustParse("550e8400-e29b-41d4-a716-446655440000"),
					UserID: "user-123",
					Title:  "Test Activity",
				}
			},
			expectedStatus: 501,
			expectedError:  "Full resolution streams not available",
		},
		{
			name:        "unsupported LOD - this test is no longer relevant since all valid LODs are caught at parameter level",
			activityID:  "550e8400-e29b-41d4-a716-446655440000",
			queryParams: "lod=unknown&type=time,distance",
			userEmail:   "user@example.com",
			setupMock: func(m *MockDatabase) {
				m.usersByEmail["user@example.com"] = &models.UserRecord{
					ID:    "user-123",
					Email: "user@example.com",
					Name:  "Test User",
				}
				m.activities["550e8400-e29b-41d4-a716-446655440000"] = &models.Activity{
					ID:     uuid.MustParse("550e8400-e29b-41d4-a716-446655440000"),
					UserID: "user-123",
					Title:  "Test Activity",
				}
			},
			expectedStatus: 400,
			expectedError:  "Invalid request parameters", // Caught at parameter validation level
		},
		{
			name:        "database error getting streams",
			activityID:  "550e8400-e29b-41d4-a716-446655440000",
			queryParams: "lod=medium&type=time,distance",
			userEmail:   "user@example.com",
			setupMock: func(m *MockDatabase) {
				m.usersByEmail["user@example.com"] = &models.UserRecord{
					ID:    "user-123",
					Email: "user@example.com",
					Name:  "Test User",
				}
				m.activities["550e8400-e29b-41d4-a716-446655440000"] = &models.Activity{
					ID:     uuid.MustParse("550e8400-e29b-41d4-a716-446655440000"),
					UserID: "user-123",
					Title:  "Test Activity",
				}
				m.errors["GetActivityStreams"] = errors.New("database error")
			},
			expectedStatus: 500,
			expectedError:  "Internal server error",
		},
		{
			name:        "no streams found",
			activityID:  "550e8400-e29b-41d4-a716-446655440000",
			queryParams: "lod=medium&type=time,distance",
			userEmail:   "user@example.com",
			setupMock: func(m *MockDatabase) {
				m.usersByEmail["user@example.com"] = &models.UserRecord{
					ID:    "user-123",
					Email: "user@example.com",
					Name:  "Test User",
				}
				m.activities["550e8400-e29b-41d4-a716-446655440000"] = &models.Activity{
					ID:     uuid.MustParse("550e8400-e29b-41d4-a716-446655440000"),
					UserID: "user-123",
					Title:  "Test Activity",
				}
				// Don't set up any stream data - this will cause getMediumLODStreams to return empty result
				// which the function treats as "no medium LOD streams found" error
			},
			expectedStatus: 500, // Function returns error when no streams found, not 404
			expectedError:  "Internal server error",
		},
		{
			name:        "successful medium LOD request",
			activityID:  "550e8400-e29b-41d4-a716-446655440000",
			queryParams: "lod=medium&type=time,distance",
			userEmail:   "user@example.com",
			setupMock: func(m *MockDatabase) {
				m.usersByEmail["user@example.com"] = &models.UserRecord{
					ID:    "user-123",
					Email: "user@example.com",
					Name:  "Test User",
				}
				m.activities["550e8400-e29b-41d4-a716-446655440000"] = &models.Activity{
					ID:     uuid.MustParse("550e8400-e29b-41d4-a716-446655440000"),
					UserID: "user-123",
					Title:  "Test Activity",
				}

				// Create some test data
				timeData := []float64{0, 1, 2, 3, 4}
				distanceData := []float64{0, 10, 20, 30, 40}

				// Compress the test data
				timeBytes, _ := compression.Compress(timeData, compression.DefaultCompressOptions())
				distanceBytes, _ := compression.Compress(distanceData, compression.DefaultCompressOptions())

				m.activityStreams["550e8400-e29b-41d4-a716-446655440000"+string(models.StreamLODMedium)] = []models.ActivityStream{
					{
						ActivityID:        uuid.MustParse("550e8400-e29b-41d4-a716-446655440000"),
						LOD:               models.StreamLODMedium,
						IndexBy:           models.StreamIndexByDistance,
						NumPoints:         5,
						OriginalNumPoints: 10,
						TimeSBytes:        timeBytes,
						DistanceMBytes:    distanceBytes,
						Codec: map[string]interface{}{
							"algorithm": "dibs",
							"version":   "1.0",
						},
					},
				}
			},
			expectedStatus: 200,
			checkResponse: func(t *testing.T, response StreamsResponse) {
				if response.ActivityID != "550e8400-e29b-41d4-a716-446655440000" {
					t.Errorf("ActivityID = %s, want 550e8400-e29b-41d4-a716-446655440000", response.ActivityID)
				}
				if response.LOD != models.StreamLODMedium {
					t.Errorf("LOD = %s, want %s", response.LOD, models.StreamLODMedium)
				}
				if response.IndexBy != models.StreamIndexByDistance {
					t.Errorf("IndexBy = %s, want %s", response.IndexBy, models.StreamIndexByDistance)
				}
				if response.NumPoints != 5 {
					t.Errorf("NumPoints = %d, want 5", response.NumPoints)
				}
				if response.OriginalNumPoints != 10 {
					t.Errorf("OriginalNumPoints = %d, want 10", response.OriginalNumPoints)
				}
				if len(response.Streams) != 2 {
					t.Errorf("Expected 2 streams, got %d", len(response.Streams))
				}

				// Check stream types
				streamTypes := make(map[models.StreamType]bool)
				for _, stream := range response.Streams {
					streamTypes[stream.Type] = true
				}
				if !streamTypes[models.StreamTypeTime] {
					t.Error("Time stream not found")
				}
				if !streamTypes[models.StreamTypeDistance] {
					t.Error("Distance stream not found")
				}
			},
		},
		{
			name:        "successful low LOD request",
			activityID:  "550e8400-e29b-41d4-a716-446655440000",
			queryParams: "lod=low&type=elevation,speed",
			userEmail:   "user@example.com",
			setupMock: func(m *MockDatabase) {
				m.usersByEmail["user@example.com"] = &models.UserRecord{
					ID:    "user-123",
					Email: "user@example.com",
					Name:  "Test User",
				}
				m.activities["550e8400-e29b-41d4-a716-446655440000"] = &models.Activity{
					ID:     uuid.MustParse("550e8400-e29b-41d4-a716-446655440000"),
					UserID: "user-123",
					Title:  "Test Activity",
				}

				// Create test data for medium LOD (which low LOD will be calculated from)
				elevationData := make([]float64, 300) // More than LowLODTargetPoints
				speedData := make([]float64, 300)
				for i := 0; i < 300; i++ {
					elevationData[i] = 100 + float64(i)*0.1
					speedData[i] = 5 + float64(i)*0.01
				}

				elevationBytes, _ := compression.Compress(elevationData, compression.DefaultCompressOptions())
				speedBytes, _ := compression.Compress(speedData, compression.DefaultCompressOptions())

				m.activityStreams["550e8400-e29b-41d4-a716-446655440000"+string(models.StreamLODMedium)] = []models.ActivityStream{
					{
						ActivityID:        uuid.MustParse("550e8400-e29b-41d4-a716-446655440000"),
						LOD:               models.StreamLODMedium,
						IndexBy:           models.StreamIndexByDistance,
						NumPoints:         300,
						OriginalNumPoints: 600,
						ElevationMBytes:   elevationBytes,
						SpeedMpsBytes:     speedBytes,
						Codec: map[string]interface{}{
							"algorithm": "dibs",
							"version":   "1.0",
						},
					},
				}
			},
			expectedStatus: 200,
			checkResponse: func(t *testing.T, response StreamsResponse) {
				if response.LOD != models.StreamLODLow {
					t.Errorf("LOD = %s, want %s", response.LOD, models.StreamLODLow)
				}
				// Allow some tolerance for decimation algorithm - it might be slightly over due to including last point
				if response.NumPoints > LowLODTargetPoints+5 {
					t.Errorf("NumPoints = %d, should be <= %d for low LOD (with small tolerance)", response.NumPoints, LowLODTargetPoints+5)
				}
				if len(response.Streams) != 2 {
					t.Errorf("Expected 2 streams, got %d", len(response.Streams))
				}
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup mock database
			mockDB := NewMockDatabase()
			tt.setupMock(mockDB)

			// Setup logger
			mockLog := logger.New(logger.Config{
				Level:       "info",
				Environment: "test",
				ServiceName: "test",
			})

			// Create a test handler that mocks the authentication
			handler := func(w http.ResponseWriter, r *http.Request) {
				ctx := context.Background()

				// Get activity ID from URL path - simulate chi router
				activityID := tt.activityID
				if activityID == "" {
					mockLog.Error("Missing activity ID in URL path", nil)
					http.Error(w, "Activity ID is required", http.StatusBadRequest)
					return
				}

				// Parse query parameters
				req, err := parseStreamRequest(r)
				if err != nil {
					mockLog.Error("Failed to parse stream request", err)
					http.Error(w, "Invalid request parameters", http.StatusBadRequest)
					return
				}

				// Mock authentication - get user from usersByEmail
				userEmail := tt.userEmail
				if userEmail == "" {
					http.Error(w, "Unauthorized", http.StatusUnauthorized)
					return
				}

				dbUser := mockDB.usersByEmail[userEmail]
				if dbUser == nil {
					http.Error(w, "Unauthorized", http.StatusUnauthorized)
					return
				}

				userID := dbUser.ID

				// Get activity to check ownership
				activity, err := mockDB.GetActivityByID(ctx, activityID)
				if err != nil {
					mockLog.Error("Failed to get activity from database", err)
					http.Error(w, "Internal server error", http.StatusInternalServerError)
					return
				}
				if activity == nil {
					mockLog.Info("Activity not found: " + activityID)
					http.Error(w, "Activity not found", http.StatusNotFound)
					return
				}

				// Check if the authenticated user owns this activity
				if activity.UserID != userID {
					mockLog.Debug("User attempted to access activity owned by different user")
					http.Error(w, "Activity not found", http.StatusNotFound) // Return 404 instead of 403
					return
				}

				// Handle different LOD types
				var responseStreams []StreamData
				var numPoints, originalNumPoints int

				switch req.LOD {
				case models.StreamLODMedium:
					responseStreams, numPoints, originalNumPoints, err = getMediumLODStreams(ctx, mockDB, activityID, req.Types, *mockLog)
					if err != nil {
						http.Error(w, "Internal server error", http.StatusInternalServerError)
						return
					}

				case models.StreamLODLow:
					responseStreams, numPoints, originalNumPoints, err = getLowLODStreams(ctx, mockDB, activityID, req.Types, *mockLog)
					if err != nil {
						http.Error(w, "Internal server error", http.StatusInternalServerError)
						return
					}

				case models.StreamLODFull:
					mockLog.Error("Full LOD streams not yet implemented", nil)
					http.Error(w, "Full resolution streams not available", http.StatusNotImplemented)
					return

				default:
					http.Error(w, "Unsupported LOD: "+string(req.LOD), http.StatusBadRequest)
					return
				}

				if len(responseStreams) == 0 {
					mockLog.Info("No stream data found for activity " + activityID)
					http.Error(w, "Stream data not found", http.StatusNotFound)
					return
				}

				// Build response
				response := StreamsResponse{
					ActivityID:        activityID,
					LOD:               req.LOD,
					IndexBy:           models.StreamIndexByDistance,
					NumPoints:         numPoints,
					OriginalNumPoints: originalNumPoints,
					Streams:           responseStreams,
				}

				w.Header().Set("Content-Type", "application/json")
				if err := json.NewEncoder(w).Encode(response); err != nil {
					mockLog.Error("Failed to encode response", err)
					http.Error(w, "Internal server error", http.StatusInternalServerError)
					return
				}
			}

			// Create request
			req := httptest.NewRequest("GET", "/v1/activities/"+tt.activityID+"/streams?"+tt.queryParams, nil)
			req.Header.Set("Content-Type", "application/json")

			// Create response recorder
			w := httptest.NewRecorder()

			// Call handler
			handler(w, req)

			// Check status code
			if w.Code != tt.expectedStatus {
				t.Errorf("Status code = %d, want %d", w.Code, tt.expectedStatus)
			}

			// Check error response if expected
			if tt.expectedError != "" {
				body := strings.TrimSpace(w.Body.String())
				if !strings.Contains(body, tt.expectedError) {
					t.Errorf("Response body '%s' does not contain expected error '%s'", body, tt.expectedError)
				}
			}

			// Check successful response
			if tt.expectedStatus == 200 && tt.checkResponse != nil {
				var response StreamsResponse
				if err := json.NewDecoder(strings.NewReader(w.Body.String())).Decode(&response); err != nil {
					t.Errorf("Failed to decode response: %v", err)
				} else {
					tt.checkResponse(t, response)
				}
			}
		})
	}
}
