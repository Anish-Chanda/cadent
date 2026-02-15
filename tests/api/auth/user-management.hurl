#include /api/common/authenticated-user.hurl
#options variable: test_email=usermgmt-{{newUuid}}@test.com
#options variable: test_password=userpass123
#options variable: test_name=User Management Test
#include-begin
# Creates and authenticates a test user
# Requires: test_email, test_password, test_name
# Sets: user_id, JWT cookie

# Create user
POST http://localhost:8080/signup
Content-Type: application/json
[Options]
variable: test_email=usermgmt-{{newUuid}}@test.com
variable: test_password=userpass123
variable: test_name=User Management Test
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

# Test 1: Get user information
GET http://localhost:8080/v1/user
HTTP 200
[Asserts]
jsonpath "$.id" == "{{user_id}}"
jsonpath "$.email" == "{{test_email}}"
jsonpath "$.name" == "{{test_name}}"
jsonpath "$.id" matches /^[0-9a-f-]+$/
header "Content-Type" contains "application/json"

# Test 2: Update user name
PATCH http://localhost:8080/v1/user
Content-Type: application/json
{
    "name": "Updated User Name"
}
HTTP 200
[Asserts]
jsonpath "$.name" == "Updated User Name"
jsonpath "$.id" == "{{user_id}}"

# Verify the update persisted
GET http://localhost:8080/v1/user
HTTP 200
[Asserts]
jsonpath "$.name" == "Updated User Name"
jsonpath "$.id" == "{{user_id}}"

# Test 3: Update with empty name - should be rejected
PATCH http://localhost:8080/v1/user
Content-Type: application/json
{
    "name": ""
}
HTTP 400

# Verify name wasn't changed
GET http://localhost:8080/v1/user
HTTP 200
[Asserts]
jsonpath "$.name" == "Updated User Name"

# Test 4: Invalid JSON in PATCH request
PATCH http://localhost:8080/v1/user
Content-Type: application/json
```
{invalid json}
```
HTTP 400

# Verify user data wasn't changed
GET http://localhost:8080/v1/user
HTTP 200
[Asserts]
jsonpath "$.id" == "{{user_id}}"
jsonpath "$.name" == "Updated User Name"
jsonpath "$.email" == "{{test_email}}"
