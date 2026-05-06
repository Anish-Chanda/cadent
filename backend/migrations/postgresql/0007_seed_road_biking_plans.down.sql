-- Remove original Cadent road biking training plans.
DELETE FROM training_plans
WHERE title IN (
    'Cadent Beginner Road 50K',
    'Cadent Advanced Road Event Build'
)
AND is_system = true
AND primary_activity_type = 'road_biking'::activity_type;