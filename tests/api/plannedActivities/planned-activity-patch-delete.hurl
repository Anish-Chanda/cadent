# Planned Activity PATCH and DELETE E2E Tests

# --- Setup: Create a user and a planned activity to work with ---

POST http://localhost:8080/api/signup
Content-Type: application/json
[Options]
variable: plan_uuid={{newUuid}}
variable: plan_email=planpatchdel-{{plan_uuid}}@test.com
{
    "user": "{{plan_email}}",
    "passwd": "PatchDelTest123!",
    "name": "Patch Delete Tester"
}
HTTP 201

POST http://localhost:8080/api/auth/local/login
[Form]
user: {{plan_email}}
passwd: PatchDelTest123!
HTTP 200
[Asserts]
cookie "JWT" exists

POST http://localhost:8080/api/v1/activities/plan
Content-Type: application/json
{
  "title": "Morning Hill Climb",
  "description": "Steady climb with cadence focus.",
  "activityType": "road_bike",
  "startTime": "2026-04-15T06:00:00Z",
  "plannedDistanceMeter": 30000,
  "plannedDurationSecond": 5400,
  "plannedElevationGainMeter": 500,
  "targetAverageSpeedMeterPerSecond": 5.56,
  "targetPowerWatt": 200
}
HTTP 201
[Captures]
activity_id: jsonpath "$.id"
[Asserts]
jsonpath "$.id" matches /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/

# --- PATCH: Update title and description ---

PATCH http://localhost:8080/api/v1/activities/plan
Content-Type: application/json
{
  "id": "{{activity_id}}",
  "title": "Evening Hill Climb",
  "description": "Updated to evening session with power intervals."
}
HTTP 200
[Asserts]
jsonpath "$.message" == "Planned activity updated"

# --- PATCH: Update numeric fields ---

PATCH http://localhost:8080/api/v1/activities/plan
Content-Type: application/json
{
  "id": "{{activity_id}}",
  "plannedDistanceMeter": 40000,
  "plannedDurationSecond": 7200,
  "plannedElevationGainMeter": 750,
  "targetAverageSpeedMeterPerSecond": 5.0,
  "targetPowerWatt": 220
}
HTTP 200
[Asserts]
jsonpath "$.message" == "Planned activity updated"

# --- PATCH: Update activity type and start time ---

PATCH http://localhost:8080/api/v1/activities/plan
Content-Type: application/json
{
  "id": "{{activity_id}}",
  "activityType": "run",
  "startTime": "2026-04-20T08:00:00Z"
}
HTTP 200
[Asserts]
jsonpath "$.message" == "Planned activity updated"

# --- PATCH: Missing activity ID returns 400 ---

PATCH http://localhost:8080/api/v1/activities/plan
Content-Type: application/json
{
  "title": "No ID Provided"
}
HTTP 400
[Asserts]
jsonpath "$.error" == "Activity ID is required"

# --- PATCH: No update fields returns 400 ---

PATCH http://localhost:8080/api/v1/activities/plan
Content-Type: application/json
{
  "id": "{{activity_id}}"
}
HTTP 400
[Asserts]
jsonpath "$.error" == "No updates provided"

# --- PATCH: Empty title returns 400 ---

PATCH http://localhost:8080/api/v1/activities/plan
Content-Type: application/json
{
  "id": "{{activity_id}}",
  "title": "   "
}
HTTP 400
[Asserts]
jsonpath "$.error" == "Title cannot be empty"

# --- PATCH: Invalid activity type returns 400 ---

PATCH http://localhost:8080/api/v1/activities/plan
Content-Type: application/json
{
  "id": "{{activity_id}}",
  "activityType": "swimming"
}
HTTP 400

# --- PATCH: Non-existent activity returns 404 ---

PATCH http://localhost:8080/api/v1/activities/plan
Content-Type: application/json
{
  "id": "00000000-0000-0000-0000-000000000000",
  "title": "Ghost Activity"
}
HTTP 404
[Asserts]
jsonpath "$.error" == "Planned activity not found"

# --- DELETE: Successfully delete the activity ---

DELETE http://localhost:8080/api/v1/activities/plan/{{activity_id}}
HTTP 204

# --- DELETE: Deleting again returns 404 ---

DELETE http://localhost:8080/api/v1/activities/plan/{{activity_id}}
HTTP 404
[Asserts]
jsonpath "$.error" == "Planned activity not found"

# --- DELETE: Non-existent activity returns 404 ---

DELETE http://localhost:8080/api/v1/activities/plan/00000000-0000-0000-0000-000000000000
HTTP 404
[Asserts]
jsonpath "$.error" == "Planned activity not found"
