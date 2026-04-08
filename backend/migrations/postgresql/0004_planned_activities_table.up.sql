CREATE TYPE planned_activity_type AS ENUM (
    'running',
    'road_biking',
    'resting',
    'cross_training',
    'strength_training',
    'mobility_training'
);

CREATE TABLE planned_activities (
    -- Identity and User Reference
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id text NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Descriptive Fields
    title text NOT NULL,
    description text,

    -- Planned activity metadata
    type planned_activity_type NOT NULL,
    start_time timestamptz NOT NULL,
    
    -- Planned Metrics (SI Units)
    planned_distance_m numeric(12, 2),
    planned_duration_s integer,
    planned_elevation_gain_m numeric(10, 2), 
    target_avg_speed_mps numeric(10, 3),
    target_power_watt integer,

    -- Matching to a real completed activity (will be soon implemented by moi)
    matched_activity_id uuid REFERENCES activities(id) ON DELETE SET NULL,

    -- Timestamps
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Integrity Constraints
    CONSTRAINT planned_activities_planned_duration_s_nonnegative
        CHECK (planned_duration_s IS NULL OR planned_duration_s >= 0),
    CONSTRAINT planned_activities_target_power_watt_nonnegative
        CHECK (target_power_watt IS NULL OR target_power_watt >= 0)
);