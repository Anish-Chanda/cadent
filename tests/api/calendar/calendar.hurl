# Activity Calendar E2E Tests
# Tests GET /api/v1/calendar endpoint with uploads + planned activities

### Setup: Create isolated user
POST http://localhost:8080/api/signup
Content-Type: application/json
{
    "user": "calendar_e2e_{{now}}@test.com",
    "passwd": "Calendar123!",
    "name": "Calendar E2E User"
}

HTTP 201

### Authentication required for calendar endpoint
GET http://localhost:8080/api/v1/calendar?startDate=2000-01-01&endDate=2100-01-01

HTTP 401

### Login
POST http://localhost:8080/api/auth/local/login
[Form]
user: calendar_e2e_{{now}}@test.com
passwd: Calendar123!

HTTP 200
[Asserts]
cookie "JWT" exists

### Upload mcfarland activity (road bike)
POST http://localhost:8080/api/v1/activities/upload
[Multipart]
file: file,tests/mcfarland_bike_ride.gpx; application/octet-stream
enrich: false

HTTP 201
[Captures]
mcfarland_activity_id: jsonpath "$.id"
[Asserts]
jsonpath "$.id" matches /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/

### Upload second activity from different file/date (run)
POST http://localhost:8080/api/v1/activities/upload
[Multipart]
file: file,tests/Morning_Run.fit; application/octet-stream
enrich: false
title: Calendar Morning Run

HTTP 201
[Captures]
morning_run_activity_id: jsonpath "$.id"
[Asserts]
jsonpath "$.id" matches /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/

### Create planned road bike activity
POST http://localhost:8080/api/v1/activities/plan
Content-Type: application/json
{
    "title": "Planned Tempo Ride",
    "description": "Steady tempo effort",
    "activityType": "road_biking",
    "startTime": "2026-03-10T07:30:00Z",
    "plannedDistanceMeter": 25000,
    "plannedDurationSecond": 3600,
    "plannedElevationGainMeter": 120,
    "targetAverageSpeedMeterPerSecond": 6.94,
    "targetPowerWatt": 185
}

HTTP 201
[Captures]
plan_ride_id: jsonpath "$.id"
[Asserts]
jsonpath "$.id" matches /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/

### Create planned run activity
POST http://localhost:8080/api/v1/activities/plan
Content-Type: application/json
{
    "title": "Planned Progression Run",
    "description": "Easy to moderate progression",
    "activityType": "running",
    "startTime": "2026-03-12T18:15:00Z",
    "plannedDistanceMeter": 10000,
    "plannedDurationSecond": 3000,
    "plannedElevationGainMeter": 80,
    "targetAverageSpeedMeterPerSecond": 3.5
}

HTTP 201
[Captures]
plan_run_id: jsonpath "$.id"
[Asserts]
jsonpath "$.id" matches /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/

### Get calendar and verify returned content (not only counts)
GET http://localhost:8080/api/v1/calendar?startDate=2000-01-01&endDate=2100-01-01

HTTP 200
[Asserts]
jsonpath "$.activities" isCollection
jsonpath "$.activities" count == 2
jsonpath "$.activities[*].id" contains "{{mcfarland_activity_id}}"
jsonpath "$.activities[*].id" contains "{{morning_run_activity_id}}"
jsonpath "$.activities[*].title" contains "Bike ride to McFarland"
jsonpath "$.activities[*].title" contains "Calendar Morning Run"
jsonpath "$.activities[*].type" contains "road_biking"
jsonpath "$.activities[*].type" contains "running"
jsonpath "$.activities[*].stats.distance_m" count == 2
jsonpath "$.activities[*].stats.elapsed_seconds" count == 2

jsonpath "$.planned_activities" isCollection
jsonpath "$.planned_activities" count == 2
jsonpath "$.planned_activities[*].id" contains "{{plan_ride_id}}"
jsonpath "$.planned_activities[*].id" contains "{{plan_run_id}}"
jsonpath "$.planned_activities[*].title" contains "Planned Tempo Ride"
jsonpath "$.planned_activities[*].title" contains "Planned Progression Run"
jsonpath "$.planned_activities[*].type" contains "road_biking"
jsonpath "$.planned_activities[*].type" contains "running"
jsonpath "$.planned_activities[*].planned_distance_m" contains 25000
jsonpath "$.planned_activities[*].planned_distance_m" contains 10000
jsonpath "$.planned_activities[*].planned_duration_s" contains 3600
jsonpath "$.planned_activities[*].planned_duration_s" contains 3000
jsonpath "$.planned_activities[*].start_time" contains "2026-03-10T07:30:00Z"
jsonpath "$.planned_activities[*].start_time" contains "2026-03-12T18:15:00Z"

### Date range with no matching planned activities
GET http://localhost:8080/api/v1/calendar?startDate=2013-06-12&endDate=2013-06-12

HTTP 200
[Asserts]
jsonpath "$.activities" count == 0
jsonpath "$.planned_activities" count == 0

### Invalid start date format
GET http://localhost:8080/api/v1/calendar?startDate=12-06-2013&endDate=2013-06-12

HTTP 400

### Invalid end date format
GET http://localhost:8080/api/v1/calendar?startDate=2013-06-12&endDate=12-06-2013

HTTP 400

### Missing start date
GET http://localhost:8080/api/v1/calendar?endDate=2013-06-12

HTTP 400

### Missing end date
GET http://localhost:8080/api/v1/calendar?startDate=2013-06-12

HTTP 400

### End date before start date
GET http://localhost:8080/api/v1/calendar?startDate=2013-06-12&endDate=2012-06-12

HTTP 400