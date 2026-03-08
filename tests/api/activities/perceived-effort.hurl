# Perceived Effort E2E Tests
# Validates perceived_effort field handling in POST /v1/activities endpoint

### Setup: Create test user for perceived effort testing
POST http://localhost:8080/api/signup
Content-Type: application/json
{
    "user": "perceived_effort_tester_{{now}}@test.com",
    "passwd": "EffortTest123!",
    "name": "Effort Tester"
}

HTTP 201

POST http://localhost:8080/api/auth/local/login
[Form]
user: perceived_effort_tester_{{now}}@test.com
passwd: EffortTest123!

HTTP 200


### Test 1: Create activity with valid perceived_effort (7)
# Validates that perceived_effort in valid range is accepted and returned correctly
POST http://localhost:8080/api/v1/activities
Content-Type: application/json
{
    "client_activity_id": "{{newUuid}}",
    "activity_type": "run",
    "title": "Valid Effort Run",
    "description": "Testing valid perceived_effort value",
    "perceived_effort": 7,
    "samples": [
        { "t": 1771092000000, "lat": 42.02888, "lon": -93.64974 },
        { "t": 1771092010000, "lat": 42.02898, "lon": -93.64980 }
    ]
}

HTTP 201
[Captures]
valid_effort_id: jsonpath "$.id"
[Asserts]
jsonpath "$.id" exists
jsonpath "$.perceived_effort" == 7
jsonpath "$.title" == "Valid Effort Run"


### Test 2: Create activity with minimum valid perceived_effort (1)
POST http://localhost:8080/api/v1/activities
Content-Type: application/json
{
    "client_activity_id": "{{newUuid}}",
    "activity_type": "road_bike",
    "title": "Minimum Effort Bike",
    "description": "Testing minimum perceived_effort value",
    "perceived_effort": 1,
    "samples": [
        { "t": 1771092000000, "lat": 42.02888, "lon": -93.64974 },
        { "t": 1771092010000, "lat": 42.02898, "lon": -93.64980 }
    ]
}

HTTP 201
[Asserts]
jsonpath "$.id" exists
jsonpath "$.perceived_effort" == 1


### Test 3: Create activity with maximum valid perceived_effort (10)
POST http://localhost:8080/api/v1/activities
Content-Type: application/json
{
    "client_activity_id": "{{newUuid}}",
    "activity_type": "run",
    "title": "Maximum Effort Run",
    "description": "Testing maximum perceived_effort value",
    "perceived_effort": 10,
    "samples": [
        { "t": 1771092000000, "lat": 42.02888, "lon": -93.64974 },
        { "t": 1771092010000, "lat": 42.02898, "lon": -93.64980 }
    ]
}

HTTP 201
[Asserts]
jsonpath "$.id" exists
jsonpath "$.perceived_effort" == 10


### Test 4: Create activity without perceived_effort (null)
# Validates that perceived_effort is optional and correctly handled when omitted
POST http://localhost:8080/api/v1/activities
Content-Type: application/json
{
    "client_activity_id": "{{newUuid}}",
    "activity_type": "run",
    "title": "No Effort Specified",
    "description": "Testing omitted perceived_effort field",
    "samples": [
        { "t": 1771092000000, "lat": 42.02888, "lon": -93.64974 },
        { "t": 1771092010000, "lat": 42.02898, "lon": -93.64980 }
    ]
}

HTTP 201
[Captures]
null_effort_id: jsonpath "$.id"
[Asserts]
jsonpath "$.id" exists
jsonpath "$.title" == "No Effort Specified"
# perceived_effort should be null or not present when not provided
jsonpath "$.perceived_effort" not exists


### Test 5: Create activity with explicit null perceived_effort
POST http://localhost:8080/api/v1/activities
Content-Type: application/json
{
    "client_activity_id": "{{newUuid}}",
    "activity_type": "road_bike",
    "title": "Explicit Null Effort",
    "description": "Testing explicit null perceived_effort",
    "perceived_effort": null,
    "samples": [
        { "t": 1771092000000, "lat": 42.02888, "lon": -93.64974 },
        { "t": 1771092010000, "lat": 42.02898, "lon": -93.64980 }
    ]
}

HTTP 201
[Asserts]
jsonpath "$.id" exists
jsonpath "$.title" == "Explicit Null Effort"
jsonpath "$.perceived_effort" not exists


### Test 6: Reject activity with perceived_effort below valid range (0)
# Validates that perceived_effort = 0 is rejected with 400
POST http://localhost:8080/api/v1/activities
Content-Type: application/json
{
    "client_activity_id": "{{newUuid}}",
    "activity_type": "run",
    "title": "Invalid Low Effort",
    "description": "Testing perceived_effort = 0",
    "perceived_effort": 0,
    "samples": [
        { "t": 1771092000000, "lat": 42.02888, "lon": -93.64974 },
        { "t": 1771092010000, "lat": 42.02898, "lon": -93.64980 }
    ]
}

HTTP 400
[Asserts]
body contains "perceived_effort must be between 1 and 10"


### Test 7: Reject activity with perceived_effort above valid range (11)
# Validates that perceived_effort = 11 is rejected with 400
POST http://localhost:8080/api/v1/activities
Content-Type: application/json
{
    "client_activity_id": "{{newUuid}}",
    "activity_type": "run",
    "title": "Invalid High Effort",
    "description": "Testing perceived_effort = 11",
    "perceived_effort": 11,
    "samples": [
        { "t": 1771092000000, "lat": 42.02888, "lon": -93.64974 },
        { "t": 1771092010000, "lat": 42.02898, "lon": -93.64980 }
    ]
}

HTTP 400
[Asserts]
body contains "perceived_effort must be between 1 and 10"


### Test 8: Reject activity with negative perceived_effort (-1)
POST http://localhost:8080/api/v1/activities
Content-Type: application/json
{
    "client_activity_id": "{{newUuid}}",
    "activity_type": "road_bike",
    "title": "Negative Effort",
    "description": "Testing perceived_effort = -1",
    "perceived_effort": -1,
    "samples": [
        { "t": 1771092000000, "lat": 42.02888, "lon": -93.64974 },
        { "t": 1771092010000, "lat": 42.02898, "lon": -93.64980 }
    ]
}

HTTP 400
[Asserts]
body contains "perceived_effort must be between 1 and 10"


### Test 9: Verify retrieval of activity with perceived_effort
# Validates that perceived_effort is correctly returned when fetching activity by ID
GET http://localhost:8080/api/v1/activities/{{valid_effort_id}}

HTTP 200
[Asserts]
jsonpath "$.id" == "{{valid_effort_id}}"
jsonpath "$.perceived_effort" == 7
jsonpath "$.title" == "Valid Effort Run"


### Test 10: Verify retrieval of activity without perceived_effort
# Validates that activity without perceived_effort can be retrieved correctly
GET http://localhost:8080/api/v1/activities/{{null_effort_id}}

HTTP 200
[Asserts]
jsonpath "$.id" == "{{null_effort_id}}"
jsonpath "$.title" == "No Effort Specified"
jsonpath "$.perceived_effort" not exists
