CREATE TYPE activity_type AS ENUM (
    'running',
    'road_biking'
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
    elevation_loss_m numeric(10, 2), -- elevation loss in meters (nullable for indoor activities)
    max_height_m numeric(10, 2), -- maximum height in meters (nullable for indoor activities)
    min_height_m numeric(10, 2), -- minimum height in meters (nullable for indoor activities)
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
    
    -- File storage
    file_url text,
    
    -- Timestamps
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- activity stream ENUMS
CREATE TYPE stream_lod AS ENUM ('medium'); -- low is calculated on the fly based on medium
CREATE TYPE stream_index_by AS ENUM ('distance'); -- downsampled by distance, in future could add 'time' or other methods

-- activity streams table
CREATE TABLE activity_streams (
    activity_id uuid REFERENCES activities(id) ON DELETE CASCADE,
    lod stream_lod NOT NULL,
    index_by stream_index_by NOT NULL,

    -- number of points in this LOD (after downsampling)
    num_points integer NOT NULL CHECK (num_points > 0),
    -- original number of points before downsampling
    original_num_points integer NOT NULL CHECK (original_num_points >= num_points),

    -- compressed streams
    time_s_bytes bytea, -- seconds since start, compressed
    distance_m_bytes bytea, -- distance in meters, compressed
    speed_mps_bytes bytea, -- speed in meters per second, compressed
    elevation_m_bytes bytea, -- elevation in meters, compressed

    -- compression algorithm metadata
    codec jsonb NOT NULL,
    -- e.g. { "name": "dibs", "version": 1, "float": 2, "endianness": "le" }
    -- the above means: DIBS codec version 1, 2 decimal places for floats, little-endian byte order


    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (activity_id, lod, index_by)
);

