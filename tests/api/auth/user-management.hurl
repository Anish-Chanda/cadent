# User Management Tests - Profile CRUD operations and validation

# Setup: Create and authenticate test user
POST http://localhost:8080/api/signup
Content-Type: application/json
[Options]
variable: mgmt_uuid={{newUuid}}
variable: mgmt_email=usermgmt-{{mgmt_uuid}}@test.com
variable: mgmt_password=userpass123
{
    "user": "{{mgmt_email}}",
    "passwd": "{{mgmt_password}}",
    "name": "User Management Test"
}
HTTP 201
[Captures]
user_id: jsonpath "$.user_id"
[Asserts]
jsonpath "$.success" == true

POST http://localhost:8080/api/auth/local/login
[Form]
user: {{mgmt_email}}
passwd: {{mgmt_password}}
HTTP 200
[Asserts]
cookie "JWT" exists
cookie "JWT[HttpOnly]" exists
cookie "JWT[Path]" == "/"

# Get user information
GET http://localhost:8080/api/v1/user
HTTP 200
[Asserts]
jsonpath "$.id" == "{{user_id}}"
jsonpath "$.email" == "{{mgmt_email}}"
jsonpath "$.name" == "User Management Test"
jsonpath "$.id" matches /^[0-9a-f-]+$/
header "Content-Type" contains "application/json"

# Failed login attempt (but session persists from earlier successful login)
POST http://localhost:8080/api/auth/local/login
[Form]
user: invalid@test.com
passwd: wrong
HTTP 401

# Session still valid - failed login doesn't clear existing valid JWT cookie
GET http://localhost:8080/api/v1/user
HTTP 200
[Asserts]
jsonpath "$.id" == "{{user_id}}"
jsonpath "$.email" == "{{mgmt_email}}"

# Re-authenticate for remaining tests
POST http://localhost:8080/api/auth/local/login
[Form]
user: {{mgmt_email}}
passwd: {{mgmt_password}}
HTTP 200

# Update user name
PATCH http://localhost:8080/api/v1/user
Content-Type: application/json
{
    "name": "Updated User Name"
}
HTTP 200
[Asserts]
jsonpath "$.name" == "Updated User Name"
jsonpath "$.id" == "{{user_id}}"

# Verify update persisted
GET http://localhost:8080/api/v1/user
HTTP 200
[Asserts]
jsonpath "$.name" == "Updated User Name"
jsonpath "$.id" == "{{user_id}}"

# Update with Unicode characters
PATCH http://localhost:8080/api/v1/user
Content-Type: application/json
{
    "name": "José María 日本語"
}
HTTP 200
[Asserts]
jsonpath "$.name" == "José María 日本語"

# Update with emoji
PATCH http://localhost:8080/api/v1/user
Content-Type: application/json
{
    "name": "User 🚀 🏃‍♂️"
}
HTTP 200
[Asserts]
jsonpath "$.name" == "User 🚀 🏃‍♂️"

# Update with empty name (rejected)
PATCH http://localhost:8080/api/v1/user
Content-Type: application/json
{
    "name": ""
}
HTTP 400

# Verify name unchanged
GET http://localhost:8080/api/v1/user
HTTP 200
[Asserts]
jsonpath "$.name" == "User 🚀 🏃‍♂️"

# Update with whitespace (rejected)
PATCH http://localhost:8080/api/v1/user
Content-Type: application/json
{
    "name": "     "
}
HTTP 400

# Verify name still unchanged
GET http://localhost:8080/api/v1/user
HTTP 200
[Asserts]
jsonpath "$.name" == "User 🚀 🏃‍♂️"

# Invalid JSON request
PATCH http://localhost:8080/api/v1/user
Content-Type: application/json
```
{invalid json}
```
HTTP 400

# Verify no data corruption
GET http://localhost:8080/api/v1/user
HTTP 200
[Asserts]
jsonpath "$.id" == "{{user_id}}"
jsonpath "$.name" == "User 🚀 🏃‍♂️"
jsonpath "$.email" == "{{mgmt_email}}"

# Update with empty object (rejected)
PATCH http://localhost:8080/api/v1/user
Content-Type: application/json
{}
HTTP 400

# Update with very long name (accepted - no length limit)
PATCH http://localhost:8080/api/v1/user
Content-Type: application/json
[Options]
variable: very_long_name=ThisIsAVeryLongNameThatTestsTheMaximumLengthAllowedForUserNamesInTheSystemAbcdefghijklmnopqrstuvwxyzAbcdefghijklmnopqrstuvwxyz
{
    "name": "{{very_long_name}}"
}
HTTP 200
[Asserts]
jsonpath "$.name" == "{{very_long_name}}"

# Verify long name persisted
GET http://localhost:8080/api/v1/user
HTTP 200
[Asserts]
jsonpath "$.name" == "{{very_long_name}}"

# HTML-like characters in name
PATCH http://localhost:8080/api/v1/user
Content-Type: application/json
{
    "name": "<script>alert('xss')</script>"
}
HTTP 200
[Asserts]
jsonpath "$.name" == "<script>alert('xss')</script>"

# SQL-like characters in name
PATCH http://localhost:8080/api/v1/user
Content-Type: application/json
{
    "name": "'; DROP TABLE users; --"
}
HTTP 200
[Asserts]
jsonpath "$.name" == "'; DROP TABLE users; --"

# Final successful update
PATCH http://localhost:8080/api/v1/user
Content-Type: application/json
{
    "name": "Final Updated Name"
}
HTTP 200
[Asserts]
jsonpath "$.name" == "Final Updated Name"
jsonpath "$.id" == "{{user_id}}"
jsonpath "$.email" == "{{mgmt_email}}"
