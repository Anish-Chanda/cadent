# Test 1: Signup with very long email (exceeds RFC 5321 standard of 254 chars)
# TODO: Fix Backend
POST http://localhost:8080/signup
Content-Type: application/json
{
    "user": "verylongemailaddressthatshouldtestthemaximumlengthallowedbythevalidation@extremelylongdomainname.com",
    "passwd": "password123",
    "name": "Long Email User"
}
HTTP 400

# Test 2: Signup with Unicode characters in name
POST http://localhost:8080/signup
Content-Type: application/json
[Options]
variable: unicode_email=unicode-{{newUuid}}@test.com
{
    "user": "{{unicode_email}}",
    "passwd": "password123",
    "name": "José María Müller 日本語"
}
HTTP 201

# Verify Unicode name persists correctly
POST http://localhost:8080/auth/local/login
[Form]
user: {{unicode_email}}
passwd: password123
HTTP 200

GET http://localhost:8080/v1/user
HTTP 200
[Asserts]
jsonpath "$.name" == "José María Müller 日本語"

# Test 3: Signup with emoji in name
POST http://localhost:8080/signup
Content-Type: application/json
[Options]
variable: emoji_email=emoji-{{newUuid}}@test.com
{
    "user": "{{emoji_email}}",
    "passwd": "password123",
    "name": "Test User 🚀 🏃‍♂️"
}
HTTP 201

POST http://localhost:8080/auth/local/login
[Form]
user: {{emoji_email}}
passwd: password123
HTTP 200

GET http://localhost:8080/v1/user
HTTP 200
[Asserts]
jsonpath "$.name" == "Test User 🚀 🏃‍♂️"

# Test 4: Signup with HTML-like characters in name (XSS prevention check)
POST http://localhost:8080/signup
Content-Type: application/json
[Options]
variable: html_email=html-{{newUuid}}@test.com
{
    "user": "{{html_email}}",
    "passwd": "password123",
    "name": "<script>alert('xss')</script>"
}
HTTP 201

POST http://localhost:8080/auth/local/login
[Form]
user: {{html_email}}
passwd: password123
HTTP 200

GET http://localhost:8080/v1/user
HTTP 200
[Asserts]
# Verify the name is stored as-is (backend should not interpret it as code)
# Frontend should properly escape it when rendering
jsonpath "$.name" == "<script>alert('xss')</script>"

# Test 5: Signup with SQL-like characters in name
POST http://localhost:8080/signup
Content-Type: application/json
[Options]
variable: sql_email=sql-{{newUuid}}@test.com
{
    "user": "{{sql_email}}",
    "passwd": "password123",
    "name": "'; DROP TABLE users; --"
}
HTTP 201

POST http://localhost:8080/auth/local/login
[Form]
user: {{sql_email}}
passwd: password123
HTTP 200

GET http://localhost:8080/v1/user
HTTP 200
[Asserts]
jsonpath "$.name" == "'; DROP TABLE users; --"

# Test 6: Very long name
POST http://localhost:8080/signup
Content-Type: application/json
[Options]
variable: longname_email=longname-{{newUuid}}@test.com
variable: very_long_name=ThisIsAVeryLongNameThatTestsTheMaximumLengthAllowedForUserNamesInTheSystemAbcdefghijklmnopqrstuvwxyzAbcdefghijklmnopqrstuvwxyz
{
    "user": "{{longname_email}}",
    "passwd": "password123",
    "name": "{{very_long_name}}"
}
# Should reject names exceeding reasonable length
HTTP 400

# Test 7: Name with only whitespace (should be rejected as empty after trimming)
POST http://localhost:8080/signup
Content-Type: application/json
{
    "user": "whitespace-{{newUuid}}@test.com",
    "passwd": "password123",
    "name": "     "
}
HTTP 400

# Test 8: Email with special characters before @
POST http://localhost:8080/signup
Content-Type: application/json
[Options]
variable: special_local=special.email+tag-{{newUuid}}@test.com
{
    "user": "{{special_local}}",
    "passwd": "password123",
    "name": "Special Email User"
}
HTTP 201

POST http://localhost:8080/auth/local/login
[Form]
user: {{special_local}}
passwd: password123
HTTP 200
[Asserts]
cookie "JWT" exists

# Test 9: Password with spaces
POST http://localhost:8080/signup
Content-Type: application/json
[Options]
variable: space_pass_email=spacepass-{{newUuid}}@test.com
variable: space_password=my password has spaces
{
    "user": "{{space_pass_email}}",
    "passwd": "{{space_password}}",
    "name": "Space Password User"
}
HTTP 201

# Verify can login with password containing spaces
POST http://localhost:8080/auth/local/login
[Form]
user: {{space_pass_email}}
passwd: {{space_password}}
HTTP 200
[Asserts]
cookie "JWT" exists

# Test 10: Update user with empty object
#include /api/common/authenticated-user.hurl
#options variable: test_email=empty-update-{{newUuid}}@test.com
#options variable: test_password=password123
#options variable: test_name=Empty Update Test
#include-begin
# Creates and authenticates a test user
# Requires: test_email, test_password, test_name
# Sets: user_id, JWT cookie

# Create user
POST http://localhost:8080/signup
Content-Type: application/json
[Options]
variable: test_email=empty-update-{{newUuid}}@test.com
variable: test_password=password123
variable: test_name=Empty Update Test
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

PATCH http://localhost:8080/v1/user
Content-Type: application/json
{}
HTTP 400

# Verify user data unchanged
GET http://localhost:8080/v1/user
HTTP 200
[Asserts]
jsonpath "$.name" == "{{test_name}}"

# Test 11: Update user with null name
PATCH http://localhost:8080/v1/user
Content-Type: application/json
{
    "name": null
}
HTTP 400
