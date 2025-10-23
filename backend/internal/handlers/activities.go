package handlers

import (
	"context"
	"encoding/json"
	"net/http"

	"github.com/anish-chanda/cadence/backend/internal/db"
	"github.com/anish-chanda/cadence/backend/internal/logger"
	"github.com/anish-chanda/cadence/backend/internal/valhalla"
)

type CreateActivityRequest struct {
	Samples []Sample `json:"samples"`
}

type Sample struct {
	T   int64   `json:"t"`   // timestamp in unix milliseconds
	Lat float64 `json:"lat"` // latitude
	Lon float64 `json:"lon"` // longitude
}

func HanldeCreateActivity(database db.Database, valhallaClient *valhalla.Client) http.HandlerFunc {
	log := logger.New(logger.Config{Level: "info"})

	return func(w http.ResponseWriter, r *http.Request) {
		ctx := context.Background()

		// Demarshal the request
		var req CreateActivityRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			log.Error("Failed to decode request", err)
			http.Error(w, "Invalid request body", http.StatusBadRequest)
			return
		}

		// Validate request
		if len(req.Samples) == 0 {
			http.Error(w, "Samples cannot be empty", http.StatusBadRequest)
			return
		}

		// Convert samples to GPS points for Valhalla
		var gpsPoints []valhalla.GPSPoint
		for _, sample := range req.Samples {
			gpsPoints = append(gpsPoints, valhalla.GPSPoint{
				Lat: sample.Lat,
				Lon: sample.Lon,
			})
		}

		// Perform map matching with Valhalla
		traceReq := valhalla.TraceRouteRequest{
			Shape:   gpsPoints,
			Costing: valhalla.CostingAuto,
		}

		response, err := valhallaClient.TraceRoute(ctx, traceReq)
		if err != nil {
			log.Error("Failed to perform map matching", err)
			http.Error(w, "Failed to process GPS data", http.StatusInternalServerError)
			return
		}

		// For now, just return the polyline and basic data
		result := map[string]interface{}{
			"polyline":             response.Trip.Legs[0].Shape,
			"distance_km":          response.Trip.Summary.Length,
			"duration_seconds":     response.Trip.Summary.Time,
			"gps_points_processed": len(gpsPoints),
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(result)
	}
}
