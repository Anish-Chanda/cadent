package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/anish-chanda/cadent/backend/internal/models"
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

func isValidPlannedActivityType(actType string) bool {
	switch models.PlannedActivityType(actType) {
	case models.PlannedActivityTypeRunning,
		models.PlannedActivityTypeRoadBiking,
		models.PlannedActivityTypeResting,
		models.PlannedActivityTypeCrossTraining,
		models.PlannedActivityTypeStrengthTraining,
		models.PlannedActivityTypeMobilityTraining:
		return true
	}
	return false
}

func (h *Handler) HandleCreatePlannedActivity() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := r.Context()

		userID, err := h.getAuthenticatedUserID(ctx, r)
		if err != nil {
			http.Error(w, err.Error(), http.StatusUnauthorized)
			return
		}

		var req CreatePlannedActivityRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			h.log.Error("Failed to decode plan request", err)
			sendError(w, http.StatusBadRequest, "Invalid JSON format")
			return
		}

		if strings.TrimSpace(req.Title) == "" || strings.TrimSpace(req.ActivityType) == "" {
			sendError(w, http.StatusBadRequest, "Title and Activity Type are required")
			return
		}
		if req.StartTime.IsZero() {
			sendError(w, http.StatusBadRequest, "Valid Start Time is required")
			return
		}

		if !isValidPlannedActivityType(req.ActivityType) {
			h.log.Error("Invalid activity type", fmt.Errorf("unsupported activity_type: %s", req.ActivityType))
			sendError(w, http.StatusBadRequest, fmt.Sprintf("Invalid activity_type: %s", req.ActivityType))
			return
		}

		plan := &models.PlannedActivity{
			UserID:                userID,
			Title:                 req.Title,
			Description:           req.Description,
			Type:                  models.PlannedActivityType(req.ActivityType),
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

		var req struct {
			ID string `json:"id"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			h.log.Error("Failed to decode delete request", err)
			sendError(w, http.StatusBadRequest, "Invalid JSON format")
			return
		}

		activityID := strings.TrimSpace(req.ID)
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

func (h *Handler) HandleUpdatePlannedActivity() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := r.Context()

		userID, err := h.getAuthenticatedUserID(ctx, r)
		if err != nil {
			http.Error(w, err.Error(), http.StatusUnauthorized)
			return
		}

		// Decode into raw map to distinguish absent fields from explicit null
		var rawFields map[string]json.RawMessage
		if err := json.NewDecoder(r.Body).Decode(&rawFields); err != nil {
			h.log.Error("Failed to decode update request", err)
			sendError(w, http.StatusBadRequest, "Invalid JSON format")
			return
		}

		// Extract and validate ID
		idRaw, hasID := rawFields["id"]
		if !hasID {
			sendError(w, http.StatusBadRequest, "Activity ID is required")
			return
		}
		var activityID string
		if err := json.Unmarshal(idRaw, &activityID); err != nil || strings.TrimSpace(activityID) == "" {
			sendError(w, http.StatusBadRequest, "Activity ID is required")
			return
		}

		// Build updates map: null JSON values set DB column to NULL
		updates := make(map[string]interface{})

		if raw, ok := rawFields["title"]; ok {
			if string(raw) == "null" {
				sendError(w, http.StatusBadRequest, "Title cannot be null")
				return
			}
			var title string
			if err := json.Unmarshal(raw, &title); err != nil {
				sendError(w, http.StatusBadRequest, "Invalid title format")
				return
			}
			trimmed := strings.TrimSpace(title)
			if trimmed == "" {
				sendError(w, http.StatusBadRequest, "Title cannot be empty")
				return
			}
			updates["title"] = trimmed
		}

		if raw, ok := rawFields["description"]; ok {
			if string(raw) == "null" {
				updates["description"] = nil
			} else {
				var desc string
				if err := json.Unmarshal(raw, &desc); err != nil {
					sendError(w, http.StatusBadRequest, "Invalid description format")
					return
				}
				updates["description"] = desc
			}
		}

		if raw, ok := rawFields["activityType"]; ok {
			if string(raw) == "null" {
				sendError(w, http.StatusBadRequest, "Activity type cannot be null")
				return
			}
			var at string
			if err := json.Unmarshal(raw, &at); err != nil {
				sendError(w, http.StatusBadRequest, "Invalid activity type format")
				return
			}
			at = strings.TrimSpace(at)
			if at != string(models.ActivityTypeRun) && at != string(models.ActivityTypeRoadBike) {
				sendError(w, http.StatusBadRequest, fmt.Sprintf("Invalid activity_type: %s. Supported types: running, road_biking", at))
				return
			}
			updates["type"] = at
		}

		if raw, ok := rawFields["startTime"]; ok {
			if string(raw) == "null" {
				sendError(w, http.StatusBadRequest, "Start time cannot be null")
				return
			}
			var st time.Time
			if err := json.Unmarshal(raw, &st); err != nil {
				sendError(w, http.StatusBadRequest, "Invalid start time format")
				return
			}
			if st.IsZero() {
				sendError(w, http.StatusBadRequest, "Valid Start Time is required")
				return
			}
			updates["start_time"] = st
		}

		if raw, ok := rawFields["plannedDistanceMeter"]; ok {
			if string(raw) == "null" {
				updates["planned_distance_m"] = nil
			} else {
				var v float64
				if err := json.Unmarshal(raw, &v); err != nil {
					sendError(w, http.StatusBadRequest, "Invalid planned distance format")
					return
				}
				updates["planned_distance_m"] = v
			}
		}

		if raw, ok := rawFields["plannedDurationSecond"]; ok {
			if string(raw) == "null" {
				updates["planned_duration_s"] = nil
			} else {
				var v int
				if err := json.Unmarshal(raw, &v); err != nil {
					sendError(w, http.StatusBadRequest, "Invalid planned duration format")
					return
				}
				updates["planned_duration_s"] = v
			}
		}

		if raw, ok := rawFields["plannedElevationGainMeter"]; ok {
			if string(raw) == "null" {
				updates["planned_elevation_gain_m"] = nil
			} else {
				var v float64
				if err := json.Unmarshal(raw, &v); err != nil {
					sendError(w, http.StatusBadRequest, "Invalid planned elevation gain format")
					return
				}
				updates["planned_elevation_gain_m"] = v
			}
		}

		if raw, ok := rawFields["targetAverageSpeedMeterPerSecond"]; ok {
			if string(raw) == "null" {
				updates["target_avg_speed_mps"] = nil
			} else {
				var v float64
				if err := json.Unmarshal(raw, &v); err != nil {
					sendError(w, http.StatusBadRequest, "Invalid target average speed format")
					return
				}
				updates["target_avg_speed_mps"] = v
			}
		}

		if raw, ok := rawFields["targetPowerWatt"]; ok {
			if string(raw) == "null" {
				updates["target_power_watt"] = nil
			} else {
				var v int
				if err := json.Unmarshal(raw, &v); err != nil {
					sendError(w, http.StatusBadRequest, "Invalid target power format")
					return
				}
				updates["target_power_watt"] = v
			}
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
