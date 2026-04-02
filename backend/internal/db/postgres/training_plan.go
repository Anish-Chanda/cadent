package postgres

import (
"context"
"fmt"

"github.com/anish-chanda/cadent/backend/internal/models"
)

func (s *PostgresDB) GetTrainingPlans(ctx context.Context, searchQuery string, sport string) ([]models.TrainingPlan, error) {
	query := `
		SELECT id, created_by_user_id, title, description, primary_sport, difficulty,
			   duration_weeks, recommended_workouts_per_week, is_system, created_at, updated_at
		FROM training_plans
		WHERE 1=1
	`
	args := []interface{}{}
	argIdx := 1

	if searchQuery != "" {
		query += fmt.Sprintf(" AND (title ILIKE $%d OR description ILIKE $%d)", argIdx, argIdx)
		args = append(args, "%"+searchQuery+"%")
		argIdx++
	}
	if sport != "" {
		query += fmt.Sprintf(" AND primary_sport = $%d", argIdx)
		args = append(args, sport)
		argIdx++
	}
	
	query += " ORDER BY is_system DESC, created_at DESC"

	rows, err := s.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to get training plans: %w", err)
	}
	defer rows.Close()

	var plans []models.TrainingPlan
	for rows.Next() {
		var p models.TrainingPlan
		if err := rows.Scan(
&p.ID, &p.CreatedByUserID, &p.Title, &p.Description, &p.PrimarySport, &p.Difficulty,
			&p.DurationWeeks, &p.RecommendedWorkoutsPerWeek, &p.IsSystem, &p.CreatedAt, &p.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan training plan: %w", err)
		}
		plans = append(plans, p)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iteration error: %w", err)
	}

	if plans == nil {
		plans = []models.TrainingPlan{}
	}

	return plans, nil
}

func (s *PostgresDB) GetTrainingPlanWorkouts(ctx context.Context, planID string) ([]models.TrainingPlanWorkout, error) {
	query := `
		SELECT id, training_plan_id, sequence_index, template_day_offset, type, title, description,
			   planned_distance_m, planned_duration_s, planned_elevation_gain_m, target_avg_speed_mps,
			   target_power_watt, created_at, updated_at
		FROM training_plan_workouts
		WHERE training_plan_id = $1
		ORDER BY sequence_index ASC
	`
	
	rows, err := s.pool.Query(ctx, query, planID)
	if err != nil {
		return nil, fmt.Errorf("failed to query workouts: %w", err)
	}
	defer rows.Close()

	var workouts []models.TrainingPlanWorkout
	for rows.Next() {
		var w models.TrainingPlanWorkout
		if err := rows.Scan(
&w.ID, &w.TrainingPlanID, &w.SequenceIndex, &w.TemplateDayOffset, &w.Type, &w.Title,
			&w.Description, &w.PlannedDistanceM, &w.PlannedDurationS, &w.PlannedElevationGainM,
			&w.TargetAvgSpeedMps, &w.TargetPowerWatt, &w.CreatedAt, &w.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan workout: %w", err)
		}
		workouts = append(workouts, w)
	}
	
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iteration error: %w", err)
	}

	if workouts == nil {
		workouts = []models.TrainingPlanWorkout{}
	}

	return workouts, nil
}
