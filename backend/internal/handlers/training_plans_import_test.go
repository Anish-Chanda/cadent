package handlers

import (
	"testing"

	"github.com/anish-chanda/cadent/backend/internal/models"
	"github.com/google/uuid"
)

func makeWorkout(sequenceIndex int, templateDayOffset int) models.TrainingPlanWorkout {
	return models.TrainingPlanWorkout{
		ID:                uuid.New(),
		SequenceIndex:     sequenceIndex,
		TemplateDayOffset: templateDayOffset,
		Type:              models.PlannedActivityTypeRunning,
		Title:             "Workout",
	}
}

func TestScheduleTemplateWorkouts_ReflowLowerWorkoutsPerWeek(t *testing.T) {
	workouts := []models.TrainingPlanWorkout{
		makeWorkout(1, 0),
		makeWorkout(2, 2),
		makeWorkout(3, 4),
		makeWorkout(4, 6),
	}

	scheduled := scheduleTemplateWorkouts(workouts, 2)
	if len(scheduled) != 4 {
		t.Fatalf("expected 4 scheduled workouts, got %d", len(scheduled))
	}

	expectedOffsets := []int{0, 2, 7, 9}
	for i := range scheduled {
		if scheduled[i].planSequence != i+1 {
			t.Fatalf("expected sequence %d, got %d", i+1, scheduled[i].planSequence)
		}
		if scheduled[i].targetDayOffset != expectedOffsets[i] {
			t.Fatalf("expected day offset %d at index %d, got %d", expectedOffsets[i], i, scheduled[i].targetDayOffset)
		}
	}
}

func TestScheduleTemplateWorkouts_ReflowHigherWorkoutsPerWeek(t *testing.T) {
	workouts := []models.TrainingPlanWorkout{
		makeWorkout(1, 0),
		makeWorkout(2, 2),
		makeWorkout(3, 4),
		makeWorkout(4, 6),
		makeWorkout(5, 7),
		makeWorkout(6, 9),
		makeWorkout(7, 11),
		makeWorkout(8, 13),
	}

	scheduled := scheduleTemplateWorkouts(workouts, 6)
	if len(scheduled) != 8 {
		t.Fatalf("expected 8 scheduled workouts, got %d", len(scheduled))
	}

	expectedOffsets := []int{0, 2, 4, 6, 1, 3, 7, 9}
	for i := range scheduled {
		if scheduled[i].targetDayOffset != expectedOffsets[i] {
			t.Fatalf("expected day offset %d at index %d, got %d", expectedOffsets[i], i, scheduled[i].targetDayOffset)
		}
	}
}
