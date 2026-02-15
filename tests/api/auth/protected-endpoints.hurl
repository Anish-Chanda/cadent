# Test 1: Access protected endpoint without authentication - GET /v1/user
GET http://localhost:8080/v1/user
HTTP 401

# Test 2: Access protected endpoint without authentication - PATCH /v1/user
PATCH http://localhost:8080/v1/user
Content-Type: application/json
{
    "name": "Unauthorized Update"
}
HTTP 401

# Test 3: Access protected endpoint without authentication - GET /v1/activities
GET http://localhost:8080/v1/activities
HTTP 401

# Test 4: Access protected endpoint without authentication - POST /v1/activities
POST http://localhost:8080/v1/activities
Content-Type: application/json
{
    "type": "run",
    "name": "Morning Run"
}
HTTP 401

# Setup: Create and login a test user for authenticated access tests
#include /api/common/authenticated-user.hurl
#options variable: test_email=protected-test-{{newUuid}}@test.com
#options variable: test_password=password123
#options variable: test_name=Protected Test User
#include-begin
# Creates and authenticates a test user
# Requires: test_email, test_password, test_name
# Sets: user_id, JWT cookie

# Create user
POST http://localhost:8080/signup
Content-Type: application/json
[Options]
variable: test_email=protected-test-{{newUuid}}@test.com
variable: test_password=password123
variable: test_name=Protected Test User
{
    "user": "{{test_email}}",
    "passwd": "{{test_password}}",
    "name": "{{test_name}}"
}
HTTP 201
[Captures]
user_id: jsonpath "$.user_id"
[Asserts]
jsonpath "$.success" == true
jsonpath "$.user_id" exists
jsonpath "$.message" == "User created successfully"

# Login with the created user
POST http://localhost:8080/auth/local/login
[Form]
user: {{test_email}}
passwd: {{test_password}}
HTTP 200
[Asserts]
cookie "JWT" exists
cookie "JWT[HttpOnly]" exists
cookie "JWT[Path]" == "/"
#include-end

# Test 5: Verify authenticated access works - GET /v1/user
GET http://localhost:8080/v1/user
HTTP 200
[Asserts]
jsonpath "$.id" == "{{user_id}}"
jsonpath "$.email" == "{{test_email}}"
jsonpath "$.name" == "{{test_name}}"

# Test 6: Verify authenticated access works - GET /v1/activities
GET http://localhost:8080/v1/activities
HTTP 200
[Asserts]
jsonpath "$.activities" count == 0
