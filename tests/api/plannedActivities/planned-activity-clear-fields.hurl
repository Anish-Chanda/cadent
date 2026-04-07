# Planned Activity Clear Nullable Fields E2E Tests
# Tests clearing populated fields to null and to empty/zero values

# --- Setup: Create a user and a planned activity with all fields filled ---

POST http://localhost:8080/api/signup
Content-Type: application/json
[Options]
variable: plan_uuid={{newUuid}}
variable: plan_email=planclear-{{plan_uuid}}@test.com
{
    "user": "{{plan_email}}",
    "passwd": "ClearTest123!",
    "name": "Clear Fields Tester"
}
HTTP 201

POST http://localhost:8080/api/auth/local/login
[Form]
user: {{plan_email}}
passwd: ClearTest123!
HTTP 200
[Asserts]
cookie "JWT" exists

POST http://localhost:8080/api/v1/activities/plan
Content-Type: application/json
{
  "title": "Full Detail Ride",
  "description": "A ride with every field filled in.",
  "activityType": "road_biking",
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

# --- Verify all fields are populated ---

GET http://localhost:8080/api/v1/calendar?startDate=2026-04-01&endDate=2026-04-30
HTTP 200
[Asserts]
jsonpath "$.planned_activities[0].description" == "A ride with every field filled in."
jsonpath "$.planned_activities[0].planned_distance" == 30000.0
jsonpath "$.planned_activities[0].planned_duration" == 5400
jsonpath "$.planned_activities[0].planned_elevation_gain" == 500.0
jsonpath "$.planned_activities[0].target_avg_speed" == 5.56
jsonpath "$.planned_activities[0].target_power" == 200

# =============================================
# PART 1: Clear fields to null
# =============================================

# --- PATCH: Clear description to null ---

PATCH http://localhost:8080/api/v1/activities/plan
Content-Type: application/json
{
  "id": "{{activity_id}}",
  "description": null
}
HTTP 200
[Asserts]
jsonpath "$.message" == "Planned activity updated"

# --- Verify description is null ---

GET http://localhost:8080/api/v1/calendar?startDate=2026-04-01&endDate=2026-04-30
HTTP 200
[Asserts]
jsonpath "$.planned_activities[0].description" == ""

# --- PATCH: Clear all nullable numeric fields to null ---

PATCH http://localhost:8080/api/v1/activities/plan
Content-Type: application/json
{
  "id": "{{activity_id}}",
  "plannedDistanceMeter": null,
  "plannedDurationSecond": null,
  "plannedElevationGainMeter": null,
  "targetAverageSpeedMeterPerSecond": null,
  "targetPowerWatt": null
}
HTTP 200
[Asserts]
jsonpath "$.message" == "Planned activity updated"

# --- Verify numeric fields are null ---

GET http://localhost:8080/api/v1/calendar?startDate=2026-04-01&endDate=2026-04-30
HTTP 200
[Asserts]
jsonpath "$.planned_activities[0].planned_distance" == null
jsonpath "$.planned_activities[0].planned_duration" == null
jsonpath "$.planned_activities[0].planned_elevation_gain" == null
jsonpath "$.planned_activities[0].target_avg_speed" == null
jsonpath "$.planned_activities[0].target_power" == null

# --- Verify required fields are unchanged after null clears ---

GET http://localhost:8080/api/v1/calendar?startDate=2026-04-01&endDate=2026-04-30
HTTP 200
[Asserts]
jsonpath "$.planned_activities[0].title" == "Full Detail Ride"
jsonpath "$.planned_activities[0].type" == "road_biking"
jsonpath "$.planned_activities[0].start_time" startsWith "2026-04-15"

# =============================================
# PART 2: Re-populate fields, then clear to "" and 0
# =============================================

# --- PATCH: Re-populate all nullable fields ---

PATCH http://localhost:8080/api/v1/activities/plan
Content-Type: application/json
{
  "id": "{{activity_id}}",
  "description": "Repopulated description for zero test.",
  "plannedDistanceMeter": 20000,
  "plannedDurationSecond": 3600,
  "plannedElevationGainMeter": 300,
  "targetAverageSpeedMeterPerSecond": 7.5,
  "targetPowerWatt": 190
}
HTTP 200
[Asserts]
jsonpath "$.message" == "Planned activity updated"

# --- Verify all fields are repopulated ---

GET http://localhost:8080/api/v1/calendar?startDate=2026-04-01&endDate=2026-04-30
HTTP 200
[Asserts]
jsonpath "$.planned_activities[0].description" == "Repopulated description for zero test."
jsonpath "$.planned_activities[0].planned_distance" == 20000.0
jsonpath "$.planned_activities[0].planned_duration" == 3600
jsonpath "$.planned_activities[0].planned_elevation_gain" == 300.0
jsonpath "$.planned_activities[0].target_avg_speed" == 7.5
jsonpath "$.planned_activities[0].target_power" == 190

# --- PATCH: Clear description to empty string ---

PATCH http://localhost:8080/api/v1/activities/plan
Content-Type: application/json
{
  "id": "{{activity_id}}",
  "description": ""
}
HTTP 200
[Asserts]
jsonpath "$.message" == "Planned activity updated"

# --- Verify description is empty string ---

GET http://localhost:8080/api/v1/calendar?startDate=2026-04-01&endDate=2026-04-30
HTTP 200
[Asserts]
jsonpath "$.planned_activities[0].description" == ""

# --- PATCH: Clear all nullable numeric fields to 0 ---

PATCH http://localhost:8080/api/v1/activities/plan
Content-Type: application/json
{
  "id": "{{activity_id}}",
  "plannedDistanceMeter": 0,
  "plannedDurationSecond": 0,
  "plannedElevationGainMeter": 0,
  "targetAverageSpeedMeterPerSecond": 0,
  "targetPowerWatt": 0
}
HTTP 200
[Asserts]
jsonpath "$.message" == "Planned activity updated"

# --- Verify numeric fields are 0 (not null) ---

GET http://localhost:8080/api/v1/calendar?startDate=2026-04-01&endDate=2026-04-30
HTTP 200
[Asserts]
jsonpath "$.planned_activities[0].planned_distance" == 0.0
jsonpath "$.planned_activities[0].planned_duration" == 0
jsonpath "$.planned_activities[0].planned_elevation_gain" == 0.0
jsonpath "$.planned_activities[0].target_avg_speed" == 0.0
jsonpath "$.planned_activities[0].target_power" == 0

# --- Verify required fields are still unchanged ---

GET http://localhost:8080/api/v1/calendar?startDate=2026-04-01&endDate=2026-04-30
HTTP 200
[Asserts]
jsonpath "$.planned_activities[0].title" == "Full Detail Ride"
jsonpath "$.planned_activities[0].type" == "road_biking"
jsonpath "$.planned_activities[0].start_time" startsWith "2026-04-15"

# =============================================
# PART 3: Cannot null required fields
# =============================================

PATCH http://localhost:8080/api/v1/activities/plan
Content-Type: application/json
{
  "id": "{{activity_id}}",
  "title": null
}
HTTP 400
[Asserts]
jsonpath "$.error" == "Title cannot be null"

PATCH http://localhost:8080/api/v1/activities/plan
Content-Type: application/json
{
  "id": "{{activity_id}}",
  "activityType": null
}
HTTP 400
[Asserts]
jsonpath "$.error" == "Activity type cannot be null"

PATCH http://localhost:8080/api/v1/activities/plan
Content-Type: application/json
{
  "id": "{{activity_id}}",
  "startTime": null
}
HTTP 400
[Asserts]
jsonpath "$.error" == "Start time cannot be null"
