# Creates and authenticates a test user
# Requires: test_email, test_password, test_name
# Sets: user_id, JWT cookie

# Create user
POST http://localhost:8080/signup
Content-Type: application/json
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
