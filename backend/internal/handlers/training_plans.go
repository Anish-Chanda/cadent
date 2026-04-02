package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"

	"github.com/anish-chanda/cadent/backend/internal/models"
	"github.com/go-chi/chi/v5"
)

func (h *Handler) HandleGetTrainingPlans() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := r.Context()

		if _, err := h.getAuthenticatedUserID(ctx, r); err != nil {
			http.Error(w, err.Error(), http.StatusUnauthorized)
			return
		}

		searchQuery := r.URL.Query().Get("q")
		sport := r.URL.Query().Get("sport")

		if sport != "" && sport != string(models.ActivityTypeRun) && sport != string(models.ActivityTypeRoadBike) {
			sendError(w, http.StatusBadRequest, fmt.Sprintf("Invalid sport filter: %s", sport))
			return
		}

		plans, err := h.database.GetTrainingPlans(ctx, searchQuery, sport)
		if err != nil {
			h.log.Error("Database failed to get training plans", err)
			sendError(w, http.StatusInternalServerError, "Failed to retrieve training plans")
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(plans)
	}
}

func (h *Handler) HandleGetTrainingPlanWorkouts() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := r.Context()

		if _, err := h.getAuthenticatedUserID(ctx, r); err != nil {
			http.Error(w, err.Error(), http.StatusUnauthorized)
			return
		}

		planID := chi.URLParam(r, "id")
		if planID == "" {
			sendError(w, http.StatusBadRequest, "Missing plan ID")
			return
		}

		workouts, err := h.database.GetTrainingPlanWorkouts(ctx, planID)
		if err != nil {
			h.log.Error("Database failed to get training plan workouts", err)
			sendError(w, http.StatusInternalServerError, "Failed to retrieve workouts")
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(workouts)
	}
}
