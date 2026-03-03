ALTER TABLE activities
    DROP CONSTRAINT IF EXISTS activities_user_max_hr_bpm_range,
    DROP CONSTRAINT IF EXISTS activities_perceived_effort_range,
    DROP COLUMN IF EXISTS user_max_hr_bpm,
    DROP COLUMN IF EXISTS perceived_effort;
