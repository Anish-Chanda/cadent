# Signup Flow Tests
# Tests user registration with comprehensive input validation

# Successful user registration
POST http://localhost:8080/signup
Content-Type: application/json
{
    "user": "{{newUuid}}@test.com",
    "passwd": "validpassword123",
    "name": "New User"
}
HTTP 201
[Asserts]
jsonpath "$.success" == true
jsonpath "$.user_id" exists
jsonpath "$.user_id" matches /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/
jsonpath "$.message" == "User created successfully"
header "Content-Type" contains "application/json"

# Missing email field
POST http://localhost:8080/signup
Content-Type: application/json
{
    "user": "",
    "passwd": "password123",
    "name": "No Email User"
}
HTTP 400
[Asserts]
jsonpath "$.success" == false
jsonpath "$.message" == "Email, password, and name are required"

# Missing password field
POST http://localhost:8080/signup
Content-Type: application/json
{
    "user": "{{newUuid}}@test.com",
    "passwd": "",
    "name": "No Password User"
}
HTTP 400
[Asserts]
jsonpath "$.success" == false
jsonpath "$.message" == "Email, password, and name are required"

# Missing name field
POST http://localhost:8080/signup
Content-Type: application/json
{
    "user": "{{newUuid}}@test.com",
    "passwd": "password123",
    "name": ""
}
HTTP 400
[Asserts]
jsonpath "$.success" == false
jsonpath "$.message" == "Email, password, and name are required"

# Name with only whitespace
POST http://localhost:8080/signup
Content-Type: application/json
{
    "user": "whitespace-{{newUuid}}@test.com",
    "passwd": "password123",
    "name": "     "
}
HTTP 400

# Invalid email format
POST http://localhost:8080/signup
Content-Type: application/json
{
    "user": "notanemail",
    "passwd": "password123",
    "name": "Invalid Email User"
}
HTTP 400

# Email with special characters
POST http://localhost:8080/signup
Content-Type: application/json
[Options]
variable: special_email=special.email+tag-{{newUuid}}@test.com
{
    "user": "{{special_email}}",
    "passwd": "password123",
    "name": "Special Email User"
}
HTTP 201
[Asserts]
jsonpath "$.success" == true

# Password too short
POST http://localhost:8080/signup
Content-Type: application/json
{
    "user": "{{newUuid}}@test.com",
    "passwd": "12345",
    "name": "Short Password User"
}
HTTP 400
[Asserts]
jsonpath "$.success" == false
jsonpath "$.message" == "Password must be at least 6 characters long"

# Minimum valid password
POST http://localhost:8080/signup
Content-Type: application/json
{
    "user": "{{newUuid}}@test.com",
    "passwd": "123456",
    "name": "Min Password User"
}
HTTP 201
[Asserts]
jsonpath "$.success" == true

# Password with spaces
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
[Asserts]
jsonpath "$.success" == true

# Unicode characters in name
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
[Asserts]
jsonpath "$.success" == true

# Emoji in name
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
[Asserts]
jsonpath "$.success" == true

# HTML-like characters in name
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
[Asserts]
jsonpath "$.success" == true

# SQL-like characters in name
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
[Asserts]
jsonpath "$.success" == true

# Very long name
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
HTTP 400

# Duplicate email rejection - create initial user
POST http://localhost:8080/signup
Content-Type: application/json
[Options]
variable: dup_uuid={{newUuid}}
variable: dup_email=duplicate-{{dup_uuid}}@test.com
{
    "user": "{{dup_email}}",
    "passwd": "password123",
    "name": "First User"
}
HTTP 201
[Asserts]
jsonpath "$.success" == true

# Duplicate email rejection - attempt duplicate
POST http://localhost:8080/signup
Content-Type: application/json
{
    "user": "{{dup_email}}",
    "passwd": "different_password",
    "name": "Second User"
}
HTTP 409
[Asserts]
jsonpath "$.success" == false
jsonpath "$.message" == "User with this email already exists"

# Email case insensitivity
POST http://localhost:8080/signup
Content-Type: application/json
[Options]
variable: case_uuid={{newUuid}}
variable: case_email=CaseTest-{{case_uuid}}@TEST.COM
{
    "user": "{{case_email}}",
    "passwd": "password123",
    "name": "Case Test User"
}
HTTP 201
[Asserts]
jsonpath "$.success" == true

# Cannot create duplicate with different case
POST http://localhost:8080/signup
Content-Type: application/json
{
    "user": "casetest-{{case_uuid}}@test.com",
    "passwd": "password123",
    "name": "Duplicate Case User"
}
HTTP 409
[Asserts]
jsonpath "$.success" == false
jsonpath "$.message" == "User with this email already exists"

# Email trimming
POST http://localhost:8080/signup
Content-Type: application/json
[Options]
variable: trim_uuid={{newUuid}}
variable: trim_email=  trimtest-{{trim_uuid}}@test.com  
{
    "user": "{{trim_email}}",
    "passwd": "password123",
    "name": "  Trim Test User  "
}
HTTP 201
[Asserts]
jsonpath "$.success" == true

# Cannot create duplicate without spaces
POST http://localhost:8080/signup
Content-Type: application/json
{
    "user": "trimtest-{{trim_uuid}}@test.com",
    "passwd": "password123",
    "name": "Duplicate Attempt"
}
HTTP 409
[Asserts]
jsonpath "$.success" == false
jsonpath "$.message" == "User with this email already exists"
