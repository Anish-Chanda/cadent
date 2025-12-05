package handlers

import (
	"context"
	"encoding/json"
	"net/http"
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
