# Test 1: Successful user registration
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
header "Content-Type" contains "application/json"
jsonpath "$.message" == "User created successfully"

# Test 2: Duplicate email rejection
# Create initial user
POST http://localhost:8080/signup
Content-Type: application/json
[Options]
variable: known_dup_uuid={{newUuid}}
{
    "user": "known-duplicate-{{known_dup_uuid}}@test.com",
    "passwd": "password123",
    "name": "First User"
}
HTTP 201
[Captures]
duplicate_email: jsonpath "$.user_id"
[Asserts]
jsonpath "$.success" == true

# Try duplicate
POST http://localhost:8080/signup
Content-Type: application/json
{
    "user": "known-duplicate-{{known_dup_uuid}}@test.com",
    "passwd": "password123",
    "name": "Second User"
}
HTTP 409
 
# Test 3: Invalid email format
POST http://localhost:8080/signup
Content-Type: application/json
{
    "user": "notanemail",
    "passwd": "password123",
    "name": "Invalid Email User"
}
HTTP 400
# Test 4: Missing email field
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

# Test 5: Missing password field
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

# Test 6: Missing name field
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

# Test 7: Password too short (< 6 characters)
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

# Test 8: Minimum valid password (6 characters)
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
jsonpath "$.user_id" exists

# Test 9: Email case insensitivity - signup with mixed case
POST http://localhost:8080/signup
Content-Type: application/json
[Options]
variable: case_test_uuid={{newUuid}}
{
    "user": "CaseTestUser-{{case_test_uuid}}@TEST.COM",
    "passwd": "password123",
    "name": "Case Test User"
}
HTTP 201
[Asserts]
jsonpath "$.success" == true

# Test 9b: Verify can login with different case (lowercase)
POST http://localhost:8080/auth/local/login
[Form]
user: casetestuser-{{case_test_uuid}}@test.com
passwd: password123
HTTP 200
[Asserts]
cookie "JWT" exists

# Test 9c: Verify cannot create duplicate with different case
POST http://localhost:8080/signup
Content-Type: application/json
{
    "user": "casetestuser-{{case_test_uuid}}@TEST.com",
    "passwd": "password123",
    "name": "Duplicate Case User"
}
HTTP 409
[Asserts]
jsonpath "$.success" == false
jsonpath "$.message" == "User with this email already exists"

# Test 10: Email with spaces - signup with leading/trailing spaces
POST http://localhost:8080/signup
Content-Type: application/json
[Options]
variable: spaces_test_uuid={{newUuid}}
{
    "user": "  spacestestuser-{{spaces_test_uuid}}@test.com  ",
    "passwd": "password123",
    "name": "  Spaces User  "
}
HTTP 201
[Asserts]
jsonpath "$.success" == true

# Test 10b: Verify can login without spaces
POST http://localhost:8080/auth/local/login
[Form]
user: spacestestuser-{{spaces_test_uuid}}@test.com
passwd: password123
HTTP 200
[Asserts]
cookie "JWT" exists

# Test 10c: Verify cannot create duplicate with different spacing
POST http://localhost:8080/signup
Content-Type: application/json
{
    "user": "spacestestuser-{{spaces_test_uuid}}@test.com",
    "passwd": "password123",
    "name": "Duplicate Attempt"
}
HTTP 409
[Asserts]
jsonpath "$.success" == false
jsonpath "$.message" == "User with this email already exists"
