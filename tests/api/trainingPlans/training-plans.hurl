# Authentication required for listing training plans
GET http://localhost:8080/api/v1/training-plans
HTTP 401

### Setup: Create isolated user
POST http://localhost:8080/api/signup
Content-Type: application/json
{
    "user": "tp_{{now}}@test.com",
    "passwd": "Training123!",
    "name": "TP User"
}
HTTP 201

### Login
POST http://localhost:8080/api/auth/local/login
[Form]
user: tp_{{now}}@test.com
passwd: Training123!
HTTP 200
[Asserts]
cookie "JWT" exists

### Return all training plans
GET http://localhost:8080/api/v1/training-plans
HTTP 200
[Captures]
first_plan_id: jsonpath "$[0].id"
[Asserts]
jsonpath "$" isCollection
jsonpath "$" count >= 2
jsonpath "$[0].id" exists
jsonpath "$[0].title" exists
jsonpath "$[0].primary_activity_type" exists
jsonpath "$[0].difficulty" exists
jsonpath "$[0].duration_weeks" exists

### Filter by valid activity_type running
GET http://localhost:8080/api/v1/training-plans?activity_type=running
HTTP 200
[Asserts]
jsonpath "$" isCollection
jsonpath "$" count >= 2
jsonpath "$[*].primary_activity_type" contains "running"

### Filter by valid activity_type road_biking
GET http://localhost:8080/api/v1/training-plans?activity_type=road_biking
HTTP 200
[Asserts]
jsonpath "$" isCollection

### Invalid activity_type filter fails with 400
GET http://localhost:8080/api/v1/training-plans?activity_type=invalid_sport
HTTP 400
[Asserts]
jsonpath "$.error" contains "Invalid activity_type filter"

### Search by known term marathon
GET http://localhost:8080/api/v1/training-plans?q=marathon
HTTP 200
[Asserts]
jsonpath "$" isCollection
jsonpath "$" count >= 1
jsonpath "$[*].title" contains "Hal Higdon Intermediate 1 Marathon"

### Combined search and activity_type filter for 10K running plans
GET http://localhost:8080/api/v1/training-plans?q=10K&activity_type=running
HTTP 200
[Captures]
ten_k_plan_id: jsonpath "$[0].id"
[Asserts]
jsonpath "$" isCollection
jsonpath "$" count >= 1
jsonpath "$[0].primary_activity_type" == "running"
jsonpath "$[0].title" contains "10K"

### Search with non-existent term returns empty collection
GET http://localhost:8080/api/v1/training-plans?q=no-plan-matches-this-term-123456
HTTP 200
[Asserts]
jsonpath "$" isCollection
jsonpath "$" count == 0
