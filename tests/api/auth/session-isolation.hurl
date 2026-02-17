# Session Isolation Tests - Users can only access their own data

# Setup: Create first user
POST http://localhost:8080/signup
Content-Type: application/json
[Options]
variable: user1_uuid={{newUuid}}
variable: user1_email=user1-{{user1_uuid}}@test.com
variable: user1_password=password123
{
    "user": "{{user1_email}}",
    "passwd": "{{user1_password}}",
    "name": "User One"
}
HTTP 201
[Captures]
user1_id: jsonpath "$.user_id"

POST http://localhost:8080/auth/local/login
[Form]
user: {{user1_email}}
passwd: {{user1_password}}
HTTP 200
[Asserts]
cookie "JWT" exists
cookie "JWT[HttpOnly]" exists
cookie "JWT[Path]" == "/"

# User 1 accesses their own data
GET http://localhost:8080/v1/user
HTTP 200
[Asserts]
jsonpath "$.id" == "{{user1_id}}"
jsonpath "$.email" == "{{user1_email}}"
jsonpath "$.name" == "User One"

# User 1 accesses their activities
GET http://localhost:8080/v1/activities
HTTP 200
[Asserts]
jsonpath "$.activities" count == 0

# Setup: Create second user
POST http://localhost:8080/signup
Content-Type: application/json
[Options]
variable: user2_uuid={{newUuid}}
variable: user2_email=user2-{{user2_uuid}}@test.com
variable: user2_password=password456
{
    "user": "{{user2_email}}",
    "passwd": "{{user2_password}}",
    "name": "User Two"
}
HTTP 201
[Captures]
user2_id: jsonpath "$.user_id"

POST http://localhost:8080/auth/local/login
[Form]
user: {{user2_email}}
passwd: {{user2_password}}
HTTP 200
[Asserts]
cookie "JWT" exists

# User 2 sees only their own data
GET http://localhost:8080/v1/user
HTTP 200
[Asserts]
jsonpath "$.id" == "{{user2_id}}"
jsonpath "$.email" == "{{user2_email}}"
jsonpath "$.name" == "User Two"
# Ensure we're NOT seeing user1's data
jsonpath "$.id" != "{{user1_id}}"
jsonpath "$.email" != "{{user1_email}}"

# User 2 sees only their own activities
GET http://localhost:8080/v1/activities
HTTP 200
[Asserts]
jsonpath "$.activities" count == 0

# Update User 2's profile
PATCH http://localhost:8080/v1/user
Content-Type: application/json
{
    "name": "Updated User Two"
}
HTTP 200
[Asserts]
jsonpath "$.id" == "{{user2_id}}"
jsonpath "$.name" == "Updated User Two"

# Re-authenticate as User 1
POST http://localhost:8080/auth/local/login
[Form]
user: {{user1_email}}
passwd: {{user1_password}}
HTTP 200
[Asserts]
cookie "JWT" exists

# Verify User 1's data unchanged
GET http://localhost:8080/v1/user
HTTP 200
[Asserts]
jsonpath "$.id" == "{{user1_id}}"
jsonpath "$.email" == "{{user1_email}}"
jsonpath "$.name" == "User One"
jsonpath "$.name" != "Updated User Two"

# Switch to User 2 session
POST http://localhost:8080/auth/local/login
[Form]
user: {{user2_email}}
passwd: {{user2_password}}
HTTP 200
[Asserts]
cookie "JWT" exists

GET http://localhost:8080/v1/user
HTTP 200
[Asserts]
jsonpath "$.id" == "{{user2_id}}"
jsonpath "$.name" == "Updated User Two"

# Switch back to User 1 session
POST http://localhost:8080/auth/local/login
[Form]
user: {{user1_email}}
passwd: {{user1_password}}
HTTP 200
[Asserts]
cookie "JWT" exists

GET http://localhost:8080/v1/user
HTTP 200
[Asserts]
jsonpath "$.id" == "{{user1_id}}"
jsonpath "$.name" == "User One"

# Unauthenticated access should fail
POST http://localhost:8080/auth/local/login
[Form]
user: invalid@test.com
passwd: wrongpassword
HTTP 401

# After failed login, protected endpoint should not be accessible
GET http://localhost:8080/v1/user
HTTP 401

# Create third user to verify no data leakage
POST http://localhost:8080/signup
Content-Type: application/json
[Options]
variable: user3_uuid={{newUuid}}
variable: user3_email=user3-{{user3_uuid}}@test.com
{
    "user": "{{user3_email}}",
    "passwd": "password789",
    "name": "User Three"
}
HTTP 201
[Captures]
user3_id: jsonpath "$.user_id"

POST http://localhost:8080/auth/local/login
[Form]
user: {{user3_email}}
passwd: password789
HTTP 200

GET http://localhost:8080/v1/user
HTTP 200
[Asserts]
jsonpath "$.id" == "{{user3_id}}"
jsonpath "$.id" != "{{user1_id}}"
jsonpath "$.id" != "{{user2_id}}"
jsonpath "$.name" == "User Three"
