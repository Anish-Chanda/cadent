package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"net/http"
	"strings"
	"time"

	"github.com/anish-chanda/cadence/backend/internal/compression"
	"github.com/anish-chanda/cadence/backend/internal/db"
	"github.com/anish-chanda/cadence/backend/internal/geo"
	"github.com/anish-chanda/cadence/backend/internal/logger"
	"github.com/anish-chanda/cadence/backend/internal/models"
	"github.com/anish-chanda/cadence/backend/internal/store"
	"github.com/anish-chanda/cadence/backend/internal/valhalla"
	"github.com/go-pkgz/auth/v2/token"
	"github.com/google/uuid"
	"github.com/muktihari/fit/encoder"
	"github.com/muktihari/fit/profile/filedef"
	"github.com/muktihari/fit/profile/mesgdef"
	"github.com/muktihari/fit/profile/typedef"
)

// Stream processing constants
const (
	MediumLODTargetPoints = 2000 // Target number of points for medium LOD streams
)

type CreateActivityRequest struct {
	ClientActivityID uuid.UUID `json:"client_activity_id"`
	ActivityType     string    `json:"activity_type"`
	Title            string    `json:"title"`
	Description      *string   `json:"description"`
	Samples          []Sample  `json:"samples"`
}

type Sample struct {
	T   int64   `json:"t"`   // timestamp in unix milliseconds
	Lat float64 `json:"lat"` // latitude
	Lon float64 `json:"lon"` // longitude
}

// FullResolutionStream holds full-resolution stream data for all points
type FullResolutionStream struct {
	TimeS      []float64 // time in seconds since start
	DistanceM  []float64 // cumulative distance in meters
	ElevationM []float64 // elevation in meters
	SpeedMps   []float64 // speed in meters per second
}

type ActivityStats struct {
	ElapsedSeconds float64      `json:"elapsed_seconds"`
	AvgSpeedMs     float64      `json:"avg_speed_ms"`     // meters per second (SI unit)
	ElevationGainM float64      `json:"elevation_gain_m"` // elevation gain in meters
	ElevationLossM float64      `json:"elevation_loss_m"` // elevation loss in meters
	MaxHeightM     float64      `json:"max_height_m"`     // maximum height in meters
	MinHeightM     float64      `json:"min_height_m"`     // minimum height in meters
	DistanceM      float64      `json:"distance_m"`       // distance in meters
	Derived        DerivedStats `json:"derived"`
}

type DerivedStats struct {
	SpeedKmh      *float64 `json:"speed_kmh,omitempty"`
	SpeedMph      *float64 `json:"speed_mph,omitempty"`
	PaceSPerKm    *float64 `json:"pace_s_per_km,omitempty"`
	PaceSPerMile  *float64 `json:"pace_s_per_mile,omitempty"`
	DistanceKm    float64  `json:"distance_km"`
	DistanceMiles float64  `json:"distance_miles"`
}

type BoundingBox struct {
	MinLat float64 `json:"min_lat"`
	MaxLat float64 `json:"max_lat"`
	MinLon float64 `json:"min_lon"`
	MaxLon float64 `json:"max_lon"`
}

type Coordinate struct {
	Lat float64 `json:"lat"`
	Lon float64 `json:"lon"`
}

type ActivityResult struct {
	ID            string        `json:"id"`
	Title         string        `json:"title"`
	Description   string        `json:"description"`
	Type          string        `json:"type"`
	StartTime     time.Time     `json:"start_time"`
	EndTime       *time.Time    `json:"end_time"`
	Stats         ActivityStats `json:"stats"`
	BBox          BoundingBox   `json:"bbox"`
	Start         Coordinate    `json:"start"`
	End           Coordinate    `json:"end"`
	Polyline      string        `json:"polyline"`
	ProcessingVer int           `json:"processing_ver"`
	CreatedAt     time.Time     `json:"created_at"`
	UpdatedAt     time.Time     `json:"updated_at"`
}

type GetActivitiesResponse struct {
	Activities []ActivityResult `json:"activities"`
}

func HandleCreateActivity(database db.Database, valhallaClient *valhalla.Client, objectStore store.ObjectStore, log logger.ServiceLogger) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// TODO: Use go routines to optimize stream processing performance
		ctx := context.Background()

		var req CreateActivityRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			log.Error("Failed to decode request", err)
			http.Error(w, "Invalid request body", http.StatusBadRequest)
			return
		}

		// TODO: Add proper request validation for required fields
		if req.ClientActivityID == uuid.Nil {
			http.Error(w, "client_activity_id is required", http.StatusBadRequest)
			return
		}
		if req.ActivityType == "" {
			http.Error(w, "activity_type is required", http.StatusBadRequest)
			return
		}
		if len(req.Samples) < 2 {
			http.Error(w, "At least 2 samples are required", http.StatusBadRequest)
			return
		}

		// Validate sample data completeness
		for i, sample := range req.Samples {
			if sample.T <= 0 {
				http.Error(w, fmt.Sprintf("Sample %d: timestamp (t) is required and must be positive", i+1), http.StatusBadRequest)
				return
			}
			// Check that coordinates are not at null island (0,0) which is invalid for real GPS data
			if sample.Lat == 0 || sample.Lon == 0 {
				http.Error(w, fmt.Sprintf("Sample %d: valid coordinates (lat, lon) are required and cannot be zero", i+1), http.StatusBadRequest)
				return
			}
		}

		// Check idempotency
		exists, err := database.CheckIdempotency(ctx, req.ClientActivityID.String())
		if err != nil {
			log.Error("Failed to check idempotency", err)
			http.Error(w, "Internal server error", http.StatusInternalServerError)
			return
		}
		if exists {
			http.Error(w, "Activity already exists", http.StatusConflict)
			return
		}

		// Get authenticated user ID
		userID, err := getAuthenticatedUserID(ctx, r, database, log)
		if err != nil {
			http.Error(w, err.Error(), http.StatusUnauthorized)
			return
		}

		log.Debug(fmt.Sprintf("Processing activity for user: %s", userID))
		// Validate activity_type enum before database insertion to return 400
		if req.ActivityType != string(models.ActivityTypeRun) && req.ActivityType != string(models.ActivityTypeRoadBike) {
			log.Error("Invalid activity type", fmt.Errorf("unsupported activity_type: %s", req.ActivityType))
			http.Error(w, fmt.Sprintf("Invalid activity_type: %s. Supported types: run, road_bike", req.ActivityType), http.StatusBadRequest)
			return
		}
		// Process GPS data to create polyline and calculate metrics
		polyline, totalDistance, bounds := processGPSData(req.Samples)

		// Get elevation data from Valhalla
		elevationData, elevationHeights := getElevationDataAndHeights(ctx, valhallaClient, polyline, log)

		// Calculate time-based metrics
		elapsedSeconds := calculateElapsedSeconds(req.Samples)
		avgSpeedMs := calculateAverageSpeed(totalDistance, elapsedSeconds)

		// Create activity model
		activity := buildActivityModel(req, userID, polyline, totalDistance, bounds, elevationData, elapsedSeconds, avgSpeedMs)

		// Process full-resolution streams
		fullStream := processFullResolutionStreams(req.Samples, elevationData, elevationHeights)

		// Validate stream alignment (all arrays should have same length)
		if err := validateStreamAlignment(fullStream, len(req.Samples)); err != nil {
			log.Error("Stream alignment validation failed", err)
			http.Error(w, "Internal stream processing error", http.StatusInternalServerError)
			return
		}

		// Create medium LOD streams using distance decimation
		mediumTargetPoints := MediumLODTargetPoints
		keepIndices := decimateByDistance(fullStream, mediumTargetPoints)

		// Create compressed medium LOD streams
		activityStreams, err := createCompressedStreams(activity.ID, keepIndices, fullStream)
		if err != nil {
			log.Error("Failed to create compressed streams", err)
			http.Error(w, "Failed to process stream data", http.StatusInternalServerError)
			return
		}

		// Create and store FIT file
		if err := createAndStoreFITFile(ctx, activity, req.Samples, objectStore, log); err != nil {
			log.Error("Failed to create FIT file", err)
			http.Error(w, "Failed to create FIT file", http.StatusInternalServerError)
			return
		}

		// Save activity to database
		if err := database.CreateActivity(ctx, activity); err != nil {
			log.Error("Failed to save activity to database", err)
			http.Error(w, "Failed to save activity", http.StatusInternalServerError)
			return
		}

		// Save activity streams to database
		if len(activityStreams) > 0 {
			if err := database.CreateActivityStreams(ctx, activityStreams); err != nil {
				log.Error("Failed to save activity streams to database", err)
				// Log error but don't fail the request since main activity was saved
				log.Info("Activity created successfully but streams failed to save")
			} else {
				log.Debug(fmt.Sprintf("Successfully saved %d streams for activity: %s", len(activityStreams), activity.ID.String()))
			}
		}

		log.Debug(fmt.Sprintf("Created activity: %s for user: %s", activity.ID.String(), userID))

		// Build and return response
		result := createActivityResult(activity)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(w).Encode(result)
	}
}

// Helper function to extract and validate authenticated user ID
func getAuthenticatedUserID(ctx context.Context, r *http.Request, database db.Database, log logger.ServiceLogger) (string, error) {
	user, err := token.GetUserInfo(r)
	if err != nil {
		log.Error("Failed to get user info from token", err)
		return "", fmt.Errorf("Unauthorized")
	}

	// the goauth package stores email in Name field for local provider
	userEmail := user.Name
	if userEmail == "" {
		log.Error("No email found in user token", nil)
		return "", fmt.Errorf("Unauthorized")
	}

	dbUser, err := database.GetUserByEmail(ctx, userEmail)
	if err != nil {
		log.Error("Failed to get user from database", err)
		return "", fmt.Errorf("Internal server error")
	}
	if dbUser == nil {
		log.Error("User not found in database", nil)
		return "", fmt.Errorf("User not found")
	}

	return dbUser.ID, nil
}

// Helper functions for null handling
func floatOrDefault(ptr *float64, defaultVal float64) float64 {
	if ptr != nil {
		return *ptr
	}
	return defaultVal
}

func stringOrDefault(ptr *string, defaultVal string) string {
	if ptr != nil {
		return *ptr
	}
	return defaultVal
}

// BoundingBox represents geographical bounds
type Bounds struct {
	MinLat float64
	MaxLat float64
	MinLon float64
	MaxLon float64
}

// Helper function to process GPS data and generate polyline, distance, and bounds
func processGPSData(samples []Sample) (string, float64, Bounds) {
	// Convert samples to geo.Point format
	geoPoints := make([]geo.Point, 0, len(samples))
	for _, s := range samples {
		geoPoints = append(geoPoints, geo.Point{
			Lat: s.Lat,
			Lon: s.Lon,
		})
	}

	// Create polyline directly from GPS points
	polyline := geo.Encode6(geoPoints)

	// Calculate total distance using Haversine formula
	var totalDistance float64
	for i := 1; i < len(samples); i++ {
		prev := samples[i-1]
		curr := samples[i]
		distance := haversineDistance(prev.Lat, prev.Lon, curr.Lat, curr.Lon)
		totalDistance += distance
	}

	// Calculate bounding box
	bounds := Bounds{
		MinLat: samples[0].Lat,
		MaxLat: samples[0].Lat,
		MinLon: samples[0].Lon,
		MaxLon: samples[0].Lon,
	}

	for _, s := range samples {
		if s.Lat < bounds.MinLat {
			bounds.MinLat = s.Lat
		}
		if s.Lat > bounds.MaxLat {
			bounds.MaxLat = s.Lat
		}
		if s.Lon < bounds.MinLon {
			bounds.MinLon = s.Lon
		}
		if s.Lon > bounds.MaxLon {
			bounds.MaxLon = s.Lon
		}
	}

	return polyline, totalDistance, bounds
}

// Helper function to get elevation data and heights from Valhalla
func getElevationDataAndHeights(ctx context.Context, valhallaClient *valhalla.Client, polyline string, log logger.ServiceLogger) (*valhalla.ElevationChange, []float64) {
	heightReq := valhalla.HeightRequest{
		Range:           false, // range off
		EncodedPolyline: polyline,
		HeightPrecision: 2, // Request 2 decimal places precision
	}

	heightResp, err := valhallaClient.GetHeight(ctx, heightReq)
	if err != nil {
		log.Error("Failed to get height data from Valhalla", err)
		return nil, nil
	}

	// Calculate elevation change from height response with 2.0m threshold
	elevationChangeResult := valhalla.CalculateElevationChange(heightResp, 2.0)
	log.Debug(fmt.Sprintf("Calculated elevation - Gain: %.2f m, Loss: %.2f m, Max: %.2f m, Min: %.2f m",
		elevationChangeResult.GainMeters, elevationChangeResult.LossMeters, elevationChangeResult.MaxHeight, elevationChangeResult.MinHeight))

	// Extract elevation heights array, handling nulls with interpolation
	var heights []float64
	if heightResp.Height != nil {
		heights = interpolateElevationNulls(heightResp.Height)
	}

	return &elevationChangeResult, heights
}

// interpolateElevationNulls interpolates null elevation values using linear interpolation
// Treats elevation as a function of distance for proper interpolation
func interpolateElevationNulls(rawHeights []*float64) []float64 {
	if len(rawHeights) == 0 {
		return []float64{}
	}

	heights := make([]float64, len(rawHeights))

	// First pass: copy non-null values
	for i, h := range rawHeights {
		if h != nil {
			heights[i] = *h
		}
	}

	// Handle edge case: if all values are null, return zeros
	hasValidValue := false
	for _, h := range rawHeights {
		if h != nil {
			hasValidValue = true
			break
		}
	}
	if !hasValidValue {
		return heights // all zeros
	}

	// Forward fill: handle nulls at the beginning
	firstValidIdx := -1
	for i, h := range rawHeights {
		if h != nil {
			firstValidIdx = i
			break
		}
	}
	if firstValidIdx > 0 {
		firstValidValue := heights[firstValidIdx]
		for i := 0; i < firstValidIdx; i++ {
			heights[i] = firstValidValue
		}
	}

	// Backward fill: handle nulls at the end
	lastValidIdx := -1
	for i := len(rawHeights) - 1; i >= 0; i-- {
		if rawHeights[i] != nil {
			lastValidIdx = i
			break
		}
	}
	if lastValidIdx < len(rawHeights)-1 {
		lastValidValue := heights[lastValidIdx]
		for i := lastValidIdx + 1; i < len(heights); i++ {
			heights[i] = lastValidValue
		}
	}

	// Linear interpolation for nulls in the middle
	for i := 0; i < len(rawHeights); i++ {
		if rawHeights[i] == nil {
			// Find previous and next valid points
			prevIdx := -1
			nextIdx := -1

			// Find previous valid point
			for j := i - 1; j >= 0; j-- {
				if rawHeights[j] != nil {
					prevIdx = j
					break
				}
			}

			// Find next valid point
			for j := i + 1; j < len(rawHeights); j++ {
				if rawHeights[j] != nil {
					nextIdx = j
					break
				}
			}

			// Interpolate if we have both previous and next valid points
			if prevIdx != -1 && nextIdx != -1 {
				prevValue := heights[prevIdx]
				nextValue := heights[nextIdx]

				// Linear interpolation based on position
				ratio := float64(i-prevIdx) / float64(nextIdx-prevIdx)
				heights[i] = prevValue + ratio*(nextValue-prevValue)
			}
			// If we don't have both prev and next, the forward/backward fill above should have handled it
		}
	}

	return heights
}

// validateStreamAlignment ensures all stream arrays have the correct length and alignment
func validateStreamAlignment(stream *FullResolutionStream, expectedLength int) error {
	if stream == nil {
		return fmt.Errorf("stream is nil")
	}

	if len(stream.TimeS) != expectedLength {
		return fmt.Errorf("timeS array length mismatch: expected %d, got %d", expectedLength, len(stream.TimeS))
	}
	if len(stream.DistanceM) != expectedLength {
		return fmt.Errorf("distanceM array length mismatch: expected %d, got %d", expectedLength, len(stream.DistanceM))
	}
	if len(stream.ElevationM) != expectedLength {
		return fmt.Errorf("elevationM array length mismatch: expected %d, got %d", expectedLength, len(stream.ElevationM))
	}
	if len(stream.SpeedMps) != expectedLength {
		return fmt.Errorf("speedMps array length mismatch: expected %d, got %d", expectedLength, len(stream.SpeedMps))
	}

	// Validate that arrays are properly aligned (first distance should be 0, first time should be 0)
	if expectedLength > 0 {
		if stream.DistanceM[0] != 0 {
			return fmt.Errorf("first distance value should be 0, got %f", stream.DistanceM[0])
		}
		if stream.TimeS[0] != 0 {
			return fmt.Errorf("first time value should be 0, got %f", stream.TimeS[0])
		}
	}

	return nil
}

// createCompressedStreams creates compressed activity streams for medium LOD
func createCompressedStreams(activityID uuid.UUID, keepIndices []int, fullStream *FullResolutionStream) ([]models.ActivityStream, error) {
	if len(keepIndices) == 0 {
		return nil, fmt.Errorf("no indices to keep for medium LOD")
	}

	now := time.Now()

	// Extract decimated arrays
	decimatedTime := make([]float64, len(keepIndices))
	decimatedDistance := make([]float64, len(keepIndices))
	decimatedElevation := make([]float64, len(keepIndices))
	decimatedSpeed := make([]float64, len(keepIndices))

	for i, idx := range keepIndices {
		decimatedTime[i] = fullStream.TimeS[idx]
		decimatedDistance[i] = fullStream.DistanceM[idx]
		decimatedElevation[i] = fullStream.ElevationM[idx]
		decimatedSpeed[i] = fullStream.SpeedMps[idx]
	}

	// Compress each stream using DIBS
	timeBytes, timeCodec := compressDIBS(decimatedTime, 2)
	distanceBytes, distanceCodec := compressDIBS(decimatedDistance, 2)
	elevationBytes, elevationCodec := compressDIBS(decimatedElevation, 2)
	speedBytes, speedCodec := compressDIBS(decimatedSpeed, 3)

	// Create activity stream record
	stream := models.ActivityStream{
		ActivityID:        activityID,
		LOD:               models.StreamLODMedium,
		IndexBy:           models.StreamIndexByDistance,
		NumPoints:         len(keepIndices),
		OriginalNumPoints: len(fullStream.TimeS),
		TimeSBytes:        timeBytes,
		DistanceMBytes:    distanceBytes,
		SpeedMpsBytes:     speedBytes,
		ElevationMBytes:   elevationBytes,
		Codec:             timeCodec, // Using time codec as representative
		CreatedAt:         now,
		UpdatedAt:         now,
	}

	// For now, we store all stream types in one record with their respective compressed bytes
	// In a more advanced implementation, you might want separate records for each stream type
	// with their own codec metadata
	_ = distanceCodec // suppress unused warning
	_ = elevationCodec // suppress unused warning
	_ = speedCodec // suppress unused warning

	return []models.ActivityStream{stream}, nil
}

// Helper function to calculate elapsed time from samples
func calculateElapsedSeconds(samples []Sample) float64 {
	if len(samples) < 2 {
		return 0
	}
	return math.Max(0, float64(samples[len(samples)-1].T-samples[0].T)/1000.0)
}

// Helper function to calculate average speed
func calculateAverageSpeed(distanceMeters, elapsedSeconds float64) float64 {
	if elapsedSeconds > 0 {
		// TODO: this should use moving time in the future
		return distanceMeters / elapsedSeconds // meters per second (SI unit)
	}
	return 0
}

// Helper function to build the Activity model
func buildActivityModel(req CreateActivityRequest, userID string, polyline string, totalDistance float64, bounds Bounds, elevationData *valhalla.ElevationChange, elapsedSeconds, avgSpeedMs float64) *models.Activity {
	now := time.Now()
	startTime := time.Unix(req.Samples[0].T/1000, 0)
	endTime := time.Unix(req.Samples[len(req.Samples)-1].T/1000, 0)

	activity := &models.Activity{
		ID:               uuid.New(),
		UserID:           userID,
		ClientActivityID: req.ClientActivityID,
		Title:            req.Title,
		Description:      req.Description,
		ActivityType:     models.ActivityType(req.ActivityType),
		StartTime:        startTime,
		EndTime:          &endTime,
		ElapsedTime:      int(elapsedSeconds),
		DistanceM:        totalDistance,
		AvgSpeedMps:      &avgSpeedMs,
		ProcessingVer:    1,
		Polyline:         &polyline,
		CreatedAt:        now,
		UpdatedAt:        now,

		// Set bounding box coordinates
		BBoxMinLat: &bounds.MinLat,
		BBoxMinLon: &bounds.MinLon,
		BBoxMaxLat: &bounds.MaxLat,
		BBoxMaxLon: &bounds.MaxLon,

		// Set start/end coordinates
		StartLat: &req.Samples[0].Lat,
		StartLon: &req.Samples[0].Lon,
		EndLat:   &req.Samples[len(req.Samples)-1].Lat,
		EndLon:   &req.Samples[len(req.Samples)-1].Lon,
	}

	// Set elevation data if available
	if elevationData != nil {
		activity.ElevationGainM = &elevationData.GainMeters
		activity.ElevationLossM = &elevationData.LossMeters
		activity.MaxHeightM = &elevationData.MaxHeight
		activity.MinHeightM = &elevationData.MinHeight
	}

	return activity
}

// Helper function to create and store FIT file
func createAndStoreFITFile(ctx context.Context, activity *models.Activity, samples []Sample, objectStore store.ObjectStore, log logger.ServiceLogger) error {
	objectKey := fmt.Sprintf("activities/%s/%s.fit", activity.UserID, activity.ID.String())

	if err := createFITFile(ctx, activity, samples, objectStore, log); err != nil {
		return err
	}

	// Set the file URL
	activity.FileURL = &objectKey
	return nil
}

// createActivityResult creates an ActivityResult from the Activity model only
// This function should be used in both HTTP handlers to reduce duplication
func createActivityResult(activity *models.Activity) ActivityResult {
	// Calculate elapsed seconds from the activity timestamps
	elapsedSeconds := float64(activity.ElapsedTime)

	// Calculate average speed from stored data
	avgSpeedMs := floatOrDefault(activity.AvgSpeedMps, 0.0)

	return ActivityResult{
		ID:            activity.ID.String(),
		Title:         activity.Title,
		Description:   stringOrDefault(activity.Description, ""),
		Type:          string(activity.ActivityType),
		StartTime:     activity.StartTime,
		EndTime:       activity.EndTime,
		ProcessingVer: activity.ProcessingVer,
		Stats: ActivityStats{
			ElapsedSeconds: elapsedSeconds,
			AvgSpeedMs:     avgSpeedMs,
			ElevationGainM: floatOrDefault(activity.ElevationGainM, 0),
			ElevationLossM: floatOrDefault(activity.ElevationLossM, 0),
			MaxHeightM:     floatOrDefault(activity.MaxHeightM, 0),
			MinHeightM:     floatOrDefault(activity.MinHeightM, 0),
			DistanceM:      activity.DistanceM,
			Derived:        calculateDerivedStats(string(activity.ActivityType), avgSpeedMs, activity.DistanceM),
		},
		BBox: BoundingBox{
			MinLat: floatOrDefault(activity.BBoxMinLat, 0),
			MaxLat: floatOrDefault(activity.BBoxMaxLat, 0),
			MinLon: floatOrDefault(activity.BBoxMinLon, 0),
			MaxLon: floatOrDefault(activity.BBoxMaxLon, 0),
		},
		Start: Coordinate{
			Lat: floatOrDefault(activity.StartLat, 0),
			Lon: floatOrDefault(activity.StartLon, 0),
		},
		End: Coordinate{
			Lat: floatOrDefault(activity.EndLat, 0),
			Lon: floatOrDefault(activity.EndLon, 0),
		},
		Polyline:  stringOrDefault(activity.Polyline, ""),
		CreatedAt: activity.CreatedAt,
		UpdatedAt: activity.UpdatedAt,
	}
}

func HandleGetActivities(database db.Database, log logger.ServiceLogger) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := context.Background()

		// Get authenticated user ID using the same helper function
		userID, err := getAuthenticatedUserID(ctx, r, database, log)
		if err != nil {
			http.Error(w, err.Error(), http.StatusUnauthorized)
			return
		}

		// Get user's activities from database
		activities, err := database.GetActivitiesByUserID(ctx, userID)
		if err != nil {
			log.Error("Failed to get activities from database", err)
			http.Error(w, "Failed to retrieve activities", http.StatusInternalServerError)
			return
		}

		// Transform activities to the response format using the unified helper function
		// Initialize as empty slice to ensure we always return [] instead of null
		results := make([]ActivityResult, 0, len(activities))
		for _, activity := range activities {
			result := createActivityResult(&activity)
			results = append(results, result)
		}

		response := GetActivitiesResponse{
			Activities: results,
		}

		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(response)
	}
}

// createFITFile generates a FIT file from activity data and saves it to object store
func createFITFile(ctx context.Context, activity *models.Activity, samples []Sample, objectStore store.ObjectStore, log logger.ServiceLogger) error {
	// Create FIT activity file using muktihari/fit library
	fitActivity := filedef.NewActivity()

	// Set file ID information
	fitActivity.FileId = *mesgdef.NewFileId(nil).
		SetType(typedef.FileActivity).
		SetTimeCreated(activity.StartTime).
		SetManufacturer(typedef.ManufacturerDevelopment). // Use development manufacturer
		SetProduct(uint16(1)).                            // TODO: product ID, for now set 1
		SetProductName("Cadent")

	// Convert samples to FIT records
	if len(samples) > 0 {
		startTime := time.UnixMilli(samples[0].T)

		for i, sample := range samples {
			timestamp := time.UnixMilli(sample.T)

			record := mesgdef.NewRecord(nil).
				SetTimestamp(timestamp).
				SetPositionLat(int32(sample.Lat * 11930465)). // Convert to semicircles
				SetPositionLong(int32(sample.Lon * 11930465)) // Convert to semicircles

			// Add distance and speed if we can calculate it
			if i > 0 {
				prevSample := samples[i-1]
				distance := haversineDistance(prevSample.Lat, prevSample.Lon, sample.Lat, sample.Lon)
				timeElapsed := float64(sample.T-prevSample.T) / 1000.0 // Convert to seconds

				if timeElapsed > 0 {
					speed := distance / timeElapsed       // m/s
					record.SetSpeed(uint16(speed * 1000)) // Convert to mm/s for FIT format
				}
			}

			fitActivity.Records = append(fitActivity.Records, record)
		}

		// Create session summary
		endTime := time.UnixMilli(samples[len(samples)-1].T)
		totalTime := endTime.Sub(startTime)

		session := mesgdef.NewSession(nil).
			SetTimestamp(endTime).
			SetStartTime(startTime).
			SetTotalElapsedTime(uint32(totalTime.Seconds() * 1000)). // milliseconds
			SetSport(typedef.SportRunning).                          // Default to running
			SetSubSport(typedef.SubSportGeneric)

		if activity.DistanceM > 0 {
			session.SetTotalDistance(uint32(activity.DistanceM * 100)) // Convert to cm
		}
		if activity.AvgSpeedMps != nil && *activity.AvgSpeedMps > 0 {
			session.SetAvgSpeed(uint16(*activity.AvgSpeedMps * 1000)) // Convert to mm/s
		}

		fitActivity.Sessions = append(fitActivity.Sessions, session)

		// Create activity summary
		fitActivity.Activity = mesgdef.NewActivity(nil).
			SetTimestamp(endTime).
			SetType(typedef.ActivityManual).
			SetNumSessions(1)
	}

	// Convert to FIT protocol messages
	fit := fitActivity.ToFIT(nil)

	// Create a buffer to encode FIT data
	var buf strings.Builder
	enc := encoder.New(&buf)
	if err := enc.Encode(&fit); err != nil {
		log.Error("Failed to encode FIT file", err)
		return fmt.Errorf("failed to encode FIT file: %w", err)
	}

	// Create object key: activities/{user_id}/{activity_id}.fit
	objectKey := fmt.Sprintf("activities/%s/%s.fit", activity.UserID, activity.ID.String())

	// Store the FIT file in object store
	reader := strings.NewReader(buf.String())
	size := int64(buf.Len())

	if err := objectStore.PutObject(ctx, objectKey, reader, size); err != nil {
		log.Error("Failed to store FIT file", err)
		return fmt.Errorf("failed to store FIT file: %w", err)
	}

	log.Debug(fmt.Sprintf("FIT file created for activity %s", activity.ID.String()))
	return nil
}

// haversineDistance calculates the distance between two points on Earth using the Haversine formula
func haversineDistance(lat1, lon1, lat2, lon2 float64) float64 {
	const R = 6371000 // Earth's radius in meters

	// Convert degrees to radians
	lat1Rad := lat1 * math.Pi / 180
	lon1Rad := lon1 * math.Pi / 180
	lat2Rad := lat2 * math.Pi / 180
	lon2Rad := lon2 * math.Pi / 180

	// Differences
	deltaLat := lat2Rad - lat1Rad
	deltaLon := lon2Rad - lon1Rad

	// Haversine formula
	a := math.Sin(deltaLat/2)*math.Sin(deltaLat/2) +
		math.Cos(lat1Rad)*math.Cos(lat2Rad)*math.Sin(deltaLon/2)*math.Sin(deltaLon/2)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))

	return R * c // Distance in meters
}

// calculateDerivedStats calculates derived statistics based on activity type and speed
func calculateDerivedStats(activityType string, speedMs float64, distanceM float64) DerivedStats {
	derived := DerivedStats{
		DistanceKm:    distanceM / 1000.0,
		DistanceMiles: distanceM / 1609.344, // 1 mile = 1609.344 meters
	}

	if speedMs > 0 {
		switch activityType {
		case "road_bike":
			// For bike activities, show speed in km/h and mph
			speedKmh := speedMs * 3.6      // m/s to km/h
			speedMph := speedMs * 2.236936 // m/s to mph
			derived.SpeedKmh = &speedKmh
			derived.SpeedMph = &speedMph
		case "run":
			// For running activities, show pace in seconds per km and per mile
			paceSPerKm := 1000.0 / speedMs     // seconds per km
			paceSPerMile := 1609.344 / speedMs // seconds per mile
			derived.PaceSPerKm = &paceSPerKm
			derived.PaceSPerMile = &paceSPerMile
		}
	}

	return derived
}

// processFullResolutionStreams converts samples and elevation data into full-resolution stream arrays
func processFullResolutionStreams(samples []Sample, elevationData *valhalla.ElevationChange, elevationHeights []float64) *FullResolutionStream {
	if len(samples) == 0 {
		return &FullResolutionStream{}
	}

	n := len(samples)
	stream := &FullResolutionStream{
		TimeS:      make([]float64, n),
		DistanceM:  make([]float64, n),
		ElevationM: make([]float64, n),
		SpeedMps:   make([]float64, n),
	}

	// Start time for calculating seconds since start
	startTimeMs := samples[0].T

	// First pass: calculate time_s, distance_m, and elevation_m
	var cumulativeDistance float64
	for i, sample := range samples {
		// Time in seconds since start
		stream.TimeS[i] = float64(sample.T-startTimeMs) / 1000.0

		// Cumulative distance
		if i == 0 {
			stream.DistanceM[i] = 0
		} else {
			prev := samples[i-1]
			segmentDistance := haversineDistance(prev.Lat, prev.Lon, sample.Lat, sample.Lon)
			cumulativeDistance += segmentDistance
			stream.DistanceM[i] = cumulativeDistance
		}

		// Elevation (use provided elevation heights if available)
		if elevationHeights != nil && i < len(elevationHeights) {
			stream.ElevationM[i] = elevationHeights[i]
		} else {
			stream.ElevationM[i] = 0 // Default elevation if no data available
		}
	}

	// Second pass: calculate speed_mps
	for i := range samples {
		if i == 0 {
			// First point: use speed from next segment if available
			if len(samples) > 1 {
				timeDiff := stream.TimeS[1] - stream.TimeS[0]
				distDiff := stream.DistanceM[1] - stream.DistanceM[0]
				if timeDiff > 0 {
					stream.SpeedMps[i] = distDiff / timeDiff
				}
			}
		} else {
			// Calculate speed from previous segment
			timeDiff := stream.TimeS[i] - stream.TimeS[i-1]
			distDiff := stream.DistanceM[i] - stream.DistanceM[i-1]
			if timeDiff > 0 {
				stream.SpeedMps[i] = distDiff / timeDiff
			}
		}
	}

	return stream
}

// decimateByDistance performs Strava-style distance-uniform decimation to create medium LOD
// Targets around MediumLODTargetPoints points by selecting points evenly spaced in distance
func decimateByDistance(fullStream *FullResolutionStream, targetPoints int) []int {
	if len(fullStream.DistanceM) <= targetPoints {
		// If we already have fewer than target points, keep all
		indices := make([]int, len(fullStream.DistanceM))
		for i := range indices {
			indices[i] = i
		}
		return indices
	}

	totalDistance := fullStream.DistanceM[len(fullStream.DistanceM)-1]
	if totalDistance <= 0 {
		// If no distance, just return first and last points
		return []int{0, len(fullStream.DistanceM) - 1}
	}

	// Calculate step size in meters
	stepSize := totalDistance / float64(targetPoints-1) // -1 because we include both endpoints

	keepIndices := make([]int, 0, targetPoints)
	keepIndices = append(keepIndices, 0) // Always keep first point

	currentIndex := 0
	for step := 1; step < targetPoints-1; step++ {
		targetDistance := float64(step) * stepSize

		// Find the closest point to target distance
		// Walk forward from current index to ensure indices always move forward
		bestIndex := currentIndex
		bestDiff := math.Abs(fullStream.DistanceM[currentIndex] - targetDistance)

		for i := currentIndex; i < len(fullStream.DistanceM); i++ {
			diff := math.Abs(fullStream.DistanceM[i] - targetDistance)
			if diff < bestDiff {
				bestDiff = diff
				bestIndex = i
			} else if diff > bestDiff {
				// We've passed the optimal point, stop searching
				break
			}
		}

		// Only add if it's different from the last kept index
		if bestIndex > keepIndices[len(keepIndices)-1] {
			keepIndices = append(keepIndices, bestIndex)
			currentIndex = bestIndex
		}
	}

	// Always keep last point
	lastIndex := len(fullStream.DistanceM) - 1
	if len(keepIndices) == 0 || keepIndices[len(keepIndices)-1] != lastIndex {
		keepIndices = append(keepIndices, lastIndex)
	}

	return keepIndices
}

// DIBS compression functions - using the dedicated compression package

// compressDIBS compresses a float64 array using the DIBS algorithm
func compressDIBS(data []float64, decimalPlaces int) ([]byte, map[string]interface{}) {
	opts := compression.CompressOptions{
		DecimalPlaces: decimalPlaces,
		BlockLog2:     8, // 256 samples per block
		EnableCRC:     false, // Disable CRC for embedded use to save space
	}

	compressed, err := compression.Compress(data, opts)
	if err != nil {
		// Fall back to placeholder on error
		codec := map[string]interface{}{
			"name":       "dibs",
			"version":    1,
			"float":      decimalPlaces,
			"endianness": "le",
			"error":      err.Error(),
		}
		return []byte{}, codec
	}

	// Create codec metadata
	codec := map[string]interface{}{
		"name":       "dibs",
		"version":    1,
		"float":      decimalPlaces,
		"endianness": "le",
		"block_log2": opts.BlockLog2,
	}

	return compressed, codec
}

// decompressDIBS decompresses DIBS-compressed data back to float64 array
func decompressDIBS(compressed []byte, codec map[string]interface{}) ([]float64, error) {
	// Check if there was an error during compression
	if errMsg, exists := codec["error"]; exists {
		return nil, fmt.Errorf("compression error: %v", errMsg)
	}

	return compression.Decompress(compressed)
}
