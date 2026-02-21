# Login Flow Tests - User authentication with validation and cookie security

# Setup: Create test user
POST http://localhost:8080/signup
Content-Type: application/json
[Options]
variable: login_uuid={{newUuid}}
variable: login_email=logintest-{{login_uuid}}@test.com
variable: login_password=correctpassword123
{
    "user": "{{login_email}}",
    "passwd": "{{login_password}}",
    "name": "Login Test User"
}
HTTP 201
[Asserts]
jsonpath "$.success" == true
[Captures]
user_id: jsonpath "$.user_id"

# Successful login
POST http://localhost:8080/auth/local/login
[Form]
user: {{login_email}}
passwd: {{login_password}}
HTTP 200
[Asserts]
cookie "JWT" exists
cookie "JWT[HttpOnly]" exists
cookie "JWT[Path]" == "/"

# JWT cookie persists across requests
GET http://localhost:8080/v1/user
HTTP 200
[Asserts]
jsonpath "$.id" == "{{user_id}}"
jsonpath "$.email" == "{{login_email}}"

# Cookie works for multiple requests
GET http://localhost:8080/v1/activities
HTTP 200

GET http://localhost:8080/v1/user
HTTP 200
[Asserts]
jsonpath "$.id" == "{{user_id}}"

# Failed login with incorrect password
POST http://localhost:8080/auth/local/login
[Form]
user: {{login_email}}
passwd: wrongpassword
HTTP 401

# Failed login with non-existent user
POST http://localhost:8080/auth/local/login
[Form]
user: nonexistent-{{newUuid}}@test.com
passwd: anypassword
HTTP 401

# Empty username
POST http://localhost:8080/auth/local/login
[Form]
user: 
passwd: somepassword
HTTP 401

# Empty password
POST http://localhost:8080/auth/local/login
[Form]
user: {{login_email}}
passwd: 
HTTP 401

# Missing credentials
POST http://localhost:8080/auth/local/login
[Form]

HTTP 401

# Password with spaces
POST http://localhost:8080/signup
Content-Type: application/json
[Options]
variable: space_uuid={{newUuid}}
variable: space_email=spacepass-{{space_uuid}}@test.com
variable: space_password=my password has spaces
{
    "user": "{{space_email}}",
    "passwd": "{{space_password}}",
    "name": "Space Password User"
}
HTTP 201

POST http://localhost:8080/auth/local/login
[Form]
user: {{space_email}}
passwd: {{space_password}}
HTTP 200
[Asserts]
cookie "JWT" exists

# Email case insensitivity - create user
POST http://localhost:8080/signup
Content-Type: application/json
[Options]
variable: case_uuid={{newUuid}}
variable: case_email_upper=CaseLogin-{{case_uuid}}@TEST.COM
{
    "user": "{{case_email_upper}}",
    "passwd": "password123",
    "name": "Case Login Test"
}
HTTP 201

# Login with lowercase email
POST http://localhost:8080/auth/local/login
[Form]
user: caselogin-{{case_uuid}}@test.com
passwd: password123
HTTP 200
[Asserts]
cookie "JWT" exists

# Login with uppercase email
POST http://localhost:8080/auth/local/login
[Form]
user: CASELOGIN-{{case_uuid}}@TEST.COM
passwd: password123
HTTP 200
[Asserts]
cookie "JWT" exists

# Email trimming - create user
POST http://localhost:8080/signup
Content-Type: application/json
[Options]
variable: trim_uuid={{newUuid}}
variable: trim_email=  trimlogin-{{trim_uuid}}@test.com  
{
    "user": "{{trim_email}}",
    "passwd": "password123",
    "name": "Trim Login Test"
}
HTTP 201

# Login without spaces
POST http://localhost:8080/auth/local/login
[Form]
user: trimlogin-{{trim_uuid}}@test.com
passwd: password123
HTTP 200
[Asserts]
cookie "JWT" exists
