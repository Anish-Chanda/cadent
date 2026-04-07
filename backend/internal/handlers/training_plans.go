package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"sort"
	"strings"
	"time"

	"github.com/anish-chanda/cadent/backend/internal/models"
	"github.com/go-chi/chi/v5"
)

type ImportTrainingPlanRequest struct {
	StartDate               time.Time `json:"startDate"`
	SelectedWorkoutsPerWeek int       `json:"selectedWorkoutsPerWeek"`
	Title                   string    `json:"title"`
	Description             *string   `json:"description"`
}

type ImportTrainingPlanResponse struct {
	UserTrainingPlanID       string `json:"userTrainingPlanId"`
	PlannedActivitiesCreated int    `json:"plannedActivitiesCreated"`
}

type scheduledTrainingPlanWorkout struct {
	workout         models.TrainingPlanWorkout
	planSequence    int
	targetDayOffset int
}

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

func (h *Handler) HandleImportTrainingPlan() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := r.Context()

		userID, err := h.getAuthenticatedUserID(ctx, r)
		if err != nil {
			h.log.Error("Failed to get authenticated user for training plan import", err)
			http.Error(w, err.Error(), http.StatusUnauthorized)
			return
		}

		planID := chi.URLParam(r, "id")
		if strings.TrimSpace(planID) == "" {
			sendError(w, http.StatusBadRequest, "Missing training plan ID")
			return
		}

		var req ImportTrainingPlanRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			h.log.Error("Failed to decode training plan import request", err)
			sendError(w, http.StatusBadRequest, "Invalid JSON format")
			return
		}

		title := strings.TrimSpace(req.Title)
		if title == "" {
			sendError(w, http.StatusBadRequest, "Title is required")
			return
		}
		if req.StartDate.IsZero() {
			sendError(w, http.StatusBadRequest, "Valid startDate is required")
			return
		}
		if req.SelectedWorkoutsPerWeek < 1 || req.SelectedWorkoutsPerWeek > 7 {
			sendError(w, http.StatusBadRequest, "selectedWorkoutsPerWeek must be between 1 and 7")
			return
		}

		plan, err := h.database.GetTrainingPlanByID(ctx, planID)
		if err != nil {
			h.log.Error("Database failed to fetch training plan", err)
			sendError(w, http.StatusInternalServerError, "Failed to retrieve training plan")
			return
		}
		if plan == nil {
			sendError(w, http.StatusNotFound, "Training plan not found")
			return
		}

		workouts, err := h.database.GetTrainingPlanWorkouts(ctx, planID)
		if err != nil {
			h.log.Error("Database failed to fetch training plan workouts", err)
			sendError(w, http.StatusInternalServerError, "Failed to retrieve training plan workouts")
			return
		}

		description := normalizeOptionalString(req.Description)
		userPlan := &models.UserTrainingPlan{
			UserID:                  userID,
			TrainingPlanID:          plan.ID,
			Title:                   title,
			Description:             description,
			StartDate:               req.StartDate,
			SelectedWorkoutsPerWeek: req.SelectedWorkoutsPerWeek,
		}

		scheduledWorkouts := scheduleTemplateWorkouts(workouts, req.SelectedWorkoutsPerWeek)
		plannedActivities := buildPlannedActivitiesFromScheduledWorkouts(userID, req.StartDate, scheduledWorkouts)

		if err := h.database.CreateUserTrainingPlanWithPlannedActivities(ctx, userPlan, plannedActivities); err != nil {
			h.log.Error("Database failed to import training plan", err)
			sendError(w, http.StatusInternalServerError, "Failed to import training plan")
			return
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(w).Encode(ImportTrainingPlanResponse{
			UserTrainingPlanID:       userPlan.ID.String(),
			PlannedActivitiesCreated: len(plannedActivities),
		})
	}
}

func normalizeOptionalString(input *string) *string {
	if input == nil {
		return nil
	}
	trimmed := strings.TrimSpace(*input)
	if trimmed == "" {
		return nil
	}
	return &trimmed
}

func scheduleTemplateWorkouts(workouts []models.TrainingPlanWorkout, selectedWorkoutsPerWeek int) []scheduledTrainingPlanWorkout {
	if len(workouts) == 0 {
		return []scheduledTrainingPlanWorkout{}
	}

	sortedWorkouts := append([]models.TrainingPlanWorkout(nil), workouts...)
	sort.Slice(sortedWorkouts, func(i, j int) bool {
		return sortedWorkouts[i].SequenceIndex < sortedWorkouts[j].SequenceIndex
	})

	weekdaySlots := buildWeekdaySlots(sortedWorkouts, selectedWorkoutsPerWeek)
	scheduled := make([]scheduledTrainingPlanWorkout, 0, len(sortedWorkouts))

	for i, workout := range sortedWorkouts {
		weekIndex := i / selectedWorkoutsPerWeek
		slotIndex := i % selectedWorkoutsPerWeek
		dayOffset := weekIndex*7 + weekdaySlots[slotIndex]

		scheduled = append(scheduled, scheduledTrainingPlanWorkout{
			workout:         workout,
			planSequence:    i + 1,
			targetDayOffset: dayOffset,
		})
	}

	return scheduled
}

func buildWeekdaySlots(workouts []models.TrainingPlanWorkout, selectedWorkoutsPerWeek int) []int {
	if selectedWorkoutsPerWeek <= 0 {
		return []int{0}
	}

	slots := make([]int, 0, selectedWorkoutsPerWeek)
	seen := make(map[int]bool)

	for _, workout := range workouts {
		daySlot := workout.TemplateDayOffset % 7
		if daySlot < 0 {
			daySlot += 7
		}
		if seen[daySlot] {
			continue
		}
		slots = append(slots, daySlot)
		seen[daySlot] = true
		if len(slots) == selectedWorkoutsPerWeek {
			return slots
		}
	}

	if len(slots) == 0 {
		slots = append(slots, 0)
		seen[0] = true
	}

	for day := 0; day < 7 && len(slots) < selectedWorkoutsPerWeek; day++ {
		if seen[day] {
			continue
		}
		slots = append(slots, day)
		seen[day] = true
	}

	return slots
}

func buildPlannedActivitiesFromScheduledWorkouts(userID string, startDate time.Time, scheduledWorkouts []scheduledTrainingPlanWorkout) []models.PlannedActivity {
	plannedActivities := make([]models.PlannedActivity, 0, len(scheduledWorkouts))

	for _, scheduledWorkout := range scheduledWorkouts {
		sequence := scheduledWorkout.planSequence
		startTime := startDate.AddDate(0, 0, scheduledWorkout.targetDayOffset)

		plannedActivities = append(plannedActivities, models.PlannedActivity{
			UserID:                userID,
			Title:                 scheduledWorkout.workout.Title,
			Description:           scheduledWorkout.workout.Description,
			Type:                  scheduledWorkout.workout.Type,
			StartTime:             startTime,
			PlannedDistanceM:      scheduledWorkout.workout.PlannedDistanceM,
			PlannedDurationS:      scheduledWorkout.workout.PlannedDurationS,
			PlannedElevationGainM: scheduledWorkout.workout.PlannedElevationGainM,
			TargetAvgSpeedMps:     scheduledWorkout.workout.TargetAvgSpeedMps,
			TargetPowerWatt:       scheduledWorkout.workout.TargetPowerWatt,
			PlanSequenceIndex:     &sequence,
		})
	}

	return plannedActivities
}
