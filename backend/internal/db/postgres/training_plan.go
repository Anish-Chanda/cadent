package postgres

import (
	"context"
	"fmt"

	"github.com/anish-chanda/cadent/backend/internal/models"
	"github.com/jackc/pgx/v5"
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

func (s *PostgresDB) GetTrainingPlanByID(ctx context.Context, planID string) (*models.TrainingPlan, error) {
	query := `
		SELECT id, created_by_user_id, title, description, primary_sport, difficulty,
			   duration_weeks, recommended_workouts_per_week, is_system, created_at, updated_at
		FROM training_plans
		WHERE id = $1
	`

	var plan models.TrainingPlan
	err := s.pool.QueryRow(ctx, query, planID).Scan(
		&plan.ID, &plan.CreatedByUserID, &plan.Title, &plan.Description, &plan.PrimarySport, &plan.Difficulty,
		&plan.DurationWeeks, &plan.RecommendedWorkoutsPerWeek, &plan.IsSystem, &plan.CreatedAt, &plan.UpdatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("failed to get training plan by id: %w", err)
	}

	return &plan, nil
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

func (s *PostgresDB) CreateUserTrainingPlanWithPlannedActivities(ctx context.Context, userPlan *models.UserTrainingPlan, plannedActivities []models.PlannedActivity) error {
	beginner, ok := s.pool.(interface {
		Begin(context.Context) (pgx.Tx, error)
	})
	if !ok {
		return fmt.Errorf("database pool does not support transactions")
	}

	tx, err := beginner.Begin(ctx)
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}

	committed := false
	defer func() {
		if !committed {
			_ = tx.Rollback(ctx)
		}
	}()

	insertUserPlanQuery := `
		INSERT INTO user_training_plans (
			user_id, training_plan_id, title, description, start_date, selected_workouts_per_week
		)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id, created_at, updated_at
	`

	err = tx.QueryRow(ctx, insertUserPlanQuery,
		userPlan.UserID,
		userPlan.TrainingPlanID,
		userPlan.Title,
		userPlan.Description,
		userPlan.StartDate,
		userPlan.SelectedWorkoutsPerWeek,
	).Scan(&userPlan.ID, &userPlan.CreatedAt, &userPlan.UpdatedAt)
	if err != nil {
		return fmt.Errorf("failed to create user training plan: %w", err)
	}

	if len(plannedActivities) == 0 {
		if err := tx.Commit(ctx); err != nil {
			return fmt.Errorf("failed to commit transaction: %w", err)
		}
		committed = true
		return nil
	}

	batch := &pgx.Batch{}
	insertPlannedActivityQuery := `
		INSERT INTO planned_activities (
			user_id, title, description, type, start_time,
			planned_distance_m, planned_duration_s, planned_elevation_gain_m,
			target_avg_speed_mps, target_power_watt,
			user_training_plan_id, plan_sequence_index
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
	`

	for i := range plannedActivities {
		activity := plannedActivities[i]
		if activity.PlanSequenceIndex == nil {
			return fmt.Errorf("planned activity at index %d missing plan sequence index", i)
		}

		batch.Queue(
			insertPlannedActivityQuery,
			activity.UserID,
			activity.Title,
			activity.Description,
			activity.Type,
			activity.StartTime,
			activity.PlannedDistanceM,
			activity.PlannedDurationS,
			activity.PlannedElevationGainM,
			activity.TargetAvgSpeedMps,
			activity.TargetPowerWatt,
			userPlan.ID,
			*activity.PlanSequenceIndex,
		)
	}

	batchResults := tx.SendBatch(ctx, batch)
	for i := 0; i < len(plannedActivities); i++ {
		if _, err := batchResults.Exec(); err != nil {
			_ = batchResults.Close()
			return fmt.Errorf("failed to batch insert planned activities: %w", err)
		}
	}
	if err := batchResults.Close(); err != nil {
		return fmt.Errorf("failed to finalize planned activity batch: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("failed to commit transaction: %w", err)
	}
	committed = true

	return nil
}
