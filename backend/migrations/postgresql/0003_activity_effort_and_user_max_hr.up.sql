ALTER TABLE activities
    ADD COLUMN perceived_effort smallint,
    ADD COLUMN user_max_hr_bpm smallint;

UPDATE activities
SET perceived_effort = 5
WHERE perceived_effort IS NULL;

ALTER TABLE activities
    ALTER COLUMN perceived_effort SET NOT NULL,
    ADD CONSTRAINT activities_perceived_effort_range CHECK (perceived_effort BETWEEN 1 AND 10),
    ADD CONSTRAINT activities_user_max_hr_bpm_range CHECK (user_max_hr_bpm IS NULL OR user_max_hr_bpm BETWEEN 1 AND 300);
