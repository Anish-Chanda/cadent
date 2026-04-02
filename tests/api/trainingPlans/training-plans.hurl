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
jsonpath "$[0].primary_sport" exists
jsonpath "$[0].difficulty" exists
jsonpath "$[0].duration_weeks" exists

### Filter by valid sport running
GET http://localhost:8080/api/v1/training-plans?sport=running
HTTP 200
[Asserts]
jsonpath "$" isCollection
jsonpath "$" count >= 2
jsonpath "$[*].primary_sport" contains "running"

### Filter by valid sport road_biking
GET http://localhost:8080/api/v1/training-plans?sport=road_biking
HTTP 200
[Asserts]
jsonpath "$" isCollection

### Invalid sport filter fails with 400
GET http://localhost:8080/api/v1/training-plans?sport=invalid_sport
HTTP 400
[Asserts]
jsonpath "$.error" contains "Invalid sport filter"

### Search by known term marathon
GET http://localhost:8080/api/v1/training-plans?q=marathon
HTTP 200
[Asserts]
jsonpath "$" isCollection
jsonpath "$" count >= 1
jsonpath "$[*].title" contains "Hal Higdon Intermediate 1 Marathon"

### Combined search and sport filter for 10K running plans
GET http://localhost:8080/api/v1/training-plans?q=10K&sport=running
HTTP 200
[Captures]
ten_k_plan_id: jsonpath "$[0].id"
[Asserts]
jsonpath "$" isCollection
jsonpath "$" count >= 1
jsonpath "$[0].primary_sport" == "running"
jsonpath "$[0].title" contains "10K"

### Search with non-existent term returns empty collection
GET http://localhost:8080/api/v1/training-plans?q=no-plan-matches-this-term-123456
HTTP 200
[Asserts]
jsonpath "$" isCollection
jsonpath "$" count == 0
