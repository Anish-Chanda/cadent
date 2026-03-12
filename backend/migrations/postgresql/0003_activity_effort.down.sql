ALTER TABLE activities
    DROP CONSTRAINT IF EXISTS activities_perceived_effort_range,
    DROP COLUMN IF EXISTS perceived_effort;
