# Match Completed Activity to Planned Activity E2E Tests
# Mirrors the real frontend flow:
#   1. Planned activity exists for the day
#   2. User finishes an activity
#   3. Frontend calls GET /today to discover unmatched planned activities
#   4. Frontend uses returned ID to PATCH and create the match

# --- Setup: Create user ---

POST http://localhost:8080/api/signup
Content-Type: application/json
[Options]
variable: match_uuid={{newUuid}}
variable: match_email=matchtest-{{match_uuid}}@test.com
{
    "user": "{{match_email}}",
    "passwd": "MatchTest123!",
    "name": "Match Tester"
}
HTTP 201

POST http://localhost:8080/api/auth/local/login
[Form]
user: {{match_email}}
passwd: MatchTest123!
HTTP 200
[Asserts]
cookie "JWT" exists

# --- Step 1: Planned activity exists for today ---
# NOTE: UPDATE startTime TO TODAY'S DATE FOR TESTING PURPOSES

POST http://localhost:8080/api/v1/activities/plan
Content-Type: application/json
{
  "title": "Morning Easy Run",
  "description": "Easy aerobic run to start the day.",
  "activityType": "running",
  "startTime": "2026-04-21T10:00:00Z",
  "plannedDistanceMeter": 8000,
  "plannedDurationSecond": 2700
}
HTTP 201
[Asserts]
jsonpath "$.id" matches /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/

# --- Step 2: User finishes an activity ---

POST http://localhost:8080/api/v1/activities
Content-Type: application/json
{
  "client_activity_id": "{{newUuid}}",
  "activity_type": "running",
  "title": "Morning Run",
  "samples": [
    {"t": 1771092000000, "lat": 42.02888, "lon": -93.64974},
    {"t": 1771092060000, "lat": 42.02950, "lon": -93.64900},
    {"t": 1771092120000, "lat": 42.03010, "lon": -93.64850},
    {"t": 1771092180000, "lat": 42.02888, "lon": -93.64974}
  ]
}
HTTP 201
[Captures]
completed_activity_id: jsonpath "$.id"
[Asserts]
jsonpath "$.id" matches /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/

# --- Step 3: Frontend calls GET today to discover unmatched planned activities ---
# Returns the planned activity — frontend uses this ID for the PATCH

GET http://localhost:8080/api/v1/activities/plan/today
HTTP 200
[Captures]
planned_activity_id: jsonpath "$.plannedActivities[0].id"
[Asserts]
jsonpath "$.plannedActivities" count == 1
jsonpath "$.plannedActivities[0].title" == "Morning Easy Run"
jsonpath "$.plannedActivities[0].matchedActivityId" == null

# --- Step 4: User selects planned activity — frontend submits the match ---

PATCH http://localhost:8080/api/v1/activities/plan
Content-Type: application/json
{
  "id": "{{planned_activity_id}}",
  "matchedActivityId": "{{completed_activity_id}}"
}
HTTP 200
[Asserts]
jsonpath "$.message" == "Planned activity updated"

# --- Verify: GET by ID confirms matchedActivityId is set ---

GET http://localhost:8080/api/v1/activities/plan
Content-Type: application/json
{
  "id": "{{planned_activity_id}}"
}
HTTP 200
[Asserts]
jsonpath "$.id" == "{{planned_activity_id}}"
jsonpath "$.matchedActivityId" == "{{completed_activity_id}}"

# --- Verify: GET today now returns empty — matched activity is filtered out ---

GET http://localhost:8080/api/v1/activities/plan/today
HTTP 200
[Asserts]
jsonpath "$.plannedActivities" count == 0

# --- Error: matchedActivityId with non-existent activity returns 404 ---

PATCH http://localhost:8080/api/v1/activities/plan
Content-Type: application/json
{
  "id": "{{planned_activity_id}}",
  "matchedActivityId": "00000000-0000-0000-0000-000000000000"
}
HTTP 404
[Asserts]
jsonpath "$.error" == "Activity not found"

# --- Error: matchedActivityId with invalid format returns 404 ---

PATCH http://localhost:8080/api/v1/activities/plan
Content-Type: application/json
{
  "id": "{{planned_activity_id}}",
  "matchedActivityId": "not-a-valid-uuid"
}
HTTP 404
[Asserts]
jsonpath "$.error" == "Activity not found"
