ALTER TABLE activities
    ADD COLUMN perceived_effort smallint;

UPDATE activities
SET perceived_effort = 5
WHERE perceived_effort IS NULL;

ALTER TABLE activities
    ALTER COLUMN perceived_effort SET NOT NULL,
    ADD CONSTRAINT activities_perceived_effort_range CHECK (perceived_effort BETWEEN 1 AND 10);
