# Activity Retrieval E2E Tests
# Tests GET /v1/activities and GET /v1/activities/{id}/streams endpoints

### Setup: Create test users for isolation testing
POST http://localhost:8080/signup
Content-Type: application/json
{
    "user": "activity_retriever_1_{{now}}@test.com",
    "passwd": "Retrieve123!",
    "name": "Retriever User 1"
}

HTTP 201

POST http://localhost:8080/signup
Content-Type: application/json
{
    "user": "activity_retriever_2_{{now}}@test.com",
    "passwd": "Retrieve123!",
    "name": "Retriever User 2"
}

HTTP 201


### Test 1: Authentication required for listing activities
GET http://localhost:8080/v1/activities

HTTP 401


### Test 2: Authenticate as User 1
POST http://localhost:8080/auth/local/login
[Form]
user: activity_retriever_1_{{now}}@test.com
passwd: Retrieve123!

HTTP 200


### Test 3: Get activities - should be empty initially
GET http://localhost:8080/v1/activities

HTTP 200
[Asserts]
jsonpath "$.activities" exists
jsonpath "$.activities" count == 0


### Test 4: Create small activity for User 1
POST http://localhost:8080/v1/activities
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


### Test 5: List activities - should have 1 activity
GET http://localhost:8080/v1/activities

HTTP 200
[Asserts]
jsonpath "$.activities" count >= 1
jsonpath "$.activities[0].id" exists
jsonpath "$.activities[0].title" exists
jsonpath "$.activities[0].type" exists
jsonpath "$.activities[0].stats" exists
jsonpath "$.activities[0].stats.distance_m" exists
jsonpath "$.activities[0].stats.elapsed_seconds" exists


### Test 6: Get streams for small activity
GET http://localhost:8080/v1/activities/{{user1_small_activity_id}}/streams?lod=medium&type=time,distance,elevation

HTTP 200
[Asserts]
jsonpath "$.activity_id" == "{{user1_small_activity_id}}"
jsonpath "$.lod" exists
jsonpath "$.streams" isCollection
jsonpath "$.streams" count == 3
jsonpath "$.streams[*].type" contains "time"
jsonpath "$.streams[*].type" contains "distance"
jsonpath "$.streams[*].type" contains "elevation"
jsonpath "$.streams[*].values" count == 3


### Test 7: Get streams for non-existent activity
GET http://localhost:8080/v1/activities/00000000-0000-0000-0000-000000000000/streams?lod=medium&type=time

HTTP 404


### Test 8: Get streams with invalid UUID format
GET http://localhost:8080/v1/activities/not-a-valid-uuid/streams?lod=medium&type=time

HTTP 400


### Test 9: Streams - missing lod parameter
GET http://localhost:8080/v1/activities/{{user1_small_activity_id}}/streams?type=time

HTTP 400


### Test 10: Streams - missing type parameter
GET http://localhost:8080/v1/activities/{{user1_small_activity_id}}/streams?lod=medium

HTTP 400


### Test 11: Streams - invalid lod value
GET http://localhost:8080/v1/activities/{{user1_small_activity_id}}/streams?lod=ultra&type=time

HTTP 400


### Test 12: Streams - invalid type value
GET http://localhost:8080/v1/activities/{{user1_small_activity_id}}/streams?lod=medium&type=heartrate

HTTP 400


### Test 13: Streams - lod=low (different decimation code path)
GET http://localhost:8080/v1/activities/{{user1_small_activity_id}}/streams?lod=low&type=time,distance

HTTP 200
[Asserts]
jsonpath "$.activity_id" == "{{user1_small_activity_id}}"
jsonpath "$.lod" exists
jsonpath "$.streams" isCollection


### Test 14: Streams - lod=full (not yet implemented)
GET http://localhost:8080/v1/activities/{{user1_small_activity_id}}/streams?lod=full&type=time

HTTP 501


### Test 15: Switch to User 2
POST http://localhost:8080/auth/local/login
[Form]
user: activity_retriever_2_{{now}}@test.com
passwd: Retrieve123!

HTTP 200


### Test 16: User 2 should have no activities
GET http://localhost:8080/v1/activities

HTTP 200
[Asserts]
jsonpath "$.activities" count == 0


### Test 17: User 2 cannot access User 1's activity streams (authorization test)
GET http://localhost:8080/v1/activities/{{user1_small_activity_id}}/streams?lod=medium&type=time

HTTP 404


### Test 18: Create activity for User 2
POST http://localhost:8080/v1/activities
Content-Type: application/json
{
    "client_activity_id": "{{newUuid}}",
    "activity_type": "run",
    "title": "User 2 Activity",
    "description": "Belongs to User 2 only",
    "samples": [
        { "t": 1771092000000, "lat": 42.03000, "lon": -93.65000 },
        { "t": 1771092015000, "lat": 42.03010,  "lon": -93.65010 }
    ]
}

HTTP 201
[Captures]
user2_activity_id: jsonpath "$.id"


### Test 19: User 2 can see their own activity
GET http://localhost:8080/v1/activities

HTTP 200
[Asserts]
jsonpath "$.activities" count == 1
jsonpath "$.activities[0].id" == "{{user2_activity_id}}"
jsonpath "$.activities[0].title" == "User 2 Activity"


### Test 20: User 2 can access their own streams
GET http://localhost:8080/v1/activities/{{user2_activity_id}}/streams?lod=medium&type=time,distance

HTTP 200
[Asserts]
jsonpath "$.activity_id" == "{{user2_activity_id}}"
jsonpath "$.streams" exists


### Test 21: Switch back to User 1
POST http://localhost:8080/auth/local/login
[Form]
user: activity_retriever_1_{{now}}@test.com
passwd: Retrieve123!

HTTP 200


### Test 22: User 1 still has >= 1 activity
GET http://localhost:8080/v1/activities

HTTP 200
[Asserts]
jsonpath "$.activities" count >= 1


### Test 23: User 1 cannot access User 2's streams (authorization test)
GET http://localhost:8080/v1/activities/{{user2_activity_id}}/streams?lod=medium&type=time

HTTP 404
