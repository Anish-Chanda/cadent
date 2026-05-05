GET http://localhost:8080/api/v1/training-plans/00000000-0000-0000-0000-000000000000/workouts
HTTP 401

### Setup: Create isolated user
POST http://localhost:8080/api/signup
Content-Type: application/json
{
    "user": "tpwk_{{now}}@test.com",
    "passwd": "Training123!",
    "name": "TPWK User"
}
HTTP 201

### Login
POST http://localhost:8080/api/auth/local/login
[Form]
user: tpwk_{{now}}@test.com
passwd: Training123!
HTTP 200
[Asserts]
cookie "JWT" exists

GET http://localhost:8080/api/v1/training-plans?q=Hal%20Higdon%20Intermediate%2010K&sport=running
HTTP 200
[Captures]
plan_id: jsonpath "$[0].id"
[Asserts]
jsonpath "$" isCollection
jsonpath "$" count >= 1
jsonpath "$[0].id" exists

### Test 3: Get workouts for valid training plan
GET http://localhost:8080/api/v1/training-plans/{{plan_id}}/workouts
HTTP 200
[Captures]
first_workout_plan_id: jsonpath "$[0].training_plan_id"
[Asserts]
jsonpath "$" isCollection
jsonpath "$" count >= 50
jsonpath "$[0].training_plan_id" == "{{plan_id}}"
jsonpath "$[0].sequence_index" == 1
jsonpath "$[1].sequence_index" == 2
jsonpath "$[0].template_day_offset" == 0
jsonpath "$[1].template_day_offset" == 1
jsonpath "$[*].type" contains "running"
jsonpath "$[*].type" contains "rest"

### Test 4: Valid but non-existent plan ID returns empty list
GET http://localhost:8080/api/v1/training-plans/00000000-0000-0000-0000-000000000000/workouts
HTTP 200
[Asserts]
jsonpath "$" isCollection
jsonpath "$" count == 0

### Test 5: Invalid UUID should fail cleanly
GET http://localhost:8080/api/v1/training-plans/invalid-uuid-abc/workouts
HTTP 500
[Asserts]
jsonpath "$.error" exists
