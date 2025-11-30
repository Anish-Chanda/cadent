package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"

	"github.com/anish-chanda/cadence/backend/internal/compression"
	"github.com/anish-chanda/cadence/backend/internal/db"
	"github.com/anish-chanda/cadence/backend/internal/logger"
	"github.com/anish-chanda/cadence/backend/internal/models"
	"github.com/go-chi/chi/v5"
)

// Stream processing constants
const (
	LowLODTargetPoints = 150 // Target number of points for low LOD streams
)

// StreamsRequest represents the query parameters for requesting activity streams
type StreamsRequest struct {
	LOD   models.StreamLOD    `json:"lod"`   // Level of detail: medium, low, or full
	Types []models.StreamType `json:"types"` // Types: time, distance, elevation, speed
}

// StreamData represents decompressed stream data for a specific type
type StreamData struct {
	Type   models.StreamType `json:"type"`
	Values []float64         `json:"values"`
}

// StreamsResponse represents the response containing requested stream data
type StreamsResponse struct {
	ActivityID        string               `json:"activity_id"`
	LOD               models.StreamLOD     `json:"lod"`
	IndexBy           models.StreamIndexBy `json:"index_by"`
	NumPoints         int                  `json:"num_points"`
	OriginalNumPoints int                  `json:"original_num_points"`
	Streams           []StreamData         `json:"streams"`
}

// HandleGetActivityStreams handles GET /v1/activities/{id}/streams
func HandleGetActivityStreams(database db.Database, log logger.ServiceLogger) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := context.Background()

		// Get activity ID from URL path
		activityID := chi.URLParam(r, "id")
		if activityID == "" {
			log.Error("Missing activity ID in URL path", nil)
			http.Error(w, "Activity ID is required", http.StatusBadRequest)
			return
		}

		// Parse query parameters
		req, err := parseStreamRequest(r)
		if err != nil {
			log.Error("Failed to parse stream request", err)
			http.Error(w, fmt.Sprintf("Invalid request parameters: %v", err), http.StatusBadRequest)
			return
		}

		// Get authenticated user ID
		userID, err := getAuthenticatedUserID(ctx, r, database, log)
		if err != nil {
			http.Error(w, err.Error(), http.StatusUnauthorized)
			return
		}

		// Get activity to check ownership
		activity, err := database.GetActivityByID(ctx, activityID)
		if err != nil {
			log.Error("Failed to get activity from database", err)
			http.Error(w, "Internal server error", http.StatusInternalServerError)
			return
		}
		if activity == nil {
			log.Info(fmt.Sprintf("Activity not found: %s", activityID))
			http.Error(w, "Activity not found", http.StatusNotFound)
			return
		}

		// Check if the authenticated user owns this activity
		if activity.UserID != userID {
			log.Debug(fmt.Sprintf("User %s attempted to access activity %s owned by %s", userID, activityID, activity.UserID))
			http.Error(w, "Activity not found", http.StatusNotFound) // Return 404 instead of 403
			return
		}

		log.Debug(fmt.Sprintf("User %s requesting streams for activity %s with LOD %s and types %v", userID, activityID, req.LOD, req.Types))

		// Get activity streams from database based on LOD
		var responseStreams []StreamData
		var numPoints, originalNumPoints int

		switch req.LOD {
		case models.StreamLODMedium:
			// Get medium LOD from database
			responseStreams, numPoints, originalNumPoints, err = getMediumLODStreams(ctx, database, activityID, req.Types, log)
			if err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}

		case models.StreamLODLow:
			// Calculate low LOD on the fly from medium LOD
			responseStreams, numPoints, originalNumPoints, err = getLowLODStreams(ctx, database, activityID, req.Types, log)
			if err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}

		case models.StreamLODFull:
			// TODO: Get full resolution from FIT file in object storage
			log.Error("Full LOD streams not yet implemented - requires FIT file parsing", nil)
			http.Error(w, "Full resolution streams not available", http.StatusNotImplemented)
			return

		default:
			http.Error(w, fmt.Sprintf("Unsupported LOD: %s", req.LOD), http.StatusBadRequest)
			return
		}

		if len(responseStreams) == 0 {
			log.Info(fmt.Sprintf("No stream data found for activity %s with LOD %s", activityID, req.LOD))
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
			log.Error("Failed to encode response", err)
			http.Error(w, "Internal server error", http.StatusInternalServerError)
			return
		}

		log.Debug(fmt.Sprintf("Successfully returned %d stream types for activity %s with LOD %s", len(responseStreams), activityID, req.LOD))
	}
}

// getMediumLODStreams retrieves medium LOD streams from database
func getMediumLODStreams(ctx context.Context, database db.Database, activityID string, requestedTypes []models.StreamType, log logger.ServiceLogger) ([]StreamData, int, int, error) {
	activityStreams, err := database.GetActivityStreams(ctx, activityID, models.StreamLODMedium)
	if err != nil {
		log.Error("Failed to get activity streams from database", err)
		return nil, 0, 0, fmt.Errorf("internal server error")
	}

	if len(activityStreams) == 0 {
		return nil, 0, 0, fmt.Errorf("no medium LOD streams found")
	}

	// For now, we assume a single activity stream record contains all stream types
	// TODO: we will change this to streams stored per row later
	activityStream := activityStreams[0]
	responseStreams := make([]StreamData, 0, len(requestedTypes))

	// Decompress requested stream types
	for _, streamType := range requestedTypes {
		var compressedData []byte

		switch streamType {
		case models.StreamTypeTime:
			compressedData = activityStream.TimeSBytes
		case models.StreamTypeDistance:
			compressedData = activityStream.DistanceMBytes
		case models.StreamTypeElevation:
			compressedData = activityStream.ElevationMBytes
		case models.StreamTypeSpeed:
			compressedData = activityStream.SpeedMpsBytes
		default:
			log.Error(fmt.Sprintf("Unknown stream type: %s", streamType), nil)
			continue
		}

		if len(compressedData) == 0 {
			log.Info(fmt.Sprintf("No compressed data for stream type %s", streamType))
			continue
		}

		// Decompress using DIBS
		decompressed, err := compression.Decompress(compressedData)
		if err != nil {
			log.Error(fmt.Sprintf("Failed to decompress %s stream", streamType), err)
			return nil, 0, 0, fmt.Errorf("failed to decompress %s stream data", streamType)
		}

		responseStreams = append(responseStreams, StreamData{
			Type:   streamType,
			Values: decompressed,
		})
	}

	return responseStreams, activityStream.NumPoints, activityStream.OriginalNumPoints, nil
}

// getLowLODStreams calculates low LOD streams by further decimating medium LOD data
func getLowLODStreams(ctx context.Context, database db.Database, activityID string, requestedTypes []models.StreamType, log logger.ServiceLogger) ([]StreamData, int, int, error) {
	// First get medium LOD streams
	mediumStreams, _, originalNumPoints, err := getMediumLODStreams(ctx, database, activityID, requestedTypes, log)
	if err != nil {
		return nil, 0, 0, err
	}

	if len(mediumStreams) == 0 {
		return nil, 0, 0, fmt.Errorf("no medium LOD data to downsample")
	}

	// Decimate medium LOD to create low LOD (~100-200 points)
	targetLowPoints := LowLODTargetPoints
	responseStreams := make([]StreamData, 0, len(mediumStreams))

	for _, stream := range mediumStreams {
		if len(stream.Values) <= targetLowPoints {
			// Already small enough
			responseStreams = append(responseStreams, stream)
		} else {
			// Simple decimation: take every nth point
			step := len(stream.Values) / targetLowPoints
			if step < 1 {
				step = 1
			}

			decimated := make([]float64, 0, targetLowPoints)
			for i := 0; i < len(stream.Values); i += step {
				decimated = append(decimated, stream.Values[i])
			}

			// Always include the last point
			if len(decimated) > 0 && decimated[len(decimated)-1] != stream.Values[len(stream.Values)-1] {
				decimated = append(decimated, stream.Values[len(stream.Values)-1])
			}

			responseStreams = append(responseStreams, StreamData{
				Type:   stream.Type,
				Values: decimated,
			})
		}
	}

	// Calculate the actual number of points in the decimated data
	actualPoints := 0
	if len(responseStreams) > 0 {
		actualPoints = len(responseStreams[0].Values)
	}

	return responseStreams, actualPoints, originalNumPoints, nil
}

// parseStreamRequest parses query parameters into a StreamsRequest
func parseStreamRequest(r *http.Request) (*StreamsRequest, error) {
	req := &StreamsRequest{}

	// Parse LOD parameter (required)
	lodParam := r.URL.Query().Get("lod")
	if lodParam == "" {
		return nil, fmt.Errorf("lod parameter is required")
	}

	switch lodParam {
	case "medium":
		req.LOD = models.StreamLODMedium
	case "low":
		req.LOD = models.StreamLODLow
	case "full":
		req.LOD = models.StreamLODFull
	default:
		return nil, fmt.Errorf("invalid lod value: %s (must be medium, low, or full)", lodParam)
	}

	// Parse types parameter (required)
	typesParam := r.URL.Query().Get("type")
	if typesParam == "" {
		return nil, fmt.Errorf("type parameter is required")
	}

	// Split comma-separated types
	typeStrings := strings.Split(typesParam, ",")
	req.Types = make([]models.StreamType, 0, len(typeStrings))

	for _, typeStr := range typeStrings {
		typeStr = strings.TrimSpace(typeStr)
		switch typeStr {
		case "time":
			req.Types = append(req.Types, models.StreamTypeTime)
		case "distance":
			req.Types = append(req.Types, models.StreamTypeDistance)
		case "elevation":
			req.Types = append(req.Types, models.StreamTypeElevation)
		case "speed":
			req.Types = append(req.Types, models.StreamTypeSpeed)
		default:
			return nil, fmt.Errorf("invalid type value: %s (must be one of: time, distance, elevation, speed)", typeStr)
		}
	}

	if len(req.Types) == 0 {
		return nil, fmt.Errorf("at least one type must be specified")
	}

	return req, nil
}
