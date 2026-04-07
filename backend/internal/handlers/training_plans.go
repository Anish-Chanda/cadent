package handlers

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"sort"
	"strings"
	"time"

	"github.com/anish-chanda/cadent/backend/internal/models"
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"
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

type ImportTrainingPlanDryRunRequest struct {
	StartDate               time.Time `json:"startDate"`
	SelectedWorkoutsPerWeek int       `json:"selectedWorkoutsPerWeek"`
	Title                   *string   `json:"title,omitempty"`
	Description             *string   `json:"description,omitempty"`
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

		planID := strings.TrimSpace(chi.URLParam(r, "id"))
		if planID == "" {
			sendError(w, http.StatusBadRequest, "Missing plan ID")
			return
		}

		plan, err := h.database.GetTrainingPlanByID(ctx, planID)
		if err != nil {
			h.log.Error("Database failed to get training plan", err)
			sendError(w, http.StatusInternalServerError, "Failed to retrieve training plan")
			return
		}
		if plan == nil {
			sendError(w, http.StatusBadRequest, "Invalid training plan ID: no training plan exists for the provided ID")
			return
		}

		workouts, err := h.database.GetTrainingPlanWorkouts(ctx, planID)
		if err != nil {
			// A valid plan is guarenteed to have workouts, system generated ones are
			// in the migration files, and user generate ones, the handler for that when implemented
			// will validate.
			if errors.Is(err, pgx.ErrNoRows) {
				sendError(w, http.StatusBadRequest, "Invalid training plan ID: no training plan exists for the provided ID")
				return
			}
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

func (h *Handler) HandleImportTrainingPlanDryRun() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := r.Context()

		userID, err := h.getAuthenticatedUserID(ctx, r)
		if err != nil {
			h.log.Error("Failed to get authenticated user for training plan import dry-run", err)
			http.Error(w, err.Error(), http.StatusUnauthorized)
			return
		}

		var req ImportTrainingPlanDryRunRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			h.log.Error("Failed to decode training plan import dry-run request", err)
			sendError(w, http.StatusBadRequest, "Invalid JSON format")
			return
		}

		planID := strings.TrimSpace(chi.URLParam(r, "id"))
		if planID == "" {
			sendError(w, http.StatusBadRequest, "Missing training plan ID")
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
			h.log.Error("Database failed to fetch training plan for dry-run", err)
			sendError(w, http.StatusInternalServerError, "Failed to retrieve training plan")
			return
		}
		if plan == nil {
			sendError(w, http.StatusNotFound, "Training plan not found")
			return
		}

		workouts, err := h.database.GetTrainingPlanWorkouts(ctx, planID)
		if err != nil {
			h.log.Error("Database failed to fetch training plan workouts for dry-run", err)
			sendError(w, http.StatusInternalServerError, "Failed to retrieve training plan workouts")
			return
		}

		scheduledWorkouts := scheduleTemplateWorkouts(workouts, req.SelectedWorkoutsPerWeek)
		dryRunPlannedActivities := buildPlannedActivitiesFromScheduledWorkouts(userID, req.StartDate, scheduledWorkouts)

		rangeStart, rangeEnd := calculateImportDryRunWindow(req.StartDate, dryRunPlannedActivities)
		activities, plannedActivities, err := h.database.GetActivitiesByUserIDAndDate(ctx, userID, rangeStart, rangeEnd)
		if err != nil {
			h.log.Error("Database failed to fetch calendar data for import dry-run", err)
			sendError(w, http.StatusInternalServerError, "Failed to build import preview")
			return
		}

		resultActivities := make([]ActivityResult, 0, len(activities))
		for _, activity := range activities {
			resultActivities = append(resultActivities, createActivityResult(&activity))
		}

		resultPlannedActivities := make([]PlannedActivityResult, 0, len(plannedActivities)+len(dryRunPlannedActivities))
		for _, plannedActivity := range plannedActivities {
			resultPlannedActivities = append(resultPlannedActivities, createPlannedActivityResult(&plannedActivity))
		}

		now := time.Now().UTC()
		for i := range dryRunPlannedActivities {
			plannedResult := createPlannedActivityResult(&dryRunPlannedActivities[i])
			plannedResult.ID = fmt.Sprintf("dry-run-%d", i+1)
			plannedResult.MatchedActivityID = nil
			plannedResult.UserTrainingPlanID = nil
			plannedResult.CreatedAt = now
			plannedResult.UpdatedAt = now
			plannedResult.IsDryRun = true
			resultPlannedActivities = append(resultPlannedActivities, plannedResult)
		}

		response := GetCalendarResponse{
			Activities:        resultActivities,
			PlannedActivities: resultPlannedActivities,
		}

		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(response)
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

func calculateImportDryRunWindow(startDate time.Time, dryRunPlannedActivities []models.PlannedActivity) (time.Time, time.Time) {
	baseDate := time.Date(startDate.Year(), startDate.Month(), startDate.Day(), 0, 0, 0, 0, startDate.Location())
	lastDate := baseDate

	for i := range dryRunPlannedActivities {
		activityDate := time.Date(
			dryRunPlannedActivities[i].StartTime.Year(),
			dryRunPlannedActivities[i].StartTime.Month(),
			dryRunPlannedActivities[i].StartTime.Day(),
			0, 0, 0, 0,
			dryRunPlannedActivities[i].StartTime.Location(),
		)
		if activityDate.After(lastDate) {
			lastDate = activityDate
		}
	}

	windowStart := time.Date(baseDate.Year(), baseDate.Month(), 1, 0, 0, 0, 0, baseDate.Location())
	windowEnd := time.Date(lastDate.Year(), lastDate.Month()+1, 1, 0, 0, 0, 0, lastDate.Location()).Add(-time.Nanosecond)

	return windowStart, windowEnd
}
