# Setup: Create unique test user for login tests
#include /api/common/create-test-user.hurl
#options variable: login_test_email=logintest-{{newUuid}}@test.com
#options variable: login_test_password=correctpassword123
#options variable: test_email={{login_test_email}}
#options variable: test_password={{login_test_password}}
#options variable: test_name=Login Test User
#include-begin
# Creates a new test user
# Requires: test_email, test_password, test_name
# Sets: user_id

POST http://localhost:8080/signup
Content-Type: application/json
[Options]
variable: login_test_email=logintest-{{newUuid}}@test.com
variable: login_test_password=correctpassword123
variable: test_email={{login_test_email}}
variable: test_password={{login_test_password}}
variable: test_name=Login Test User
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

# Test 1: Successful login with valid credentials
POST http://localhost:8080/auth/local/login
[Form]
user: {{login_test_email}}
passwd: {{login_test_password}}
HTTP 200
[Asserts]
cookie "JWT" exists

# Test 2: Failed login with incorrect password
POST http://localhost:8080/auth/local/login
[Form]
user: {{login_test_email}}
passwd: wrongpassword
HTTP 401

# Test 3: Failed login with non-existent user
POST http://localhost:8080/auth/local/login
[Form]
user: nonexistent-{{newUuid}}@test.com
passwd: anypassword
HTTP 401

# Test 4: Failed login with empty username
POST http://localhost:8080/auth/local/login
[Form]
user: 
passwd: somepassword
HTTP 400

# Test 5: Failed login with empty password
POST http://localhost:8080/auth/local/login
[Form]
user: {{login_test_email}}
passwd: 
HTTP 400

# Test 6: Failed login with missing credentials
POST http://localhost:8080/auth/local/login
[Form]

HTTP 400

# Test 7: Login is case-insensitive for email - create with uppercase
#include /api/common/create-test-user.hurl
#options variable: case_uuid={{newUuid}}
#options variable: test_email=CaseLogin-{{case_uuid}}@TEST.COM
#options variable: test_password=password123
#options variable: test_name=Case Login Test
#include-begin
# Creates a new test user
# Requires: test_email, test_password, test_name
# Sets: user_id

POST http://localhost:8080/signup
Content-Type: application/json
[Options]
variable: case_uuid={{newUuid}}
variable: test_email=CaseLogin-{{case_uuid}}@TEST.COM
variable: test_password=password123
variable: test_name=Case Login Test
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

# Try logging in with lowercase
POST http://localhost:8080/auth/local/login
[Form]
user: caselogin-{{case_uuid}}@test.com
passwd: password123
HTTP 200
[Asserts]
cookie "JWT" exists

# Test 8: Login with special characters in password
#include /api/common/create-test-user.hurl
#options variable: special_email=specialpass-{{newUuid}}@test.com
#options variable: special_password=p@ssw0rd!#$%
#options variable: test_email={{special_email}}
#options variable: test_password={{special_password}}
#options variable: test_name=Special Char User
#include-begin
# Creates a new test user
# Requires: test_email, test_password, test_name
# Sets: user_id

POST http://localhost:8080/signup
Content-Type: application/json
[Options]
variable: special_email=specialpass-{{newUuid}}@test.com
variable: special_password=p@ssw0rd!#$%
variable: test_email={{special_email}}
variable: test_password={{special_password}}
variable: test_name=Special Char User
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

POST http://localhost:8080/auth/local/login
[Form]
user: {{special_email}}
passwd: {{special_password}}
HTTP 200
[Asserts]
cookie "JWT" exists
