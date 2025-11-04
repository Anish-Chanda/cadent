CREATE TYPE activity_type AS ENUM (
    'run',
    'road_bike'
);

CREATE TABLE activities (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id text NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    client_activity_id uuid UNIQUE NOT NULL,
    title text NOT NULL,
    description text,
    type activity_type NOT NULL,
    start_time timestamptz NOT NULL,
    end_time timestamptz,
    elapsed_time integer NOT NULL, -- elapsed time in seconds
    distance_m numeric(12, 2) NOT NULL, -- distance in meters
    elevation_gain_m numeric(10, 2), -- elevation gain in meters (nullable for indoor activities)
    avg_speed_mps numeric(10, 3), -- average speed in meters per second
    max_speed_mps numeric(10, 3), -- max speed in meters per second
    avg_hr_bpm smallint, -- average heart rate (nullable if no HR sensor)
    max_hr_bpm smallint, -- max heart rate (nullable if no HR sensor)
    processing_ver integer NOT NULL DEFAULT 1,
    
    -- Polyline and route data
    polyline text, -- encoded polyline string
    
    -- Bounding box coordinates
    bbox_min_lat numeric(10, 7),
    bbox_min_lon numeric(11, 7),
    bbox_max_lat numeric(10, 7),
    bbox_max_lon numeric(11, 7),
    
    -- Start and end coordinates
    start_lat numeric(10, 7),
    start_lon numeric(11, 7),
    end_lat numeric(10, 7),
    end_lon numeric(11, 7),
    
    -- Valhalla processing metadata
    num_legs integer,
    num_alternates integer,
    num_points_poly integer,
    val_duration_seconds numeric(10, 3), -- Valhalla calculated duration
    
    -- File storage
    file_url text,
    
    -- Timestamps
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);