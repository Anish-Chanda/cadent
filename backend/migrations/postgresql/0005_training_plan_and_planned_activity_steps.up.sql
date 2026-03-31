ALTER TABLE planned_activities
    ADD COLUMN steps jsonb NOT NULL DEFAULT '[]'::jsonb;

CREATE TABLE training_plan (
    -- Identity and User Reference
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id text REFERENCES users(id) ON DELETE CASCADE,

    -- Timestamps
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Descriptive Fields
    title text NOT NULL,
    description text,

    -- Ownership Metadata
    is_system boolean NOT NULL DEFAULT false,

    -- Planned activities JSONB payload
    planned_activities jsonb NOT NULL DEFAULT '[]'::jsonb,

    CONSTRAINT training_plan_owner_check CHECK (is_system OR user_id IS NOT NULL)
);
