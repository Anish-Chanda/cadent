# flow: authenticate, fetch plans, create one real planned activity, call dry run for the plan and assert, modify import vars and assert

### Authentication required for dry-run endpoint
POST http://localhost:8080/api/v1/training-plans/00000000-0000-0000-0000-000000000000/import/dry-run
Content-Type: application/json
{
  "startDate": "2026-06-02T09:00:00Z",
  "selectedWorkoutsPerWeek": 2,
  "title": "Unauthorized Dry Run"
}
HTTP 401

### Setup: Create isolated user
POST http://localhost:8080/api/signup
Content-Type: application/json
{
  "user": "tp_dryrun_{{now}}@test.com",
  "passwd": "DryRun123!",
  "name": "Training Plan Dry Run User"
}
HTTP 201

### Login
POST http://localhost:8080/api/auth/local/login
[Form]
user: tp_dryrun_{{now}}@test.com
passwd: DryRun123!
HTTP 200
[Asserts]
cookie "JWT" exists

### Get plans and capture first plan
GET http://localhost:8080/api/v1/training-plans
HTTP 200
[Captures]
plan_id: jsonpath "$[0].id"
plan_title: jsonpath "$[0].title"
[Asserts]
jsonpath "$" isCollection
jsonpath "$" count >= 1
jsonpath "$[0].id" exists
jsonpath "$[0].title" exists

### Get workouts for first plan and capture workout metadata
GET http://localhost:8080/api/v1/training-plans/{{plan_id}}/workouts
HTTP 200
[Captures]
first_workout_title: jsonpath "$[0].title"
second_workout_title: jsonpath "$[1].title"
[Asserts]
jsonpath "$" isCollection
jsonpath "$" count >= 2
jsonpath "$[0].sequence_index" == 1
jsonpath "$[1].sequence_index" == 2
jsonpath "$[0].title" exists
jsonpath "$[1].title" exists

### Create one real planned activity that must appear in dry-run output
POST http://localhost:8080/api/v1/activities/plan
Content-Type: application/json
{
  "title": "Seed Planned Session",
  "description": "Existing planned activity before import dry-run",
  "activityType": "running",
  "startTime": "2026-06-01T07:00:00Z",
  "plannedDistanceMeter": 5000,
  "plannedDurationSecond": 1800,
  "plannedElevationGainMeter": 30,
  "targetAverageSpeedMeterPerSecond": 2.8
}
HTTP 201
[Captures]
seed_planned_id: jsonpath "$.id"
[Asserts]
jsonpath "$.id" matches /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/

### Dry-run A: lower workouts/week and first start date
POST http://localhost:8080/api/v1/training-plans/{{plan_id}}/import/dry-run
Content-Type: application/json
{
  "startDate": "2026-06-02T09:00:00Z",
  "selectedWorkoutsPerWeek": 2,
  "title": "Dry Run Variant A",
  "description": "Lower density import"
}
HTTP 200
[Captures]
dryrun_a_first_import_start: jsonpath "$.planned_activities[1].start_time"
dryrun_a_second_import_start: jsonpath "$.planned_activities[2].start_time"
[Asserts]
jsonpath "$.activities" isCollection
jsonpath "$.activities" count == 0
jsonpath "$.planned_activities" isCollection
jsonpath "$.planned_activities" count >= 3

# Existing planned item remains present and unchanged
jsonpath "$.planned_activities[0].id" == "{{seed_planned_id}}"
jsonpath "$.planned_activities[0].title" == "Seed Planned Session"
jsonpath "$.planned_activities[0].start_time" == "2026-06-01T07:00:00Z"

# Dry-run injected entries are present and explicitly marked
jsonpath "$.planned_activities[*].id" contains "dry-run-1"
jsonpath "$.planned_activities[*].id" contains "dry-run-2"
jsonpath "$.planned_activities[*].is_dry_run" contains true

# Dry-run includes workouts from selected plan and sequence metadata
jsonpath "$.planned_activities[*].title" contains "{{first_workout_title}}"
jsonpath "$.planned_activities[*].title" contains "{{second_workout_title}}"
jsonpath "$.planned_activities[*].plan_sequence_index" contains 1
jsonpath "$.planned_activities[*].plan_sequence_index" contains 2

### Dry-run B: modify start date and workouts/week; assert output changes
POST http://localhost:8080/api/v1/training-plans/{{plan_id}}/import/dry-run
Content-Type: application/json
{
  "startDate": "2026-06-09T09:00:00Z",
  "selectedWorkoutsPerWeek": 4,
  "title": "Dry Run Variant B",
  "description": "Higher density import"
}
HTTP 200
[Asserts]
jsonpath "$.activities" count == 0
jsonpath "$.planned_activities" count >= 5

# Existing planned item still present in merged result
jsonpath "$.planned_activities[0].id" == "{{seed_planned_id}}"
jsonpath "$.planned_activities[0].title" == "Seed Planned Session"

# Dry-run entries still present and marked
jsonpath "$.planned_activities[*].id" contains "dry-run-1"
jsonpath "$.planned_activities[*].id" contains "dry-run-2"
jsonpath "$.planned_activities[*].is_dry_run" contains true

# Modified variables should change dry-run schedule positions
jsonpath "$.planned_activities[1].start_time" != "{{dryrun_a_first_import_start}}"
jsonpath "$.planned_activities[2].start_time" != "{{dryrun_a_second_import_start}}"

# Sequence metadata should include deeper indexes with higher workouts/week
jsonpath "$.planned_activities[*].plan_sequence_index" contains 1
jsonpath "$.planned_activities[*].plan_sequence_index" contains 4
