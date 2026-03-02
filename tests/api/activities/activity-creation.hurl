# Activity Creation E2E Tests
# Comprehensive validation of POST /v1/activities endpoint

### Setup: Create test user for activity testing
POST http://localhost:8080/api/signup
Content-Type: application/json
{
    "user": "activity_creator_{{now}}@test.com",
    "passwd": "CreateTest123!",
    "name": "Activity Creator"
}

HTTP 201

POST http://localhost:8080/api/auth/local/login
[Form]
user: activity_creator_{{now}}@test.com
passwd: CreateTest123!

HTTP 200


### Test 1: Create activity with campus loop data
# This is the primary test - validates all calculated metrics with real 220-point GPS data
# Expected: ~2.28km distance, ~414s duration, road_bike type, complete metrics
POST http://localhost:8080/api/v1/activities
Content-Type: application/json
file,tests/campus_loop_220pts.test.json;

HTTP 201
[Captures]
campus_loop_id: jsonpath "$.id"
[Asserts]
# Basic fields
jsonpath "$.id" exists
jsonpath "$.id" matches /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/
jsonpath "$.type" == "road_bike"
jsonpath "$.title" == "Campus Loop"
jsonpath "$.description" contains "Test activity"
jsonpath "$.description" contains "220 GPS points"

# Distance validation (API calculates: ~2279m - matches expected 2.28km!)
jsonpath "$.stats.distance_m" exists
jsonpath "$.stats.distance_m" > 2250
jsonpath "$.stats.distance_m" < 2300

# Duration validation (should be 414s)
jsonpath "$.stats.elapsed_seconds" exists
jsonpath "$.stats.elapsed_seconds" == 414

# Speed validation (API calculates: 5.50 m/s)
jsonpath "$.stats.avg_speed_ms" exists
jsonpath "$.stats.avg_speed_ms" > 5.4
jsonpath "$.stats.avg_speed_ms" < 5.6

# Elevation metrics (Valhalla calculated)
jsonpath "$.stats.elevation_gain_m" exists
jsonpath "$.stats.elevation_gain_m" > 15
jsonpath "$.stats.elevation_gain_m" < 25

jsonpath "$.stats.elevation_loss_m" exists
jsonpath "$.stats.elevation_loss_m" > 15
jsonpath "$.stats.elevation_loss_m" < 25

# Coordinates and bounding box
jsonpath "$.start.lat" exists
jsonpath "$.start.lat" == 42.02888

jsonpath "$.start.lon" exists
jsonpath "$.start.lon" == -93.64974

jsonpath "$.bbox.min_lat" exists
jsonpath "$.bbox.max_lat" exists
jsonpath "$.bbox.min_lon" exists
jsonpath "$.bbox.max_lon" exists

# Polyline encoding
jsonpath "$.polyline" exists

# Timestamps
jsonpath "$.start_time" exists
jsonpath "$.end_time" exists
jsonpath "$.created_at" exists
jsonpath "$.updated_at" exists

# Processing metadata
jsonpath "$.processing_ver" exists


### Test 2: Create running activity with real GPS data
# Validates running activity with 2042 GPS points from actual Strava export by @Truman-Patterson
# Tests realistic data processing and metric calculations
# Expected: ~8.16km distance, ~2129s duration (35.5 min), running activity
POST http://localhost:8080/api/v1/activities
Content-Type: application/json
file,tests/afternoon_run.test.json;

HTTP 201
[Captures]
afternoon_run_id: jsonpath "$.id"
[Asserts]
# Basic fields
jsonpath "$.id" exists
jsonpath "$.id" matches /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/
jsonpath "$.type" == "run"
jsonpath "$.title" == "Afternoon Run"
jsonpath "$.description" contains "Test running activity"

# Distance validation (~8158m ≈ 8.16km)
jsonpath "$.stats.distance_m" exists
jsonpath "$.stats.distance_m" > 8100
jsonpath "$.stats.distance_m" < 8200

# Duration validation (should be 2129s)
jsonpath "$.stats.elapsed_seconds" exists
jsonpath "$.stats.elapsed_seconds" == 2129

# Speed validation (~3.83 m/s typical running pace)
jsonpath "$.stats.avg_speed_ms" exists
jsonpath "$.stats.avg_speed_ms" > 3.7
jsonpath "$.stats.avg_speed_ms" < 4.0

# Elevation metrics
jsonpath "$.stats.elevation_gain_m" exists
jsonpath "$.stats.elevation_gain_m" > 38
jsonpath "$.stats.elevation_gain_m" < 45

jsonpath "$.stats.elevation_loss_m" exists
jsonpath "$.stats.elevation_loss_m" > 44
jsonpath "$.stats.elevation_loss_m" < 50

# Coordinates and bounding box
jsonpath "$.start.lat" exists
jsonpath "$.start.lat" == 42.019797

jsonpath "$.start.lon" exists
jsonpath "$.start.lon" == -93.644527

jsonpath "$.bbox.min_lat" exists
jsonpath "$.bbox.max_lat" exists
jsonpath "$.bbox.min_lon" exists
jsonpath "$.bbox.max_lon" exists

# Polyline encoding
jsonpath "$.polyline" exists

# Timestamps
jsonpath "$.start_time" exists
jsonpath "$.end_time" exists
jsonpath "$.created_at" exists
jsonpath "$.updated_at" exists

# Processing metadata
jsonpath "$.processing_ver" exists


### Test 3: Idempotency - duplicate client_activity_id
POST http://localhost:8080/api/v1/activities
Content-Type: application/json
file,tests/campus_loop_220pts.test.json;

HTTP 409


### Test 4: Authentication required
# Logout first to test unauthorized access
GET http://localhost:8080/api/auth/logout

HTTP 200

POST http://localhost:8080/api/v1/activities
Content-Type: application/json
{
    "client_activity_id": "c1d2e3f4-a5b6-4c7d-8e9f-0a1b2c3d4e5f",
    "activity_type": "run",
    "title": "Unauth Test",
    "samples": [
        { "t": 1771092000000, "lat": 42.02888, "lon": -93.64974 },
        { "t": 1771092010000, "lat": 42.02890, "lon": -93.64976 }
    ]
}

HTTP 401


### Test 5: Insufficient samples (< 2 points)
POST http://localhost:8080/api/auth/local/login
[Form]
user: activity_creator_{{now}}@test.com
passwd: CreateTest123!

HTTP 200

POST http://localhost:8080/api/v1/activities
Content-Type: application/json
{
    "client_activity_id": "d2e3f4a5-b6c7-4d8e-9f0a-1b2c3d4e5f6a",
    "activity_type": "run",
    "title": "Single Sample",
    "samples": [
        { "t": 1771092000000, "lat": 42.02888, "lon": -93.64974 }
    ]
}

HTTP 400


### Test 6: Invalid activity type
POST http://localhost:8080/api/v1/activities
Content-Type: application/json
{
    "client_activity_id": "e3f4a5b6-c7d8-4e9f-a0b1-c2d3e4f5a6b7",
    "activity_type": "skateboarding",
    "title": "Invalid Type Test",
    "samples": [
        { "t": 1771092000000, "lat": 42.02888, "lon": -93.64974 },
        { "t": 1771092010000, "lat": 42.02890, "lon": -93.64976 }
    ]
}

HTTP 400


### Test 7: Minimal valid activity (2 samples) - also validates optional description field
POST http://localhost:8080/api/v1/activities
Content-Type: application/json
{
    "client_activity_id": "{{newUuid}}",
    "activity_type": "run",
    "title": "Minimal Run",
    "description": "A minimal two-sample activity",
    "samples": [
        { "t": 1771092000000, "lat": 42.02888, "lon": -93.64974 },
        { "t": 1771092010000, "lat": 42.02898, "lon": -93.64980 }
    ]
}

HTTP 201
[Asserts]
jsonpath "$.id" exists
jsonpath "$.type" == "run"
jsonpath "$.title" == "Minimal Run"
jsonpath "$.description" == "A minimal two-sample activity"
jsonpath "$.stats.distance_m" > 0
jsonpath "$.stats.elapsed_seconds" == 10



### Test 8: Missing required field (client_activity_id)
POST http://localhost:8080/api/v1/activities
Content-Type: application/json
{
    "activity_type": "run",
    "title": "No Client ID",
    "samples": [
        { "t": 1771092000000, "lat": 42.02888, "lon": -93.64974 },
        { "t": 1771092010000, "lat": 42.02890, "lon": -93.64976 }
    ]
}

HTTP 400


### Test 9: Missing required field (activity_type)
POST http://localhost:8080/api/v1/activities
Content-Type: application/json
{
    "client_activity_id": "b6c7d8e9-f0a1-4b2c-d3e4-f5a6b7c8d9e0",
    "title": "No Type",
    "samples": [
        { "t": 1771092000000, "lat": 42.02888, "lon": -93.64974 },
        { "t": 1771092010000, "lat": 42.02890, "lon": -93.64976 }
    ]
}

HTTP 400


### Test 10: Missing required field (samples)
POST http://localhost:8080/api/v1/activities
Content-Type: application/json
{
    "client_activity_id": "c7d8e9f0-a1b2-4c3d-e4f5-a6b7c8d9e0f1",
    "activity_type": "run",
    "title": "No Samples"
}

HTTP 400


### Test 11: Invalid sample (missing timestamp)
POST http://localhost:8080/api/v1/activities
Content-Type: application/json
{
    "client_activity_id": "d8e9f0a1-b2c3-4d4e-f5a6-b7c8d9e0f1a2",
    "activity_type": "run",
    "title": "Invalid Sample",
    "samples": [
        { "lat": 42.02888, "lon": -93.64974 },
        { "t": 1771092010000, "lat": 42.02890, "lon": -93.64976 }
    ]
}

HTTP 400


### Test 12: Invalid sample (missing coordinates)
POST http://localhost:8080/api/v1/activities
Content-Type: application/json
{
    "client_activity_id": "e9f0a1b2-c3d4-4e5f-a6b7-c8d9e0f1a2b3",
    "activity_type": "run",
    "title": "Missing Coords",
    "samples": [
        { "t": 1771092000000, "lat": 42.02888 },
        { "t": 1771092010000, "lat": 42.02890, "lon": -93.64976 }
    ]
}

HTTP 400


### Test 13: Empty title (should be allowed)
POST http://localhost:8080/api/v1/activities
Content-Type: application/json
{
    "client_activity_id": "{{newUuid}}",
    "activity_type": "run",
    "title": "",
    "samples": [
        { "t": 1771092000000, "lat": 42.02888, "lon": -93.64974 },
        { "t": 1771092010000, "lat": 42.02890, "lon": -93.64976 }
    ]
}

HTTP 201
[Asserts]
jsonpath "$.title" == ""


### Test 14: Malformed JSON (unparseable body)
POST http://localhost:8080/api/v1/activities
Content-Type: application/json
`{invalid json}`

HTTP 400
