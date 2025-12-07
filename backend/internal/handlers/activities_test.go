package handlers

import (
	"context"
	"errors"
	"math"
	"strings"
	"testing"
	"time"

	"github.com/anish-chanda/cadence/backend/internal/models"
	"github.com/anish-chanda/cadence/backend/internal/valhalla"
	"github.com/google/uuid"
)

// Extended mock database for activities
type activitiesMockDB struct {
	*mockDatabase
	idempotencyResults map[string]bool
	idempotencyError   error
	activities         map[string]*models.Activity
	activityError      error
	streams            map[string][]models.ActivityStream
	streamsError       error
}

func newActivitiesMockDB() *activitiesMockDB {
	return &activitiesMockDB{
		mockDatabase:       newMockDatabase(),
		idempotencyResults: make(map[string]bool),
		activities:         make(map[string]*models.Activity),
		streams:            make(map[string][]models.ActivityStream),
	}
}

func (m *activitiesMockDB) CheckIdempotency(ctx context.Context, clientActivityID string) (bool, error) {
	if m.idempotencyError != nil {
		return false, m.idempotencyError
	}
	return m.idempotencyResults[clientActivityID], nil
}

func (m *activitiesMockDB) CreateActivity(ctx context.Context, activity *models.Activity) error {
	if m.activityError != nil {
		return m.activityError
	}
	m.activities[activity.ID.String()] = activity
	return nil
}

func (m *activitiesMockDB) GetActivityByID(ctx context.Context, activityID string) (*models.Activity, error) {
	if m.activityError != nil {
		return nil, m.activityError
	}
	return m.activities[activityID], nil
}

func (m *activitiesMockDB) GetActivitiesByUserID(ctx context.Context, userID string) ([]models.Activity, error) {
	if m.activityError != nil {
		return nil, m.activityError
	}
	var activities []models.Activity
	for _, activity := range m.activities {
		if activity.UserID == userID {
			activities = append(activities, *activity)
		}
	}
	return activities, nil
}

func (m *activitiesMockDB) CreateActivityStreams(ctx context.Context, streams []models.ActivityStream) error {
	if m.streamsError != nil {
		return m.streamsError
	}
	for _, stream := range streams {
		key := stream.ActivityID.String()
		m.streams[key] = append(m.streams[key], stream)
	}
	return nil
}

func (m *activitiesMockDB) GetActivityStreams(ctx context.Context, activityID string, lod models.StreamLOD) ([]models.ActivityStream, error) {
	if m.streamsError != nil {
		return nil, m.streamsError
	}
	streams := m.streams[activityID]
	var filtered []models.ActivityStream
	for _, stream := range streams {
		if stream.LOD == lod {
			filtered = append(filtered, stream)
		}
	}
	return filtered, nil
}

// Mock Valhalla client
type mockValhallaClient struct {
	heightError error
	heights     map[string]float64
}

func newMockValhallaClient() *mockValhallaClient {
	return &mockValhallaClient{
		heights: make(map[string]float64),
	}
}

func (m *mockValhallaClient) GetHeight(ctx context.Context, lat, lon float64) (float64, error) {
	if m.heightError != nil {
		return 0, m.heightError
	}
	key := string(rune(lat)) + "," + string(rune(lon))
	height, ok := m.heights[key]
	if !ok {
		return 100.0, nil // Default height
	}
	return height, nil
}

// Mock object store
type mockObjectStore struct {
	putError error
	objects  map[string][]byte
}

func newMockObjectStore() *mockObjectStore {
	return &mockObjectStore{
		objects: make(map[string][]byte),
	}
}

func (m *mockObjectStore) Connect() error {
	return nil
}

func (m *mockObjectStore) PutObject(ctx context.Context, key string, data []byte, contentType string) error {
	if m.putError != nil {
		return m.putError
	}
	m.objects[key] = data
	return nil
}

func (m *mockObjectStore) GetObject(ctx context.Context, key string) ([]byte, error) {
	data, ok := m.objects[key]
	if !ok {
		return nil, errors.New("object not found")
	}
	return data, nil
}

func (m *mockObjectStore) DeleteObject(ctx context.Context, key string) error {
	delete(m.objects, key)
	return nil
}

func (m *mockObjectStore) Close() error {
	return nil
}

func TestFloatOrDefault(t *testing.T) {
	tests := []struct {
		name     string
		ptr      *float64
		def      float64
		expected float64
	}{
		{
			name:     "nil pointer returns default",
			ptr:      nil,
			def:      42.5,
			expected: 42.5,
		},
		{
			name:     "valid pointer returns value",
			ptr:      func() *float64 { v := 123.45; return &v }(),
			def:      42.5,
			expected: 123.45,
		},
		{
			name:     "zero value pointer",
			ptr:      func() *float64 { v := 0.0; return &v }(),
			def:      42.5,
			expected: 0.0,
		},
		{
			name:     "negative value pointer",
			ptr:      func() *float64 { v := -99.9; return &v }(),
			def:      42.5,
			expected: -99.9,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := floatOrDefault(tt.ptr, tt.def)
			if result != tt.expected {
				t.Errorf("floatOrDefault() = %f, want %f", result, tt.expected)
			}
		})
	}
}

func TestStringOrDefault(t *testing.T) {
	tests := []struct {
		name     string
		ptr      *string
		def      string
		expected string
	}{
		{
			name:     "nil pointer returns default",
			ptr:      nil,
			def:      "default",
			expected: "default",
		},
		{
			name:     "valid pointer returns value",
			ptr:      func() *string { v := "test"; return &v }(),
			def:      "default",
			expected: "test",
		},
		{
			name:     "empty string pointer",
			ptr:      func() *string { v := ""; return &v }(),
			def:      "default",
			expected: "",
		},
		{
			name:     "unicode string pointer",
			ptr:      func() *string { v := "测试🎌"; return &v }(),
			def:      "default",
			expected: "测试🎌",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := stringOrDefault(tt.ptr, tt.def)
			if result != tt.expected {
				t.Errorf("stringOrDefault() = %s, want %s", result, tt.expected)
			}
		})
	}
}

func TestProcessGPSData(t *testing.T) {
	tests := []struct {
		name             string
		samples          []Sample
		expectedPolyline string  // We'll check if it's not empty
		expectedDistance float64 // Approximate expected distance
		tolerance        float64 // Distance tolerance for comparison
	}{
		{
			name: "simple two-point line",
			samples: []Sample{
				{T: 1000, Lat: 40.0, Lon: -74.0},
				{T: 2000, Lat: 40.001, Lon: -74.001},
			},
			expectedDistance: 150, // Rough approximation
			tolerance:        50,
		},
		{
			name: "square path",
			samples: []Sample{
				{T: 1000, Lat: 40.0, Lon: -74.0},
				{T: 2000, Lat: 40.001, Lon: -74.0},
				{T: 3000, Lat: 40.001, Lon: -74.001},
				{T: 4000, Lat: 40.0, Lon: -74.001},
				{T: 5000, Lat: 40.0, Lon: -74.0},
			},
			expectedDistance: 400, // Rough square perimeter
			tolerance:        100,
		},
		{
			name: "single point should work",
			samples: []Sample{
				{T: 1000, Lat: 40.0, Lon: -74.0},
			},
			expectedDistance: 0,
			tolerance:        0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			polyline, distance, bounds := processGPSData(tt.samples)

			// Check polyline is not empty (except for single point)
			if len(tt.samples) > 1 && polyline == "" {
				t.Error("Expected non-empty polyline for multiple points")
			}

			// Check distance is within tolerance
			if math.Abs(distance-tt.expectedDistance) > tt.tolerance {
				t.Errorf("Distance = %f, expected ~%f (tolerance %f)", distance, tt.expectedDistance, tt.tolerance)
			}

			// Check bounds are reasonable
			if len(tt.samples) > 0 {
				firstSample := tt.samples[0]
				if bounds.MinLat > firstSample.Lat || bounds.MaxLat < firstSample.Lat {
					t.Errorf("Bounds lat range [%f, %f] does not contain sample lat %f", bounds.MinLat, bounds.MaxLat, firstSample.Lat)
				}
				if bounds.MinLon > firstSample.Lon || bounds.MaxLon < firstSample.Lon {
					t.Errorf("Bounds lon range [%f, %f] does not contain sample lon %f", bounds.MinLon, bounds.MaxLon, firstSample.Lon)
				}
			}
		})
	}
}

func TestCalculateElapsedSeconds(t *testing.T) {
	tests := []struct {
		name     string
		samples  []Sample
		expected float64
	}{
		{
			name: "single point",
			samples: []Sample{
				{T: 1000, Lat: 40.0, Lon: -74.0},
			},
			expected: 0,
		},
		{
			name: "two points 1 second apart",
			samples: []Sample{
				{T: 1000, Lat: 40.0, Lon: -74.0},
				{T: 2000, Lat: 40.0, Lon: -74.0},
			},
			expected: 1,
		},
		{
			name: "multiple points over 30 seconds",
			samples: []Sample{
				{T: 1000, Lat: 40.0, Lon: -74.0},
				{T: 11000, Lat: 40.0, Lon: -74.0},
				{T: 21000, Lat: 40.0, Lon: -74.0},
				{T: 31000, Lat: 40.0, Lon: -74.0},
			},
			expected: 30,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := calculateElapsedSeconds(tt.samples)
			if result != tt.expected {
				t.Errorf("calculateElapsedSeconds() = %f, want %f", result, tt.expected)
			}
		})
	}
}

func TestCalculateAverageSpeed(t *testing.T) {
	tests := []struct {
		name           string
		distance       float64
		elapsedSeconds float64
		expectedSpeed  float64
	}{
		{
			name:           "zero time",
			distance:       1000,
			elapsedSeconds: 0,
			expectedSpeed:  0,
		},
		{
			name:           "1000m in 100s = 10 m/s",
			distance:       1000,
			elapsedSeconds: 100,
			expectedSpeed:  10,
		},
		{
			name:           "zero distance",
			distance:       0,
			elapsedSeconds: 100,
			expectedSpeed:  0,
		},
		{
			name:           "fractional speed",
			distance:       1500,
			elapsedSeconds: 300,
			expectedSpeed:  5,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := calculateAverageSpeed(tt.distance, tt.elapsedSeconds)
			if math.Abs(result-tt.expectedSpeed) > 0.001 {
				t.Errorf("calculateAverageSpeed() = %f, want %f", result, tt.expectedSpeed)
			}
		})
	}
}

func TestHaversineDistance(t *testing.T) {
	tests := []struct {
		name      string
		lat1      float64
		lon1      float64
		lat2      float64
		lon2      float64
		expected  float64
		tolerance float64
	}{
		{
			name: "same point",
			lat1: 40.0, lon1: -74.0,
			lat2: 40.0, lon2: -74.0,
			expected:  0,
			tolerance: 1,
		},
		{
			name: "NYC to Philadelphia approximate",
			lat1: 40.7128, lon1: -74.0060,
			lat2: 39.9526, lon2: -75.1652,
			expected:  130000, // ~130km
			tolerance: 10000,
		},
		{
			name: "small distance",
			lat1: 40.0, lon1: -74.0,
			lat2: 40.001, lon2: -74.001,
			expected:  140, // Rough approximation
			tolerance: 50,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := haversineDistance(tt.lat1, tt.lon1, tt.lat2, tt.lon2)
			if math.Abs(result-tt.expected) > tt.tolerance {
				t.Errorf("haversineDistance() = %f, expected ~%f (tolerance %f)", result, tt.expected, tt.tolerance)
			}
		})
	}
}

func TestValidateStreamAlignment(t *testing.T) {
	tests := []struct {
		name           string
		stream         *FullResolutionStream
		expectedLength int
		expectError    bool
		errorSubstring string
	}{
		{
			name:           "nil stream",
			stream:         nil,
			expectError:    true,
			errorSubstring: "stream is nil",
		},
		{
			name: "valid aligned stream",
			stream: &FullResolutionStream{
				TimeS:      []float64{0, 1, 2},
				DistanceM:  []float64{0, 10, 20},
				ElevationM: []float64{100, 110, 120},
				SpeedMps:   []float64{0, 10, 10},
			},
			expectedLength: 3,
			expectError:    false,
		},
		{
			name: "mismatched time array length",
			stream: &FullResolutionStream{
				TimeS:      []float64{0, 1},
				DistanceM:  []float64{0, 10, 20},
				ElevationM: []float64{100, 110, 120},
				SpeedMps:   []float64{0, 10, 10},
			},
			expectedLength: 3,
			expectError:    true,
			errorSubstring: "timeS array length mismatch",
		},
		{
			name: "non-zero first distance",
			stream: &FullResolutionStream{
				TimeS:      []float64{0, 1, 2},
				DistanceM:  []float64{5, 10, 20}, // Should start with 0
				ElevationM: []float64{100, 110, 120},
				SpeedMps:   []float64{0, 10, 10},
			},
			expectedLength: 3,
			expectError:    true,
			errorSubstring: "first distance value should be 0",
		},
		{
			name: "non-zero first time",
			stream: &FullResolutionStream{
				TimeS:      []float64{5, 1, 2}, // Should start with 0
				DistanceM:  []float64{0, 10, 20},
				ElevationM: []float64{100, 110, 120},
				SpeedMps:   []float64{0, 10, 10},
			},
			expectedLength: 3,
			expectError:    true,
			errorSubstring: "first time value should be 0",
		},
		{
			name: "empty stream",
			stream: &FullResolutionStream{
				TimeS:      []float64{},
				DistanceM:  []float64{},
				ElevationM: []float64{},
				SpeedMps:   []float64{},
			},
			expectedLength: 0,
			expectError:    false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := validateStreamAlignment(tt.stream, tt.expectedLength)

			if tt.expectError {
				if err == nil {
					t.Error("Expected error but got none")
				} else if tt.errorSubstring != "" && !strings.Contains(err.Error(), tt.errorSubstring) {
					t.Errorf("Error message '%s' does not contain '%s'", err.Error(), tt.errorSubstring)
				}
			} else {
				if err != nil {
					t.Errorf("Unexpected error: %v", err)
				}
			}
		})
	}
}

func TestDecimateByDistance(t *testing.T) {
	tests := []struct {
		name         string
		stream       *FullResolutionStream
		targetPoints int
		expectError  bool
	}{
		{
			name: "simple decimation",
			stream: &FullResolutionStream{
				TimeS:      []float64{0, 1, 2, 3, 4},
				DistanceM:  []float64{0, 100, 200, 300, 400},
				ElevationM: []float64{100, 110, 120, 130, 140},
				SpeedMps:   []float64{0, 100, 100, 100, 100},
			},
			targetPoints: 3,
			expectError:  false,
		},
		{
			name: "target larger than input",
			stream: &FullResolutionStream{
				TimeS:      []float64{0, 1, 2},
				DistanceM:  []float64{0, 100, 200},
				ElevationM: []float64{100, 110, 120},
				SpeedMps:   []float64{0, 100, 100},
			},
			targetPoints: 10,
			expectError:  false, // Should return all points
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			indices := decimateByDistance(tt.stream, tt.targetPoints)

			if !tt.expectError {
				if len(indices) == 0 {
					t.Error("Expected non-empty indices")
				}

				// Check that returned indices are valid
				for _, idx := range indices {
					if idx < 0 || idx >= len(tt.stream.TimeS) {
						t.Errorf("Invalid index %d for stream length %d", idx, len(tt.stream.TimeS))
					}
				}

				// Check that first and last indices are included
				if len(indices) > 1 {
					if indices[0] != 0 {
						t.Error("First index should be 0")
					}
					if indices[len(indices)-1] != len(tt.stream.TimeS)-1 {
						t.Error("Last index should be the last point")
					}
				}
			}
		})
	}
}

func TestCreateActivityResult(t *testing.T) {
	tests := []struct {
		name     string
		activity *models.Activity
		expected ActivityResult
	}{
		{
			name: "complete activity with all fields",
			activity: &models.Activity{
				ID:             uuid.MustParse("550e8400-e29b-41d4-a716-446655440000"),
				Title:          "Morning Run",
				Description:    stringPtr("Great morning run"),
				ActivityType:   models.ActivityTypeRun,
				StartTime:      time.Date(2023, 1, 1, 8, 0, 0, 0, time.UTC),
				EndTime:        timePtr(time.Date(2023, 1, 1, 9, 0, 0, 0, time.UTC)),
				ElapsedTime:    3600,          // 1 hour
				ProcessingVer:  1,             // int field
				AvgSpeedMps:    floatPtr(3.0), // 3 m/s
				ElevationGainM: floatPtr(100.0),
				ElevationLossM: floatPtr(50.0),
				MaxHeightM:     floatPtr(200.0),
				MinHeightM:     floatPtr(150.0),
				DistanceM:      10800.0, // 10.8 km
				BBoxMinLat:     floatPtr(40.0),
				BBoxMaxLat:     floatPtr(41.0),
				BBoxMinLon:     floatPtr(-74.0),
				BBoxMaxLon:     floatPtr(-73.0),
				StartLat:       floatPtr(40.5),
				StartLon:       floatPtr(-73.5),
				EndLat:         floatPtr(40.6),
				EndLon:         floatPtr(-73.4),
				Polyline:       stringPtr("encoded_polyline"),
				CreatedAt:      time.Date(2023, 1, 1, 9, 0, 0, 0, time.UTC),
				UpdatedAt:      time.Date(2023, 1, 1, 9, 5, 0, 0, time.UTC),
			},
			expected: ActivityResult{
				ID:            "550e8400-e29b-41d4-a716-446655440000",
				Title:         "Morning Run",
				Description:   "Great morning run",
				Type:          "run",
				StartTime:     time.Date(2023, 1, 1, 8, 0, 0, 0, time.UTC),
				EndTime:       timePtr(time.Date(2023, 1, 1, 9, 0, 0, 0, time.UTC)),
				ProcessingVer: 1, // int field
				Stats: ActivityStats{
					ElapsedSeconds: 3600,
					AvgSpeedMs:     3.0,
					ElevationGainM: 100.0,
					ElevationLossM: 50.0,
					MaxHeightM:     200.0,
					MinHeightM:     150.0,
					DistanceM:      10800.0,
					Derived: DerivedStats{
						DistanceKm:    10.8,
						DistanceMiles: 10800.0 / 1609.344,
						PaceSPerKm:    floatPtr(1000.0 / 3.0),   // ~333.33 s/km
						PaceSPerMile:  floatPtr(1609.344 / 3.0), // ~536.45 s/mile
					},
				},
				BBox: BoundingBox{
					MinLat: 40.0,
					MaxLat: 41.0,
					MinLon: -74.0,
					MaxLon: -73.0,
				},
				Start: Coordinate{
					Lat: 40.5,
					Lon: -73.5,
				},
				End: Coordinate{
					Lat: 40.6,
					Lon: -73.4,
				},
				Polyline:  "encoded_polyline",
				CreatedAt: time.Date(2023, 1, 1, 9, 0, 0, 0, time.UTC),
				UpdatedAt: time.Date(2023, 1, 1, 9, 5, 0, 0, time.UTC),
			},
		},
		{
			name: "minimal activity with defaults",
			activity: &models.Activity{
				ID:            uuid.MustParse("550e8400-e29b-41d4-a716-446655440001"),
				Title:         "Basic Activity",
				ActivityType:  models.ActivityTypeRoadBike,
				StartTime:     time.Date(2023, 1, 2, 10, 0, 0, 0, time.UTC),
				EndTime:       timePtr(time.Date(2023, 1, 2, 11, 30, 0, 0, time.UTC)),
				ElapsedTime:   5400,    // 1.5 hours
				DistanceM:     25000.0, // 25 km
				ProcessingVer: 1,
				CreatedAt:     time.Date(2023, 1, 2, 11, 30, 0, 0, time.UTC),
				UpdatedAt:     time.Date(2023, 1, 2, 11, 30, 0, 0, time.UTC),
			},
			expected: ActivityResult{
				ID:            "550e8400-e29b-41d4-a716-446655440001",
				Title:         "Basic Activity",
				Description:   "", // default
				Type:          "road_bike",
				StartTime:     time.Date(2023, 1, 2, 10, 0, 0, 0, time.UTC),
				EndTime:       timePtr(time.Date(2023, 1, 2, 11, 30, 0, 0, time.UTC)),
				ProcessingVer: 1, // int field
				Stats: ActivityStats{
					ElapsedSeconds: 5400,
					AvgSpeedMs:     0.0, // default
					ElevationGainM: 0.0, // default
					ElevationLossM: 0.0, // default
					MaxHeightM:     0.0, // default
					MinHeightM:     0.0, // default
					DistanceM:      25000.0,
					Derived: DerivedStats{
						DistanceKm:    25.0,
						DistanceMiles: 25000.0 / 1609.344,
						// No speed/pace data because avgSpeedMs is 0
					},
				},
				BBox:      BoundingBox{}, // all zeros as defaults
				Start:     Coordinate{},  // all zeros as defaults
				End:       Coordinate{},  // all zeros as defaults
				Polyline:  "",            // default
				CreatedAt: time.Date(2023, 1, 2, 11, 30, 0, 0, time.UTC),
				UpdatedAt: time.Date(2023, 1, 2, 11, 30, 0, 0, time.UTC),
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := createActivityResult(tt.activity)

			// Compare basic fields
			if result.ID != tt.expected.ID {
				t.Errorf("ID = %s, want %s", result.ID, tt.expected.ID)
			}
			if result.Title != tt.expected.Title {
				t.Errorf("Title = %s, want %s", result.Title, tt.expected.Title)
			}
			if result.Description != tt.expected.Description {
				t.Errorf("Description = %s, want %s", result.Description, tt.expected.Description)
			}
			if result.Type != tt.expected.Type {
				t.Errorf("Type = %s, want %s", result.Type, tt.expected.Type)
			}

			// Compare stats
			if result.Stats.ElapsedSeconds != tt.expected.Stats.ElapsedSeconds {
				t.Errorf("ElapsedSeconds = %f, want %f", result.Stats.ElapsedSeconds, tt.expected.Stats.ElapsedSeconds)
			}
			if result.Stats.DistanceM != tt.expected.Stats.DistanceM {
				t.Errorf("DistanceM = %f, want %f", result.Stats.DistanceM, tt.expected.Stats.DistanceM)
			}

			// Compare derived stats
			if math.Abs(result.Stats.Derived.DistanceKm-tt.expected.Stats.Derived.DistanceKm) > 0.001 {
				t.Errorf("DistanceKm = %f, want %f", result.Stats.Derived.DistanceKm, tt.expected.Stats.Derived.DistanceKm)
			}
			if math.Abs(result.Stats.Derived.DistanceMiles-tt.expected.Stats.Derived.DistanceMiles) > 0.001 {
				t.Errorf("DistanceMiles = %f, want %f", result.Stats.Derived.DistanceMiles, tt.expected.Stats.Derived.DistanceMiles)
			}

			// Check pace/speed fields (should be nil if no avgSpeedMs)
			if tt.expected.Stats.Derived.PaceSPerKm != nil {
				if result.Stats.Derived.PaceSPerKm == nil {
					t.Error("Expected PaceSPerKm to be set, got nil")
				} else if math.Abs(*result.Stats.Derived.PaceSPerKm-*tt.expected.Stats.Derived.PaceSPerKm) > 0.1 {
					t.Errorf("PaceSPerKm = %f, want %f", *result.Stats.Derived.PaceSPerKm, *tt.expected.Stats.Derived.PaceSPerKm)
				}
			} else if result.Stats.Derived.PaceSPerKm != nil {
				t.Errorf("Expected PaceSPerKm to be nil, got %f", *result.Stats.Derived.PaceSPerKm)
			}
		})
	}
}

func TestCalculateDerivedStats(t *testing.T) {
	tests := []struct {
		name         string
		activityType string
		speedMs      float64
		distanceM    float64
		expected     DerivedStats
	}{
		{
			name:         "road bike with speed",
			activityType: "road_bike",
			speedMs:      10.0, // 10 m/s = 36 km/h
			distanceM:    25000.0,
			expected: DerivedStats{
				DistanceKm:    25.0,
				DistanceMiles: 25000.0 / 1609.344,
				SpeedKmh:      floatPtr(36.0),     // 10 * 3.6
				SpeedMph:      floatPtr(22.36936), // 10 * 2.236936
			},
		},
		{
			name:         "run with pace",
			activityType: "run",
			speedMs:      3.0, // 3 m/s
			distanceM:    10000.0,
			expected: DerivedStats{
				DistanceKm:    10.0,
				DistanceMiles: 10000.0 / 1609.344,
				PaceSPerKm:    floatPtr(1000.0 / 3.0),   // ~333.33 seconds per km
				PaceSPerMile:  floatPtr(1609.344 / 3.0), // ~536.45 seconds per mile
			},
		},
		{
			name:         "zero speed",
			activityType: "run",
			speedMs:      0.0,
			distanceM:    5000.0,
			expected: DerivedStats{
				DistanceKm:    5.0,
				DistanceMiles: 5000.0 / 1609.344,
				// No pace/speed fields should be set
			},
		},
		{
			name:         "unknown activity type",
			activityType: "swimming",
			speedMs:      2.0,
			distanceM:    1500.0,
			expected: DerivedStats{
				DistanceKm:    1.5,
				DistanceMiles: 1500.0 / 1609.344,
				// No pace/speed fields should be set for unknown activity types
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := calculateDerivedStats(tt.activityType, tt.speedMs, tt.distanceM)

			// Check distance conversions
			if math.Abs(result.DistanceKm-tt.expected.DistanceKm) > 0.001 {
				t.Errorf("DistanceKm = %f, want %f", result.DistanceKm, tt.expected.DistanceKm)
			}
			if math.Abs(result.DistanceMiles-tt.expected.DistanceMiles) > 0.001 {
				t.Errorf("DistanceMiles = %f, want %f", result.DistanceMiles, tt.expected.DistanceMiles)
			}

			// Check speed fields (bike)
			if tt.expected.SpeedKmh != nil {
				if result.SpeedKmh == nil {
					t.Error("Expected SpeedKmh to be set, got nil")
				} else if math.Abs(*result.SpeedKmh-*tt.expected.SpeedKmh) > 0.001 {
					t.Errorf("SpeedKmh = %f, want %f", *result.SpeedKmh, *tt.expected.SpeedKmh)
				}
			} else if result.SpeedKmh != nil {
				t.Errorf("Expected SpeedKmh to be nil, got %f", *result.SpeedKmh)
			}

			if tt.expected.SpeedMph != nil {
				if result.SpeedMph == nil {
					t.Error("Expected SpeedMph to be set, got nil")
				} else if math.Abs(*result.SpeedMph-*tt.expected.SpeedMph) > 0.001 {
					t.Errorf("SpeedMph = %f, want %f", *result.SpeedMph, *tt.expected.SpeedMph)
				}
			} else if result.SpeedMph != nil {
				t.Errorf("Expected SpeedMph to be nil, got %f", *result.SpeedMph)
			}

			// Check pace fields (run)
			if tt.expected.PaceSPerKm != nil {
				if result.PaceSPerKm == nil {
					t.Error("Expected PaceSPerKm to be set, got nil")
				} else if math.Abs(*result.PaceSPerKm-*tt.expected.PaceSPerKm) > 0.1 {
					t.Errorf("PaceSPerKm = %f, want %f", *result.PaceSPerKm, *tt.expected.PaceSPerKm)
				}
			} else if result.PaceSPerKm != nil {
				t.Errorf("Expected PaceSPerKm to be nil, got %f", *result.PaceSPerKm)
			}

			if tt.expected.PaceSPerMile != nil {
				if result.PaceSPerMile == nil {
					t.Error("Expected PaceSPerMile to be set, got nil")
				} else if math.Abs(*result.PaceSPerMile-*tt.expected.PaceSPerMile) > 0.1 {
					t.Errorf("PaceSPerMile = %f, want %f", *result.PaceSPerMile, *tt.expected.PaceSPerMile)
				}
			} else if result.PaceSPerMile != nil {
				t.Errorf("Expected PaceSPerMile to be nil, got %f", *result.PaceSPerMile)
			}
		})
	}
}

func TestInterpolateElevationNulls(t *testing.T) {
	tests := []struct {
		name     string
		input    []*float64
		expected []float64
	}{
		{
			name:     "empty input",
			input:    []*float64{},
			expected: []float64{},
		},
		{
			name:     "all valid values",
			input:    []*float64{floatPtr(10), floatPtr(20), floatPtr(30)},
			expected: []float64{10, 20, 30},
		},
		{
			name:     "all null values",
			input:    []*float64{nil, nil, nil},
			expected: []float64{0, 0, 0},
		},
		{
			name:     "nulls at beginning",
			input:    []*float64{nil, nil, floatPtr(30), floatPtr(40)},
			expected: []float64{30, 30, 30, 40},
		},
		{
			name:     "nulls at end",
			input:    []*float64{floatPtr(10), floatPtr(20), nil, nil},
			expected: []float64{10, 20, 20, 20},
		},
		{
			name:     "nulls in middle - linear interpolation",
			input:    []*float64{floatPtr(10), nil, nil, floatPtr(40)},
			expected: []float64{10, 20, 30, 40}, // Linear interpolation: 10 + (40-10)*(1/3) = 20, 10 + (40-10)*(2/3) = 30
		},
		{
			name:     "complex pattern",
			input:    []*float64{nil, floatPtr(100), nil, floatPtr(200), nil, nil, floatPtr(300)},
			expected: []float64{100, 100, 150, 200, 233.33333333333334, 266.6666666666667, 300}, // Forward fill, interpolation, interpolation
		},
		{
			name:     "single valid value surrounded by nulls",
			input:    []*float64{nil, nil, floatPtr(50), nil, nil},
			expected: []float64{50, 50, 50, 50, 50}, // Forward and backward fill
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := interpolateElevationNulls(tt.input)

			if len(result) != len(tt.expected) {
				t.Errorf("Result length = %d, want %d", len(result), len(tt.expected))
				return
			}

			for i, expected := range tt.expected {
				if math.Abs(result[i]-expected) > 0.0001 {
					t.Errorf("result[%d] = %f, want %f", i, result[i], expected)
				}
			}
		})
	}
}

// Helper function for creating float pointers in tests
func floatPtr(f float64) *float64 {
	return &f
}

// Helper function for creating string pointers in tests
func stringPtr(s string) *string {
	return &s
}

// Helper function for creating time pointers in tests
func timePtr(t time.Time) *time.Time {
	return &t
}

func TestBuildActivityModel(t *testing.T) {
	req := CreateActivityRequest{
		ClientActivityID: uuid.New(),
		ActivityType:     "running",
		Title:            "Test Run",
		Description:      func() *string { s := "Test Description"; return &s }(),
		Samples: []Sample{
			{T: 1000, Lat: 40.0, Lon: -74.0},
			{T: 2000, Lat: 40.001, Lon: -74.001},
		},
	}

	userID := "user123"
	polyline := "test_polyline"
	totalDistance := 150.5
	bounds := Bounds{MinLat: 40.0, MaxLat: 40.001, MinLon: -74.001, MaxLon: -74.0}
	elevationData := valhalla.ElevationChange{
		GainMeters: 10.5,
		LossMeters: 5.2,
		MaxHeight:  120.0,
		MinHeight:  100.0,
	}
	elapsedSeconds := 1.0
	avgSpeedMs := 150.5

	activity := buildActivityModel(req, userID, polyline, totalDistance, bounds, &elevationData, elapsedSeconds, avgSpeedMs)

	if activity.UserID != userID {
		t.Errorf("UserID = %s, want %s", activity.UserID, userID)
	}
	if string(activity.ActivityType) != req.ActivityType {
		t.Errorf("ActivityType = %s, want %s", activity.ActivityType, req.ActivityType)
	}
	if activity.Title != req.Title {
		t.Errorf("Title = %s, want %s", activity.Title, req.Title)
	}
	if activity.Polyline == nil || *activity.Polyline != polyline {
		t.Errorf("Polyline = %v, want %s", activity.Polyline, polyline)
	}
	if activity.DistanceM != totalDistance {
		t.Errorf("DistanceM = %f, want %f", activity.DistanceM, totalDistance)
	}
	if activity.ElapsedTime != int(elapsedSeconds) {
		t.Errorf("ElapsedTime = %d, want %d", activity.ElapsedTime, int(elapsedSeconds))
	}
	if activity.AvgSpeedMps == nil || *activity.AvgSpeedMps != avgSpeedMs {
		t.Errorf("AvgSpeedMps = %v, want %f", activity.AvgSpeedMps, avgSpeedMs)
	}
}
