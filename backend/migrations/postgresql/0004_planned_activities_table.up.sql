CREATE TABLE planned_activities (
    -- Identity and User Reference
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id text NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Descriptive Fields
    title text NOT NULL,
    description text,
    
    -- Activity Metadata
    type activity_type NOT NULL,
    start_time timestamptz NOT NULL,
    
    -- Planned Metrics (SI Units)
    planned_distance_m numeric(12, 2),
    planned_duration_s integer,
    planned_elevation_gain_m numeric(10, 2), 
    target_avg_speed_mps numeric(10, 3),
    target_power_watt integer,

    -- Timestamps
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);
