package handlers

import (
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"github.com/anish-chanda/cadence/backend/internal/db"
	"github.com/anish-chanda/cadence/backend/internal/logger"
	"github.com/anish-chanda/cadence/backend/internal/models"
	"github.com/go-pkgz/auth/v2/token"
)

type CreatePlannedActivityRequest struct {
	Title       string `json:"title"`
	Description string `json:"description"`

	ActivityType string    `json:"activityType"`
	StartTime    time.Time `json:"startTime"`

	PlannedDistanceMeter             *float64 `json:"plannedDistanceMeter"`
	PlannedDurationSecond            *int     `json:"plannedDurationSecond"`
	PlannedElevationGainMeter        *float64 `json:"plannedElevationGainMeter"`
	TargetAverageSpeedMeterPerSecond *float64 `json:"targetAverageSpeedMeterPerSecond"`
	TargetPowerWatt                  *int     `json:"targetPowerWatt"`
}

func HandleCreatePlannedActivity(database db.Database, log logger.ServiceLogger) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := r.Context()

		// 1. Auth Check
		user, err := token.GetUserInfo(r)
		if err != nil {
			log.Error("Unauthorized access attempt", err)
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}
		userID, err := getAuthenticatedUserID(ctx, r, database, log)
		if err != nil {
			http.Error(w, err.Error(), http.StatusUnauthorized)
			return
		}

		// 2. Decode the JSON Body
		var req CreatePlannedActivityRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			log.Error("Failed to decode plan request", err)
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

		// 3. Save to Database
		plan := &models.PlannedActivity{
			UserID:                userID,
			Title:                 req.Title,
			Description:           &req.Description,
			Type:                  models.ActivityType(req.ActivityType),
			StartTime:             req.StartTime,
			PlannedDistanceM:      req.PlannedDistanceMeter,
			PlannedDurationS:      req.PlannedDurationSecond,
			PlannedElevationGainM: req.PlannedElevationGainMeter,
			TargetAvgSpeedMps:     req.TargetAverageSpeedMeterPerSecond,
			TargetPowerWatt:       req.TargetPowerWatt,
		}

		saved, err := database.CreatePlannedActivity(ctx, plan)
		if err != nil {
			log.Error("Database failed", err)
			sendError(w, http.StatusInternalServerError, "Failed to save to database")
			return
		}

		// 4. Build Success Response
		savedDescription := ""
		if saved.Description != nil {
			savedDescription = *saved.Description
		}

		response := map[string]interface{}{
			"status":  "success",
			"message": "Activity created",
			"data": map[string]string{
				"title":       saved.Title,
				"description": savedDescription,
				"created_by":  user.Name,
			},
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
