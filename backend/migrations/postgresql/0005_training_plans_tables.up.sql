CREATE TYPE training_plan_difficulty AS ENUM (
    'beginner',
    'intermediate',
    'advanced'
);

CREATE TABLE training_plans (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    created_by_user_id text REFERENCES users(id) ON DELETE SET NULL,

    title text NOT NULL,
    description text,

    -- Main activity type for browsing/filtering. Uses the real activity enum on purpose.
    primary_activity_type activity_type,

    difficulty training_plan_difficulty NOT NULL,
    duration_weeks smallint NOT NULL,
    recommended_workouts_per_week smallint NOT NULL,
    is_system boolean NOT NULL DEFAULT true,

    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT training_plans_duration_weeks_positive
        CHECK (duration_weeks > 0),
    CONSTRAINT training_plans_recommended_workouts_per_week_range
        CHECK (recommended_workouts_per_week BETWEEN 1 AND 7)
);

CREATE TABLE training_plan_workouts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    training_plan_id uuid NOT NULL REFERENCES training_plans(id) ON DELETE CASCADE,

    -- Canonical order of workouts inside the template
    sequence_index integer NOT NULL,

    -- Coach-authored spacing from the imported plan start date
    template_day_offset integer NOT NULL,

    type planned_activity_type NOT NULL,

    title text NOT NULL,
    description text,

    planned_distance_m numeric(12, 2),
    planned_duration_s integer,
    planned_elevation_gain_m numeric(10, 2),
    target_avg_speed_mps numeric(10, 3),
    target_power_watt integer,

    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT training_plan_workouts_sequence_index_positive
        CHECK (sequence_index > 0),
    CONSTRAINT training_plan_workouts_template_day_offset_nonnegative
        CHECK (template_day_offset >= 0),
    CONSTRAINT training_plan_workouts_planned_duration_s_nonnegative
        CHECK (planned_duration_s IS NULL OR planned_duration_s >= 0),
    CONSTRAINT training_plan_workouts_planned_distance_m_nonnegative
        CHECK (planned_distance_m IS NULL OR planned_distance_m >= 0),
    CONSTRAINT training_plan_workouts_target_power_watt_nonnegative
        CHECK (target_power_watt IS NULL OR target_power_watt >= 0),

    CONSTRAINT uq_training_plan_workouts_training_plan_id_sequence_index
        UNIQUE (training_plan_id, sequence_index)
);

CREATE TABLE user_training_plans (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id text NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    training_plan_id uuid NOT NULL REFERENCES training_plans(id) ON DELETE RESTRICT,

    -- Copied from the source plan at import time
    title text NOT NULL,
    description text,

    start_date date NOT NULL,
    selected_workouts_per_week smallint NOT NULL,

    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT user_training_plans_selected_workouts_per_week_range
        CHECK (selected_workouts_per_week BETWEEN 1 AND 7)
);

ALTER TABLE planned_activities
    ADD COLUMN user_training_plan_id uuid REFERENCES user_training_plans(id) ON DELETE CASCADE,
    ADD COLUMN plan_sequence_index integer;

ALTER TABLE planned_activities
    ADD CONSTRAINT planned_activities_plan_sequence_index_positive
        CHECK (plan_sequence_index IS NULL OR plan_sequence_index > 0);

ALTER TABLE planned_activities
    ADD CONSTRAINT planned_activities_user_training_plan_id_plan_sequence_index_consistency
        CHECK (
            (user_training_plan_id IS NULL AND plan_sequence_index IS NULL)
            OR
            (user_training_plan_id IS NOT NULL AND plan_sequence_index IS NOT NULL)
        );