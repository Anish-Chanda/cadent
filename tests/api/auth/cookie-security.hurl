# Setup: Create a test user
#include /api/common/create-test-user.hurl
#options variable: test_email=cookie-test-{{newUuid}}@test.com
#options variable: test_password=securepass123
#options variable: test_name=Cookie Security Test
#include-begin
# Creates a new test user
# Requires: test_email, test_password, test_name
# Sets: user_id

POST http://localhost:8080/signup
Content-Type: application/json
[Options]
variable: test_email=cookie-test-{{newUuid}}@test.com
variable: test_password=securepass123
variable: test_name=Cookie Security Test
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
#include-end

# Test 1: Verify JWT cookie has all required security attributes
POST http://localhost:8080/auth/local/login
[Form]
user: {{test_email}}
passwd: {{test_password}}
HTTP 200
[Asserts]
cookie "JWT" exists
cookie "JWT[HttpOnly]" exists
cookie "JWT[Path]" == "/"

# Test 2: Verify cookie persists and works across multiple requests
GET http://localhost:8080/v1/user
HTTP 200
[Asserts]
jsonpath "$.id" == "{{user_id}}"

GET http://localhost:8080/v1/activities
HTTP 200

GET http://localhost:8080/v1/user
HTTP 200
[Asserts]
jsonpath "$.id" == "{{user_id}}"
