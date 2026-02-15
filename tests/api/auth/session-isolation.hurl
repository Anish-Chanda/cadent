# Setup: Create and authenticate first user
#include /api/common/authenticated-user.hurl
#options variable: test_email=user1-{{newUuid}}@test.com
#options variable: test_password=password123
#options variable: test_name=User One
#include-begin
# Creates and authenticates a test user
# Requires: test_email, test_password, test_name
# Sets: user_id, JWT cookie

# Create user
POST http://localhost:8080/signup
Content-Type: application/json
[Options]
variable: test_email=user1-{{newUuid}}@test.com
variable: test_password=password123
variable: test_name=User One
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

[Captures]
user1_id: variable "user_id"
user1_email: variable "test_email"

# Test 1: Verify User 1 can access their own data
GET http://localhost:8080/v1/user
HTTP 200
[Asserts]
jsonpath "$.id" == "{{user1_id}}"
jsonpath "$.email" == "{{user1_email}}"

# Test 2: Create and authenticate second user
#include /api/common/authenticated-user.hurl
#options variable: test_email=user2-{{newUuid}}@test.com
#options variable: test_password=password456
#options variable: test_name=User Two
#include-begin
# Creates and authenticates a test user
# Requires: test_email, test_password, test_name
# Sets: user_id, JWT cookie

# Create user
POST http://localhost:8080/signup
Content-Type: application/json
[Options]
variable: test_email=user2-{{newUuid}}@test.com
variable: test_password=password456
variable: test_name=User Two
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

[Captures]
user2_id: variable "user_id"
user2_email: variable "test_email"

# Test 3: Verify User 2 sees their own data, not User 1's
GET http://localhost:8080/v1/user
HTTP 200
[Asserts]
jsonpath "$.id" == "{{user2_id}}"
jsonpath "$.email" == "{{user2_email}}"
# Ensure we're NOT seeing user1's data
jsonpath "$.id" != "{{user1_id}}"
jsonpath "$.email" != "{{user1_email}}"

# Test 4: Verify User 2 only sees their own activities
GET http://localhost:8080/v1/activities
HTTP 200
[Asserts]
# Should be empty for new user
jsonpath "$.activities" count == 0

# Test 5: Update User 2's profile - should not affect User 1
PATCH http://localhost:8080/v1/user
Content-Type: application/json
{
    "name": "Updated User Two"
}
HTTP 200
[Asserts]
jsonpath "$.id" == "{{user2_id}}"

# Test 6: Re-authenticate as User 1 and verify their data is unchanged
POST http://localhost:8080/auth/local/login
[Form]
user: {{user1_email}}
passwd: password123
HTTP 200
[Asserts]
cookie "JWT" exists

GET http://localhost:8080/v1/user
HTTP 200
[Asserts]
jsonpath "$.id" == "{{user1_id}}"
jsonpath "$.email" == "{{user1_email}}"
jsonpath "$.name" == "User One"
# Ensure User 1's data was NOT affected by User 2's update
jsonpath "$.name" != "Updated User Two"

# Test 7: Session cookie properly isolates users
# Verify that switching sessions changes the user context
POST http://localhost:8080/auth/local/login
[Form]
user: {{user2_email}}
passwd: password456
HTTP 200

GET http://localhost:8080/v1/user
HTTP 200
[Asserts]
jsonpath "$.id" == "{{user2_id}}"

POST http://localhost:8080/auth/local/login
[Form]
user: {{user1_email}}
passwd: password123
HTTP 200

GET http://localhost:8080/v1/user
HTTP 200
[Asserts]
jsonpath "$.id" == "{{user1_id}}"
