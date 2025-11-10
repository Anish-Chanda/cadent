package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"net/http"
	"strings"
	"time"

	"github.com/anish-chanda/cadence/backend/internal/db"
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

type ActivityStats struct {
	ElapsedSeconds float64      `json:"elapsed_seconds"`
	AvgSpeedMs     float64      `json:"avg_speed_ms"`     // meters per second (SI unit)
	ElevationGainM float64      `json:"elevation_gain_m"` // elevation gain in meters
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
		// Extract email from the token (stored as "Name" field by go-pkgz/authfor  local provider)
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
		log.Debug(fmt.Sprintf("Processing activity for user: %s (%s)", userID, userEmail))

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
		var avgSpeedMs float64
		if elapsedSeconds > 0 {
			avgSpeedMs = baseResult.DistanceMeters / elapsedSeconds // meters per second (SI unit)
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

		// Create and store FIT file, get the object key
		objectKey := fmt.Sprintf("activities/%s/%s.fit", activity.UserID, activity.ID.String())
		if err := createFITFile(ctx, activity, req.Samples, objectStore, log); err != nil {
			log.Error("Failed to create FIT file", err)
			http.Error(w, "Failed to create FIT file", http.StatusInternalServerError)
			return
		}

		// Set the file URL
		activity.FileURL = &objectKey

		// Save to database
		if err := database.CreateActivity(ctx, activity); err != nil {
			log.Error("Failed to save activity to database", err)
			http.Error(w, "Failed to save activity", http.StatusInternalServerError)
			return
		}

		// Return the processing result (not the full database model)
		result := ActivityResult{
			ID:    activity.ID.String(),
			Title: activity.Title,
			Description: func() string {
				if activity.Description != nil {
					return *activity.Description
				}
				return ""
			}(),
			Type:          string(activity.ActivityType),
			StartTime:     activity.StartTime,
			EndTime:       activity.EndTime,
			ProcessingVer: activity.ProcessingVer,
			Stats: ActivityStats{
				ElapsedSeconds: elapsedSeconds,
				AvgSpeedMs:     avgSpeedMs,
				ElevationGainM: func() float64 {
					if elevationGain != nil {
						return *elevationGain
					}
					return 0
				}(),
				DistanceM: baseResult.DistanceMeters,
				Derived:   calculateDerivedStats(req.ActivityType, avgSpeedMs, baseResult.DistanceMeters),
			},
			BBox: BoundingBox{
				MinLat: func() float64 {
					if bbox := baseResult.BBox; bbox != nil {
						if val, ok := bbox["min_lat"]; ok {
							return val
						}
					}
					return 0
				}(),
				MaxLat: func() float64 {
					if bbox := baseResult.BBox; bbox != nil {
						if val, ok := bbox["max_lat"]; ok {
							return val
						}
					}
					return 0
				}(),
				MinLon: func() float64 {
					if bbox := baseResult.BBox; bbox != nil {
						if val, ok := bbox["min_lon"]; ok {
							return val
						}
					}
					return 0
				}(),
				MaxLon: func() float64 {
					if bbox := baseResult.BBox; bbox != nil {
						if val, ok := bbox["max_lon"]; ok {
							return val
						}
					}
					return 0
				}(),
			},
			Start: Coordinate{
				Lat: func() float64 {
					if start := baseResult.Start; start != nil {
						if val, ok := start["lat"]; ok {
							return val
						}
					}
					return 0
				}(),
				Lon: func() float64 {
					if start := baseResult.Start; start != nil {
						if val, ok := start["lon"]; ok {
							return val
						}
					}
					return 0
				}(),
			},
			End: Coordinate{
				Lat: func() float64 {
					if end := baseResult.End; end != nil {
						if val, ok := end["lat"]; ok {
							return val
						}
					}
					return 0
				}(),
				Lon: func() float64 {
					if end := baseResult.End; end != nil {
						if val, ok := end["lon"]; ok {
							return val
						}
					}
					return 0
				}(),
			},
			Polyline:  baseResult.Polyline,
			CreatedAt: activity.CreatedAt,
			UpdatedAt: activity.UpdatedAt,
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

		// Transform activities to the response format
		// Initialize as empty slice to ensure we always return [] instead of null
		results := make([]ActivityResult, 0, len(activities))
		for _, activity := range activities {
			avgSpeedMs := func() float64 {
				if activity.AvgSpeedMps != nil {
					return *activity.AvgSpeedMps
				}
				return 0.0
			}()

			result := ActivityResult{
				ID:    activity.ID.String(),
				Title: activity.Title,
				Description: func() string {
					if activity.Description != nil {
						return *activity.Description
					}
					return ""
				}(),
				Type:          string(activity.ActivityType),
				StartTime:     activity.StartTime,
				EndTime:       activity.EndTime,
				ProcessingVer: activity.ProcessingVer,
				Stats: ActivityStats{
					ElapsedSeconds: float64(activity.ElapsedTime),
					AvgSpeedMs:     avgSpeedMs,
					ElevationGainM: func() float64 {
						if activity.ElevationGainM != nil {
							return *activity.ElevationGainM
						}
						return 0.0
					}(),
					DistanceM: activity.DistanceM,
					Derived:   calculateDerivedStats(string(activity.ActivityType), avgSpeedMs, activity.DistanceM),
				},
				BBox: BoundingBox{
					MinLat: func() float64 {
						if activity.BBoxMinLat != nil {
							return *activity.BBoxMinLat
						}
						return 0.0
					}(),
					MaxLat: func() float64 {
						if activity.BBoxMaxLat != nil {
							return *activity.BBoxMaxLat
						}
						return 0.0
					}(),
					MinLon: func() float64 {
						if activity.BBoxMinLon != nil {
							return *activity.BBoxMinLon
						}
						return 0.0
					}(),
					MaxLon: func() float64 {
						if activity.BBoxMaxLon != nil {
							return *activity.BBoxMaxLon
						}
						return 0.0
					}(),
				},
				Start: Coordinate{
					Lat: func() float64 {
						if activity.StartLat != nil {
							return *activity.StartLat
						}
						return 0.0
					}(),
					Lon: func() float64 {
						if activity.StartLon != nil {
							return *activity.StartLon
						}
						return 0.0
					}(),
				},
				End: Coordinate{
					Lat: func() float64 {
						if activity.EndLat != nil {
							return *activity.EndLat
						}
						return 0.0
					}(),
					Lon: func() float64 {
						if activity.EndLon != nil {
							return *activity.EndLon
						}
						return 0.0
					}(),
				},
				Polyline: func() string {
					if activity.Polyline != nil {
						return *activity.Polyline
					}
					return ""
				}(),
				CreatedAt: activity.CreatedAt,
				UpdatedAt: activity.UpdatedAt,
			}
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
