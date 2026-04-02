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
		models.PlannedActivityTypeRest,
		models.PlannedActivityTypeCrossTraining,
		models.PlannedActivityTypeStrength,
		models.PlannedActivityTypeMobility:
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

func sendError(w http.ResponseWriter, code int, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(map[string]string{"error": message})
}
