CREATE TYPE activity_type AS ENUM (
    'run',
    'road_bike'
);

 CREATE TABLE activities (
    id uuid PRIMARY KEY,
    client_activity_id uuid UNIQUE NOT NULL,
    title text NOT NULL,
    description text,
    type activity_type NOT NULL,
    start_time timestamptz NOT NULL,
    end_time timestamptz,
    elapsed_time integer NOT NULL,
    moving_time integer,
    distance_m numeric(12, 2),
    elevation_gain_m numeric(10, 2),
    avg_speed_mps numeric(10, 3),
    max_speed_mps numeric(10, 3),
    avg_hr_bpm smallint,
    max_hr_bpm smallint,
    processing_ver integer NOT NULL,
    file_url text,
    source jsonb NOT NULL
);