package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/anish-chanda/cadent/backend/internal/models"
	"github.com/go-chi/chi/v5"
)

type CreatePlannedActivityRequest struct {
	Title       string  `json:"title"`
	Description *string `json:"description"`

	ActivityType string    `json:"activityType"`
	StartTime    time.Time `json:"startTime"`

	PlannedDistanceMeter             *float64 `json:"plannedDistanceMeter"`
	PlannedDurationSecond            *int     `json:"plannedDurationSecond"`
	PlannedElevationGainMeter        *float64 `json:"plannedElevationGainMeter"`
	TargetAverageSpeedMeterPerSecond *float64 `json:"targetAverageSpeedMeterPerSecond"`
	TargetPowerWatt                  *int     `json:"targetPowerWatt"`
}

func (h *Handler) HandleCreatePlannedActivity() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := r.Context()

		// 1. Auth Check
		userID, err := h.getAuthenticatedUserID(ctx, r)
		if err != nil {
			http.Error(w, err.Error(), http.StatusUnauthorized)
			return
		}

		// 2. Decode the JSON Body
		var req CreatePlannedActivityRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			h.log.Error("Failed to decode plan request", err)
			sendError(w, http.StatusBadRequest, "Invalid JSON format")
			return
		}

		// Validation
		if strings.TrimSpace(req.Title) == "" || strings.TrimSpace(req.ActivityType) == "" {
			sendError(w, http.StatusBadRequest, "Title and Activity Type are required")
			return
		}
		if req.StartTime.IsZero() {
			sendError(w, http.StatusBadRequest, "Valid Start Time is required")
			return
		}
		// Validate activity_type enum database insertion to return 400
		if req.ActivityType != string(models.ActivityTypeRun) && req.ActivityType != string(models.ActivityTypeRoadBike) {
			h.log.Error("Invalid activity type", fmt.Errorf("unsupported activity_type: %s", req.ActivityType))
			sendError(w, http.StatusBadRequest, fmt.Sprintf("Invalid activity_type: %s. Supported types: running, road_biking", req.ActivityType))
			return
		}

		// 3. Save to Database
		plan := &models.PlannedActivity{
			UserID:                userID,
			Title:                 req.Title,
			Description:           req.Description,
			Type:                  models.ActivityType(req.ActivityType),
			StartTime:             req.StartTime,
			PlannedDistanceM:      req.PlannedDistanceMeter,
			PlannedDurationS:      req.PlannedDurationSecond,
			PlannedElevationGainM: req.PlannedElevationGainMeter,
			TargetAvgSpeedMps:     req.TargetAverageSpeedMeterPerSecond,
			TargetPowerWatt:       req.TargetPowerWatt,
		}

		saved, err := h.database.CreatePlannedActivity(ctx, plan)
		if err != nil {
			h.log.Error("Database failed", err)
			sendError(w, http.StatusInternalServerError, "Failed to save to database")
			return
		}

		// 4. Build Success Response
		response := map[string]interface{}{
			"id": saved.ID.String(),
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(response)
	}
}

func (h *Handler) HandleDeletePlannedActivity() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := r.Context()

		userID, err := h.getAuthenticatedUserID(ctx, r)
		if err != nil {
			http.Error(w, err.Error(), http.StatusUnauthorized)
			return
		}

		activityID := chi.URLParam(r, "id")
		if activityID == "" {
			sendError(w, http.StatusBadRequest, "Activity ID is required")
			return
		}

		err = h.database.DeletePlannedActivity(ctx, activityID, userID)
		if err != nil {
			if err.Error() == "planned activity not found" {
				sendError(w, http.StatusNotFound, "Planned activity not found")
				return
			}
			h.log.Error("Failed to delete planned activity", err)
			sendError(w, http.StatusInternalServerError, "Failed to delete planned activity")
			return
		}

		w.WriteHeader(http.StatusNoContent)
	}
}

type UpdatePlannedActivityRequest struct {
	ID                               string     `json:"id"`
	Title                            *string    `json:"title"`
	Description                      *string    `json:"description"`
	ActivityType                     *string    `json:"activityType"`
	StartTime                        *time.Time `json:"startTime"`
	PlannedDistanceMeter             *float64   `json:"plannedDistanceMeter"`
	PlannedDurationSecond            *int       `json:"plannedDurationSecond"`
	PlannedElevationGainMeter        *float64   `json:"plannedElevationGainMeter"`
	TargetAverageSpeedMeterPerSecond *float64   `json:"targetAverageSpeedMeterPerSecond"`
	TargetPowerWatt                  *int       `json:"targetPowerWatt"`
}

func (h *Handler) HandleUpdatePlannedActivity() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := r.Context()

		userID, err := h.getAuthenticatedUserID(ctx, r)
		if err != nil {
			http.Error(w, err.Error(), http.StatusUnauthorized)
			return
		}

		var req UpdatePlannedActivityRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			h.log.Error("Failed to decode update request", err)
			sendError(w, http.StatusBadRequest, "Invalid JSON format")
			return
		}

		if strings.TrimSpace(req.ID) == "" {
			sendError(w, http.StatusBadRequest, "Activity ID is required")
			return
		}
		activityID := req.ID

		// Build updates map from non-nil fields
		updates := make(map[string]interface{})

		if req.Title != nil {
			trimmed := strings.TrimSpace(*req.Title)
			if trimmed == "" {
				sendError(w, http.StatusBadRequest, "Title cannot be empty")
				return
			}
			updates["title"] = trimmed
		}
		if req.Description != nil {
			updates["description"] = req.Description
		}
		if req.ActivityType != nil {
			at := strings.TrimSpace(*req.ActivityType)
			if at != string(models.ActivityTypeRun) && at != string(models.ActivityTypeRoadBike) {
				sendError(w, http.StatusBadRequest, fmt.Sprintf("Invalid activity_type: %s. Supported types: run, road_bike", at))
				return
			}
			updates["type"] = at
		}
		if req.StartTime != nil {
			if req.StartTime.IsZero() {
				sendError(w, http.StatusBadRequest, "Valid Start Time is required")
				return
			}
			updates["start_time"] = *req.StartTime
		}
		if req.PlannedDistanceMeter != nil {
			updates["planned_distance_m"] = *req.PlannedDistanceMeter
		}
		if req.PlannedDurationSecond != nil {
			updates["planned_duration_s"] = *req.PlannedDurationSecond
		}
		if req.PlannedElevationGainMeter != nil {
			updates["planned_elevation_gain_m"] = *req.PlannedElevationGainMeter
		}
		if req.TargetAverageSpeedMeterPerSecond != nil {
			updates["target_avg_speed_mps"] = *req.TargetAverageSpeedMeterPerSecond
		}
		if req.TargetPowerWatt != nil {
			updates["target_power_watt"] = *req.TargetPowerWatt
		}

		if len(updates) == 0 {
			sendError(w, http.StatusBadRequest, "No updates provided")
			return
		}

		err = h.database.UpdatePlannedActivity(ctx, activityID, userID, updates)
		if err != nil {
			if err.Error() == "planned activity not found" {
				sendError(w, http.StatusNotFound, "Planned activity not found")
				return
			}
			h.log.Error("Failed to update planned activity", err)
			sendError(w, http.StatusInternalServerError, "Failed to update planned activity")
			return
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(map[string]string{"message": "Planned activity updated"})
	}
}

func sendError(w http.ResponseWriter, code int, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(map[string]string{"error": message})
}
