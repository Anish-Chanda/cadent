package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"net/http"
	"time"

	"github.com/anish-chanda/cadence/backend/internal/db"
	"github.com/anish-chanda/cadence/backend/internal/logger"
	"github.com/anish-chanda/cadence/backend/internal/models"
	"github.com/anish-chanda/cadence/backend/internal/valhalla"
	"github.com/go-pkgz/auth/v2/token"
	"github.com/google/uuid"
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

type ActivityResult struct {
	valhalla.Result
	ElapsedSeconds float64 `json:"elapsed_seconds"`
	AvgSpeedMs     float64 `json:"avg_speed_ms"`  // meters per second (SI unit)
	AvgSpeedKmh    float64 `json:"avg_speed_kmh"` // kilometers per hour (for convenience)
}

func HandleCreateActivity(database db.Database, valhallaClient *valhalla.Client, log logger.ServiceLogger) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := context.Background()

		var req CreateActivityRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			log.Error("Failed to decode request", err)
			http.Error(w, "Invalid request body", http.StatusBadRequest)
			return
		}
		if len(req.Samples) < 2 {
			http.Error(w, "Not Enough Samples", http.StatusBadRequest)
			return
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

		// Get authenticated user information using go-pkgz/auth token package
		user, err := token.GetUserInfo(r)
		if err != nil {
			log.Error("Failed to get user info from token", err)
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}

		// The go-pkgz/auth package generates its own user IDs, but we need to map to our database user ID
		// Extract email from the token (stored as "Name" field by go-pkgz/auth local provider)
		userEmail := user.Name
		if userEmail == "" {
			log.Error("No email found in user token", nil)
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}

		// Look up the actual database user ID using the email
		dbUser, err := database.GetUserByEmail(ctx, userEmail)
		if err != nil {
			log.Error("Failed to get user from database", err)
			http.Error(w, "Internal server error", http.StatusInternalServerError)
			return
		}
		if dbUser == nil {
			log.Error("User not found in database", nil)
			http.Error(w, "User not found", http.StatusNotFound)
			return
		}

		userID := dbUser.ID
		log.Info(fmt.Sprintf("Processing activity for user: %s (%s)", userID, userEmail))

		// Convert ms to seconds
		beginTimeS := req.Samples[0].T / 1000

		// Build shape with per-point time (seconds)
		points := make([]valhalla.GPSPoint, 0, len(req.Samples))
		for _, s := range req.Samples {
			sec := s.T / 1000
			t := sec
			points = append(points, valhalla.GPSPoint{
				Lat:  s.Lat,
				Lon:  s.Lon,
				Time: &t,
			})
		}

		// Durations array (seconds, non-negative)
		durations := make([]int, 0, len(req.Samples)-1)
		for i := 0; i+1 < len(req.Samples); i++ {
			d := (req.Samples[i+1].T - req.Samples[i].T) / 1000
			if d < 0 {
				d = 0
			}
			durations = append(durations, int(d))
		}

		useTS := true
		sm := valhalla.ShapeMatchMapSnap

		traceReq := valhalla.TraceRouteRequest{
			Shape:         points,
			ShapeMatch:    &sm,
			Costing:       valhalla.CostingBicycle,
			BeginTime:     &beginTimeS,
			Durations:     durations,
			UseTimestamps: &useTS,
		}

		resp, err := valhallaClient.TraceRoute(ctx, traceReq)
		if err != nil {
			http.Error(w, "Failed to process GPS data", http.StatusInternalServerError)
			return
		}

		baseResult := valhalla.ProcessTraceResponse(resp)

		// Get elevation data using the polyline
		heightReq := valhalla.HeightRequest{
			Range:           true,
			EncodedPolyline: baseResult.Polyline,
		}

		heightResp, err := valhallaClient.GetHeight(ctx, heightReq)
		if err != nil {
			// Log error but don't fail the request - elevation is optional
			// In production, you might want to use proper logging here
			heightResp = nil
		}

		// Calculate elevation gain
		var elevationGain *float64
		if heightResp != nil {
			gain := valhalla.CalculateElevationGain(heightResp)
			if gain > 0 {
				elevationGain = &gain
			}
		}

		// Update base result with elevation gain
		baseResult.ElevationGainM = elevationGain

		// Elapsed seconds from device timestamps (ms -> s)
		elapsedSeconds := math.Max(0, float64(req.Samples[len(req.Samples)-1].T-req.Samples[0].T)/1000.0)

		// Calculate average speeds
		var avgSpeedMs, avgSpeedKmh float64
		if elapsedSeconds > 0 {
			avgSpeedMs = baseResult.DistanceMeters / elapsedSeconds // meters per second (SI unit)
			avgSpeedKmh = avgSpeedMs * 3.6                          // convert m/s to km/h
		}

		// Create activity model for database
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
			DistanceM:        baseResult.DistanceMeters,
			ElevationGainM:   elevationGain,
			AvgSpeedMps:      &avgSpeedMs,
			ProcessingVer:    1,
			Polyline:         &baseResult.Polyline,
			CreatedAt:        now,
			UpdatedAt:        now,
		}

		// Set bounding box coordinates
		if bbox := baseResult.BBox; bbox != nil {
			if minLat, ok := bbox["min_lat"]; ok {
				activity.BBoxMinLat = &minLat
			}
			if minLon, ok := bbox["min_lon"]; ok {
				activity.BBoxMinLon = &minLon
			}
			if maxLat, ok := bbox["max_lat"]; ok {
				activity.BBoxMaxLat = &maxLat
			}
			if maxLon, ok := bbox["max_lon"]; ok {
				activity.BBoxMaxLon = &maxLon
			}
		}

		// Set start/end coordinates
		if start := baseResult.Start; start != nil {
			if lat, ok := start["lat"]; ok {
				activity.StartLat = &lat
			}
			if lon, ok := start["lon"]; ok {
				activity.StartLon = &lon
			}
		}
		if end := baseResult.End; end != nil {
			if lat, ok := end["lat"]; ok {
				activity.EndLat = &lat
			}
			if lon, ok := end["lon"]; ok {
				activity.EndLon = &lon
			}
		}

		// Set Valhalla metadata
		activity.NumLegs = &baseResult.NumLegs
		activity.NumAlternates = &baseResult.NumAlternates
		activity.NumPointsPoly = &baseResult.NumPointsPoly
		activity.ValDurationSeconds = &baseResult.ValDurationSeconds

		// Save to database
		if err := database.CreateActivity(ctx, activity); err != nil {
			log.Error("Failed to save activity to database", err)
			http.Error(w, "Failed to save activity", http.StatusInternalServerError)
			return
		}

		log.Info(fmt.Sprintf("Successfully created activity %s for user %s", activity.ID, userID))

		// Return the processing result (not the full database model)
		result := ActivityResult{
			Result:         baseResult,
			ElapsedSeconds: elapsedSeconds,
			AvgSpeedMs:     avgSpeedMs,
			AvgSpeedKmh:    avgSpeedKmh,
		}

		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(result)
	}
}

func HandleGetActivities(database db.Database, log logger.ServiceLogger) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := context.Background()

		// Get authenticated user information using go-pkgz/auth token package
		user, err := token.GetUserInfo(r)
		if err != nil {
			log.Error("Failed to get user info from token", err)
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}

		// The go-pkgz/auth package generates its own user IDs, but we need to map to our database user ID
		// Extract email from the token (stored as "Name" field by go-pkgz/auth local provider)
		userEmail := user.Name
		if userEmail == "" {
			log.Error("No email found in user token", nil)
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}

		// Look up the actual database user ID using the email
		dbUser, err := database.GetUserByEmail(ctx, userEmail)
		if err != nil {
			log.Error("Failed to get user from database", err)
			http.Error(w, "Internal server error", http.StatusInternalServerError)
			return
		}
		if dbUser == nil {
			log.Error("User not found in database", nil)
			http.Error(w, "User not found", http.StatusNotFound)
			return
		}

		userID := dbUser.ID

		// Get user's activities from database
		activities, err := database.GetActivitiesByUserID(ctx, userID)
		if err != nil {
			log.Error("Failed to get activities from database", err)
			http.Error(w, "Failed to retrieve activities", http.StatusInternalServerError)
			return
		}

		log.Info(fmt.Sprintf("Retrieved %d activities for user %s", len(activities), userID))

		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(activities)
	}
}

func intPtr(v int) *int { return &v }
