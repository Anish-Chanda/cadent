# Activity Calendar E2E Tests
# Tests GET /v1/activities/calendar endpoint

### Setup: Create test users for isolation testing
POST http://localhost:8080/api/signup
Content-Type: application/json
{
    "user": "activity_retriever_1_{{now}}@test.com",
    "passwd": "Retrieve123!",
    "name": "Retriever User 1"
}

HTTP 201

### Test 1: Authentication required for listing activities
GET http://localhost:8080/api/v1/activities

HTTP 401


### Test 2: Authenticate as User 1
POST http://localhost:8080/api/auth/local/login
[Form]
user: activity_retriever_1_{{now}}@test.com
passwd: Retrieve123!

HTTP 200

### Test 3: Get activities - should be empty initially
GET http://localhost:8080/api/v1/activities

HTTP 200
[Asserts]
jsonpath "$.activities" exists
jsonpath "$.activities" count == 0

### Test 4: Create small activity for User 1
POST http://localhost:8080/api/v1/activities
Content-Type: application/json
{
    "client_activity_id": "{{newUuid}}",
    "activity_type": "run",
    "title": "Morning Run",
    "description": "Quick jog around campus",
    "samples": [
        { "t": 1771092000000, "lat": 42.02888, "lon": -93.64974 },
        { "t": 1771092010000, "lat": 42.02898, "lon": -93.64980 },
        { "t": 1771092020000, "lat": 42.02908, "lon": -93.64990 }
    ]
}

HTTP 201
[Captures]
user1_small_activity_id: jsonpath "$.id"
[Asserts]
jsonpath "$.id" exists
jsonpath "$.type" == "run"

### Test 5: Create small planned activity for User 1
POST http://localhost:8080/api/v1/activities/plan
Content-Type: application/json
{
    "title": "First Activity",
    "description": "Afternoon run through the park",
    "activityType": "road_bike",
    "startTime": "{{now \"%Y-%m-%d\"}}",
    "plannedDistanceMeter": 25000,
    "plannedDurationSecond": 3600,
    "plannedElevationGainMeter": 120,
    "targetAverageSpeedMeterPerSecond": 6.94,
    "targetPowerWatt": 185
}

HTTP 201
[Captures]
user1_small_activity_id: jsonpath "$.id"
[Asserts]
jsonpath "$.id" exists
jsonpath "$.type" == "road_bike"

### Test 6: Get Activities in Date Range
GET http://localhost:8080/api/v1/activities/calendar?startDate="{{now \"%Y-%m-%d\"}}""&endDate="{{now \"%Y-%m-%d\"}}"

HTTP 200
[Asserts]
jsonpath "$.activities" count >= 1
jsonpath "$.activities[0].id" exists
jsonpath "$.activities[0].title" exists
jsonpath "$.activities[0].type" exists
jsonpath "$.activities[0].stats" exists
jsonpath "$.activities[0].stats.distance_m" exists
jsonpath "$.activities[0].stats.elapsed_seconds" exists
jsonpath "$.planned_activities" count >= 1
jsonpath "$.planned_activities[0].id" exists
jsonpath "$.planned_activities[0].title" exists
jsonpath "$.planned_activities[0].type" exists

### Test 7: Get Activities in Date Range - none in range
GET http://localhost:8080/api/v1/activities/calendar?startDate=2013-06-12&endDate=2013-06-12

HTTP 200
[Asserts]
jsonpath "$.activities" count == 0
jsonpath "$.activities" count == 0

### Test 8: Get Activities in Date Range - Invalid Start Date
GET http://localhost:8080/api/v1/activities/calendar?startDate=12-06-2013&endDate=2013-06-12

HTTP 400

### Test 9: Get Activities in Date Range - Invalid End Date
GET http://localhost:8080/api/v1/activities/calendar?startDate=2013-06-12&endDate=12-06-2013

HTTP 400

### Test 10: Get Activities in Date Range - Missing Start Date
GET http://localhost:8080/api/v1/activities/calendar?endDate=2013-06-12

HTTP 400

### Test 11: Get Activities in Date Range - Missing End Date
GET http://localhost:8080/api/v1/activities/calendar?startDate=2013-06-12

HTTP 400

### Test 12: Get Activities in Date Range - End Date before Start Date
GET http://localhost:8080/api/v1/activities/calendar?startDate=2013-06-12&endDate=2012-06-12

HTTP 400