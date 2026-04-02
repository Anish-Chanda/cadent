ALTER TABLE planned_activities
    DROP CONSTRAINT IF EXISTS planned_activities_user_training_plan_id_plan_sequence_index_consistency,
    DROP CONSTRAINT IF EXISTS planned_activities_plan_sequence_index_positive;

ALTER TABLE planned_activities
    DROP COLUMN IF EXISTS plan_sequence_index,
    DROP COLUMN IF EXISTS user_training_plan_id;

DROP TABLE IF EXISTS user_training_plans CASCADE;
DROP TABLE IF EXISTS training_plan_workouts CASCADE;
DROP TABLE IF EXISTS training_plans CASCADE;

DROP TYPE IF EXISTS training_plan_difficulty;
