ALTER TABLE activities
    ADD COLUMN perceived_effort smallint,
    ADD CONSTRAINT activities_perceived_effort_range CHECK (perceived_effort IS NULL OR (perceived_effort BETWEEN 1 AND 10));
