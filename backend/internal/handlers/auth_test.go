package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/anish-chanda/cadence/backend/internal/logger"
	"github.com/anish-chanda/cadence/backend/internal/models"
)

// mockDatabase implements the db.Database interface for testing
type mockDatabase struct {
	users           map[string]*models.UserRecord
	getUserError    error
	createUserError error
}

func newMockDatabase() *mockDatabase {
	return &mockDatabase{
		users: make(map[string]*models.UserRecord),
	}
}

func (m *mockDatabase) GetUserByEmail(ctx context.Context, email string) (*models.UserRecord, error) {
	if m.getUserError != nil {
		return nil, m.getUserError
	}
	return m.users[email], nil
}

func (m *mockDatabase) CreateUser(ctx context.Context, user *models.UserRecord) error {
	if m.createUserError != nil {
		return m.createUserError
	}
	m.users[user.Email] = user
	return nil
}

func (m *mockDatabase) GetUserByID(ctx context.Context, userID string) (*models.UserRecord, error) {
	for _, user := range m.users {
		if user.ID == userID {
			return user, nil
		}
	}
	return nil, nil
}

func (m *mockDatabase) UpdateUser(ctx context.Context, userID string, updates map[string]interface{}) error {
	return nil
}

// Required interface methods (not used in auth tests)
func (m *mockDatabase) CreateActivity(ctx context.Context, activity *models.Activity) error {
	return nil
}
func (m *mockDatabase) GetActivitiesByUserID(ctx context.Context, userID string) ([]models.Activity, error) {
	return nil, nil
}
func (m *mockDatabase) CheckIdempotency(ctx context.Context, clientActivityID string) (bool, error) {
	return false, nil
}
func (m *mockDatabase) GetActivityByID(ctx context.Context, activityID string) (*models.Activity, error) {
	return nil, nil
}
func (m *mockDatabase) GetActivityStreams(ctx context.Context, activityID string, lod models.StreamLOD) ([]models.ActivityStream, error) {
	return nil, nil
}
func (m *mockDatabase) CreateActivityStreams(ctx context.Context, streams []models.ActivityStream) error {
	return nil
}
func (m *mockDatabase) Connect(dsn string) error { return nil }
func (m *mockDatabase) Close() error             { return nil }
func (m *mockDatabase) Migrate() error           { return nil }

func TestHashPassword(t *testing.T) {
	tests := []struct {
		name     string
		password string
	}{
		{"empty password", ""},
		{"short password", "123"},
		{"normal password", "password123"},
		{"complex password", "P@ssw0rd!@#$%^&*()"},
		{"unicode password", "пароль日本語🔒"},
		{"very long password", strings.Repeat("a", 1000)},
		{"password with spaces", "my secure password"},
		{"password with newlines", "line1\nline2\nline3"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			hash, err := hashPassword(tt.password)
			if err != nil {
				t.Fatalf("hashPassword(%q) failed: %v", tt.password, err)
			}

			// Verify hash format
			if !strings.HasPrefix(hash, "$argon2id$v=19$") {
				t.Errorf("Hash doesn't have expected Argon2id format: %s", hash)
			}

			// Verify hash components
			parts := strings.Split(hash, "$")
			if len(parts) != 6 {
				t.Errorf("Hash should have 6 parts separated by '$', got %d: %s", len(parts), hash)
			}

			if parts[1] != "argon2id" {
				t.Errorf("Expected algorithm 'argon2id', got '%s'", parts[1])
			}

			if parts[2] != "v=19" {
				t.Errorf("Expected version 'v=19', got '%s'", parts[2])
			}

			// Verify we can verify the password... lol
			valid, err := verifyPassword(tt.password, hash)
			if err != nil {
				t.Fatalf("verifyPassword failed: %v", err)
			}
			if !valid {
				t.Errorf("verifyPassword should return true for correct password")
			}
		})
	}
}

func TestVerifyPassword(t *testing.T) {
	// Create a known good hash for testing
	testPassword := "testpassword123"
	goodHash, err := hashPassword(testPassword)
	if err != nil {
		t.Fatalf("Failed to create test hash: %v", err)
	}

	tests := []struct {
		name        string
		password    string
		hash        string
		expectValid bool
		expectError bool
		errorSubstr string
	}{
		{
			name:        "correct password",
			password:    testPassword,
			hash:        goodHash,
			expectValid: true,
			expectError: false,
		},
		{
			name:        "wrong password",
			password:    "wrongpassword",
			hash:        goodHash,
			expectValid: false,
			expectError: false,
		},
		{
			name:        "empty password against hash",
			password:    "",
			hash:        goodHash,
			expectValid: false,
			expectError: false,
		},
		{
			name:        "invalid hash format - too few parts",
			password:    testPassword,
			hash:        "$argon2id$v=19",
			expectValid: false,
			expectError: true,
			errorSubstr: "invalid hash format",
		},
		{
			name:        "invalid hash format - wrong algorithm",
			password:    testPassword,
			hash:        "$bcrypt$v=19$m=19456,t=2,p=1$c29tZXNhbHQ$aGFzaA",
			expectValid: false,
			expectError: true,
			errorSubstr: "invalid hash format",
		},
		{
			name:        "invalid parameter format",
			password:    testPassword,
			hash:        "$argon2id$v=19$invalidparams$c29tZXNhbHQ$aGFzaA",
			expectValid: false,
			expectError: true,
		},
		{
			name:        "invalid base64 salt",
			password:    testPassword,
			hash:        "$argon2id$v=19$m=19456,t=2,p=1$invalid!!!base64$aGFzaA",
			expectValid: false,
			expectError: true,
		},
		{
			name:        "invalid base64 hash",
			password:    testPassword,
			hash:        "$argon2id$v=19$m=19456,t=2,p=1$c29tZXNhbHQ$invalid!!!base64",
			expectValid: false,
			expectError: true,
		},
		{
			name:        "completely malformed hash",
			password:    testPassword,
			hash:        "not_a_hash_at_all",
			expectValid: false,
			expectError: true,
			errorSubstr: "invalid hash format",
		},
		{
			name:        "empty hash",
			password:    testPassword,
			hash:        "",
			expectValid: false,
			expectError: true,
			errorSubstr: "invalid hash format",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			valid, err := verifyPassword(tt.password, tt.hash)

			if valid != tt.expectValid {
				t.Errorf("Expected valid=%v, got valid=%v", tt.expectValid, valid)
			}

			if tt.expectError {
				if err == nil {
					t.Errorf("Expected error, but got nil")
				} else if tt.errorSubstr != "" && !strings.Contains(err.Error(), tt.errorSubstr) {
					t.Errorf("Expected error to contain %q, but got: %v", tt.errorSubstr, err)
				}
			} else {
				if err != nil {
					t.Errorf("Expected no error, but got: %v", err)
				}
			}
		})
	}
}

func TestHandleLogin(t *testing.T) {
	tests := []struct {
		name        string
		email       string
		password    string
		setupDB     func(*mockDatabase)
		expectOk    bool
		expectError bool
		errorSubstr string
	}{
		{
			name:     "database error",
			email:    "user@example.com",
			password: "password",
			setupDB: func(db *mockDatabase) {
				db.getUserError = errors.New("database connection failed")
			},
			expectOk:    false,
			expectError: true,
			errorSubstr: "failed to get user",
		},
		{
			name:     "user not found",
			email:    "nonexistent@example.com",
			password: "password",
			setupDB:  func(db *mockDatabase) {}, // No user in database
			expectOk: false,
		},
		{
			name:     "user with non-local auth provider",
			email:    "oauth@example.com",
			password: "password",
			setupDB: func(db *mockDatabase) {
				db.users["oauth@example.com"] = &models.UserRecord{
					Email:        "oauth@example.com",
					AuthProvider: "google", // Use string literal instead of non-existent constant
				}
			},
			expectOk:    false,
			expectError: true,
			errorSubstr: "does not use local authentication",
		},
		{
			name:     "user with nil password hash",
			email:    "user@example.com",
			password: "password",
			setupDB: func(db *mockDatabase) {
				db.users["user@example.com"] = &models.UserRecord{
					Email:        "user@example.com",
					AuthProvider: models.AuthProviderLocal,
					PasswordHash: nil,
				}
			},
			expectOk:    false,
			expectError: true,
			errorSubstr: "has no password set",
		},
		{
			name:     "user with corrupted password hash",
			email:    "user@example.com",
			password: "password",
			setupDB: func(db *mockDatabase) {
				corruptedHash := "corrupted_hash"
				db.users["user@example.com"] = &models.UserRecord{
					Email:        "user@example.com",
					AuthProvider: models.AuthProviderLocal,
					PasswordHash: &corruptedHash,
				}
			},
			expectOk:    false,
			expectError: true,
			errorSubstr: "failed to verify password",
		},
		{
			name:     "wrong password",
			email:    "user@example.com",
			password: "wrongpassword",
			setupDB: func(db *mockDatabase) {
				correctHash, _ := hashPassword("correctpassword")
				db.users["user@example.com"] = &models.UserRecord{
					Email:        "user@example.com",
					AuthProvider: models.AuthProviderLocal,
					PasswordHash: &correctHash,
				}
			},
			expectOk: false,
		},
		{
			name:     "successful login",
			email:    "user@example.com",
			password: "correctpassword",
			setupDB: func(db *mockDatabase) {
				correctHash, _ := hashPassword("correctpassword")
				db.users["user@example.com"] = &models.UserRecord{
					Email:        "user@example.com",
					AuthProvider: models.AuthProviderLocal,
					PasswordHash: &correctHash,
				}
			},
			expectOk: true,
		},
		{
			name:     "successful login with complex password",
			email:    "user@example.com",
			password: "C0mpl3x!P@ssw0rd#123",
			setupDB: func(db *mockDatabase) {
				complexHash, _ := hashPassword("C0mpl3x!P@ssw0rd#123")
				db.users["user@example.com"] = &models.UserRecord{
					Email:        "user@example.com",
					AuthProvider: models.AuthProviderLocal,
					PasswordHash: &complexHash,
				}
			},
			expectOk: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			db := newMockDatabase()
			tt.setupDB(db)

			ok, err := HandleLogin(db, tt.email, tt.password)

			if ok != tt.expectOk {
				t.Errorf("Expected ok=%v, got ok=%v", tt.expectOk, ok)
			}

			if tt.expectError {
				if err == nil {
					t.Errorf("Expected error, but got nil")
				} else if tt.errorSubstr != "" && !strings.Contains(err.Error(), tt.errorSubstr) {
					t.Errorf("Expected error to contain %q, but got: %v", tt.errorSubstr, err)
				}
			} else {
				if err != nil {
					t.Errorf("Expected no error, but got: %v", err)
				}
			}
		})
	}
}

func TestCreateUser(t *testing.T) {
	tests := []struct {
		name        string
		email       string
		password    string
		userName    string
		setupDB     func(*mockDatabase)
		expectError bool
		errorSubstr string
	}{
		{
			name:     "successful user creation",
			email:    "newuser@example.com",
			password: "password123",
			userName: "New User",
			setupDB:  func(db *mockDatabase) {}, // No special setup needed
		},
		{
			name:     "database error during creation",
			email:    "newuser@example.com",
			password: "password123",
			userName: "New User",
			setupDB: func(db *mockDatabase) {
				db.createUserError = errors.New("database constraint violation")
			},
			expectError: true,
			errorSubstr: "failed to create user",
		},
		{
			name:     "empty password",
			email:    "user@example.com",
			password: "",
			userName: "Test User",
			setupDB:  func(db *mockDatabase) {},
		},
		{
			name:     "empty email",
			email:    "",
			password: "password",
			userName: "Test User",
			setupDB:  func(db *mockDatabase) {},
		},
		{
			name:     "empty name",
			email:    "user@example.com",
			password: "password",
			userName: "",
			setupDB:  func(db *mockDatabase) {},
		},
		{
			name:     "unicode email and name",
			email:    "тест@example.com",
			password: "password",
			userName: "テストユーザー",
			setupDB:  func(db *mockDatabase) {},
		},
		{
			name:     "very long inputs",
			email:    strings.Repeat("a", 100) + "@example.com",
			password: strings.Repeat("b", 500),
			userName: strings.Repeat("c", 200),
			setupDB:  func(db *mockDatabase) {},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			db := newMockDatabase()
			tt.setupDB(db)

			user, err := createUser(db, tt.email, tt.password, tt.userName)

			if tt.expectError {
				if err == nil {
					t.Errorf("Expected error, but got nil")
				} else if tt.errorSubstr != "" && !strings.Contains(err.Error(), tt.errorSubstr) {
					t.Errorf("Expected error to contain %q, but got: %v", tt.errorSubstr, err)
				}
				return
			}

			if err != nil {
				t.Errorf("Expected no error, but got: %v", err)
				return
			}

			if user == nil {
				t.Errorf("Expected user to be created, but got nil")
				return
			}

			// Verify user properties
			if user.Email != tt.email {
				t.Errorf("Expected email %q, got %q", tt.email, user.Email)
			}
			if user.Name != tt.userName {
				t.Errorf("Expected name %q, got %q", tt.userName, user.Name)
			}
			if user.AuthProvider != models.AuthProviderLocal {
				t.Errorf("Expected AuthProvider to be Local, got %v", user.AuthProvider)
			}
			if user.PasswordHash == nil {
				t.Errorf("Expected PasswordHash to be set, got nil")
			} else {
				// Verify the password hash is valid
				valid, err := verifyPassword(tt.password, *user.PasswordHash)
				if err != nil {
					t.Errorf("Failed to verify generated password hash: %v", err)
				}
				if !valid {
					t.Errorf("Generated password hash doesn't verify against original password")
				}
			}
			if user.ID == "" {
				t.Errorf("Expected ID to be generated, got empty string")
			}
			if user.CreatedAt == 0 {
				t.Errorf("Expected CreatedAt to be set, got 0")
			}
			if user.UpdatedAt == 0 {
				t.Errorf("Expected UpdatedAt to be set, got 0")
			}
			if user.CreatedAt != user.UpdatedAt {
				t.Errorf("Expected CreatedAt and UpdatedAt to be equal for new user, got CreatedAt=%d UpdatedAt=%d", user.CreatedAt, user.UpdatedAt)
			}

			// Verify user was stored in mock database
			storedUser := db.users[tt.email]
			if storedUser == nil {
				t.Errorf("User was not stored in database")
			} else if storedUser.ID != user.ID {
				t.Errorf("Stored user ID doesn't match returned user ID")
			}
		})
	}
}

func TestGenerateUserID(t *testing.T) {
	// Test that generateUserID produces valid UUIDs
	ids := make(map[string]bool)

	for i := 0; i < 100; i++ {
		id, err := generateUserID()
		if err != nil {
			t.Fatalf("generateUserID failed: %v", err)
		}

		if id == "" {
			t.Errorf("generateUserID returned empty string")
		}

		if ids[id] {
			t.Errorf("generateUserID returned duplicate ID: %s", id)
		}
		ids[id] = true

		// Basic UUID format validation (36 characters with hyphens)
		if len(id) != 36 {
			t.Errorf("Expected UUID length 36, got %d for ID: %s", len(id), id)
		}

		// Check for hyphens in expected positions
		if id[8] != '-' || id[13] != '-' || id[18] != '-' || id[23] != '-' {
			t.Errorf("ID doesn't match UUID format: %s", id)
		}
	}
}

// Benchmark tests
func BenchmarkHashPassword(b *testing.B) {
	password := "benchmarkpassword123"
	for i := 0; i < b.N; i++ {
		_, err := hashPassword(password)
		if err != nil {
			b.Fatalf("hashPassword failed: %v", err)
		}
	}
}

func BenchmarkVerifyPassword(b *testing.B) {
	password := "benchmarkpassword123"
	hash, err := hashPassword(password)
	if err != nil {
		b.Fatalf("Failed to create hash for benchmark: %v", err)
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, err := verifyPassword(password, hash)
		if err != nil {
			b.Fatalf("verifyPassword failed: %v", err)
		}
	}
}

// mockLogger for testing handlers
type mockLogger struct{}

func (m *mockLogger) WithContext(key, value string) interface{}                     { return m }
func (m *mockLogger) WithFields(fields map[string]interface{}) interface{}          { return m }
func (m *mockLogger) Debug(msg string, fields ...map[string]interface{})            {}
func (m *mockLogger) Info(msg string, fields ...map[string]interface{})             {}
func (m *mockLogger) Warn(msg string, fields ...map[string]interface{})             {}
func (m *mockLogger) Error(msg string, err error, fields ...map[string]interface{}) {}
func (m *mockLogger) Fatal(msg string, err error, fields ...map[string]interface{}) {}
func (m *mockLogger) Panic(msg string, err error, fields ...map[string]interface{}) {}
func (m *mockLogger) GetZerolog() interface{}                                       { return nil }

func TestSignupHandler(t *testing.T) {
	tests := []struct {
		name           string
		method         string
		requestBody    string
		mockSetup      func(*mockDatabase)
		expectedStatus int
		expectedBody   string
		contentType    string
	}{
		{
			name:           "method not allowed",
			method:         "GET",
			requestBody:    "",
			mockSetup:      func(m *mockDatabase) {},
			expectedStatus: 405,
			contentType:    "",
		},
		{
			name:           "invalid JSON",
			method:         "POST",
			requestBody:    `{"invalid": json}`,
			mockSetup:      func(m *mockDatabase) {},
			expectedStatus: 400,
			expectedBody:   `{"success":false,"user_id":"","message":"Invalid request format"}`,
			contentType:    "application/json",
		},
		{
			name:           "empty email",
			method:         "POST",
			requestBody:    `{"user":"","passwd":"password123","name":"Test User"}`,
			mockSetup:      func(m *mockDatabase) {},
			expectedStatus: 400,
			expectedBody:   `{"success":false,"user_id":"","message":"Email, password, and name are required"}`,
			contentType:    "application/json",
		},
		{
			name:           "empty password",
			method:         "POST",
			requestBody:    `{"user":"test@example.com","passwd":"","name":"Test User"}`,
			mockSetup:      func(m *mockDatabase) {},
			expectedStatus: 400,
			expectedBody:   `{"success":false,"user_id":"","message":"Email, password, and name are required"}`,
			contentType:    "application/json",
		},
		{
			name:           "empty name",
			method:         "POST",
			requestBody:    `{"user":"test@example.com","passwd":"password123","name":""}`,
			mockSetup:      func(m *mockDatabase) {},
			expectedStatus: 400,
			expectedBody:   `{"success":false,"user_id":"","message":"Email, password, and name are required"}`,
			contentType:    "application/json",
		},
		{
			name:           "invalid email format",
			method:         "POST",
			requestBody:    `{"user":"invalid-email","passwd":"password123","name":"Test User"}`,
			mockSetup:      func(m *mockDatabase) {},
			expectedStatus: 400,
			expectedBody:   `{"success":false,"user_id":"","message":"Invalid email format"}`,
			contentType:    "application/json",
		},
		{
			name:           "password too short",
			method:         "POST",
			requestBody:    `{"user":"test@example.com","passwd":"12345","name":"Test User"}`,
			mockSetup:      func(m *mockDatabase) {},
			expectedStatus: 400,
			expectedBody:   `{"success":false,"user_id":"","message":"Password must be at least 6 characters long"}`,
			contentType:    "application/json",
		},
		{
			name:        "database error on user check",
			method:      "POST",
			requestBody: `{"user":"test@example.com","passwd":"password123","name":"Test User"}`,
			mockSetup: func(m *mockDatabase) {
				m.getUserError = errors.New("database connection error")
			},
			expectedStatus: 500,
			expectedBody:   `{"success":false,"user_id":"","message":"Internal server error"}`,
			contentType:    "application/json",
		},
		{
			name:        "user already exists",
			method:      "POST",
			requestBody: `{"user":"existing@example.com","passwd":"password123","name":"Test User"}`,
			mockSetup: func(m *mockDatabase) {
				m.users["existing@example.com"] = &models.UserRecord{
					ID:    "existing-id",
					Email: "existing@example.com",
					Name:  "Existing User",
				}
			},
			expectedStatus: 409,
			expectedBody:   `{"success":false,"user_id":"","message":"User with this email already exists"}`,
			contentType:    "application/json",
		},
		{
			name:        "database error on user creation",
			method:      "POST",
			requestBody: `{"user":"new@example.com","passwd":"password123","name":"Test User"}`,
			mockSetup: func(m *mockDatabase) {
				m.createUserError = errors.New("failed to insert user")
			},
			expectedStatus: 500,
			expectedBody:   `{"success":false,"user_id":"","message":"Failed to create user account"}`,
			contentType:    "application/json",
		},
		{
			name:           "successful signup",
			method:         "POST",
			requestBody:    `{"user":"success@example.com","passwd":"password123","name":"Success User"}`,
			mockSetup:      func(m *mockDatabase) {},
			expectedStatus: 201,
			contentType:    "application/json",
		},
		{
			name:           "case insensitive email",
			method:         "POST",
			requestBody:    `{"user":"CaseTest@EXAMPLE.COM","passwd":"password123","name":"Case User"}`,
			mockSetup:      func(m *mockDatabase) {},
			expectedStatus: 201,
			contentType:    "application/json",
		},
		{
			name:           "email with whitespace",
			method:         "POST",
			requestBody:    `{"user":"  whitespace@example.com  ","passwd":"password123","name":"  Whitespace User  "}`,
			mockSetup:      func(m *mockDatabase) {},
			expectedStatus: 201,
			contentType:    "application/json",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup mock database
			mockDB := newMockDatabase()
			tt.mockSetup(mockDB)

			// Setup mock logger
			mockLog := logger.New(logger.Config{
				Level:       "info",
				Environment: "test",
				ServiceName: "test",
			})

			// Create handler
			handler := SignupHandler(mockDB, *mockLog)

			// Create request
			req := httptest.NewRequest(tt.method, "/signup", strings.NewReader(tt.requestBody))
			req.Header.Set("Content-Type", "application/json")

			// Create response recorder
			w := httptest.NewRecorder()

			// Call handler
			handler.ServeHTTP(w, req)

			// Check status code
			if w.Code != tt.expectedStatus {
				t.Errorf("Status code = %d, want %d", w.Code, tt.expectedStatus)
			}

			// Check content type if specified
			if tt.contentType != "" {
				if w.Header().Get("Content-Type") != tt.contentType {
					t.Errorf("Content-Type = %s, want %s", w.Header().Get("Content-Type"), tt.contentType)
				}
			}

			// Check response body if specified
			if tt.expectedBody != "" {
				body := strings.TrimSpace(w.Body.String())
				if body != tt.expectedBody {
					t.Errorf("Response body = %s, want %s", body, tt.expectedBody)
				}
			}

			// For successful cases, verify response structure
			if tt.expectedStatus == 201 {
				var response SignupResponse
				if err := json.NewDecoder(strings.NewReader(w.Body.String())).Decode(&response); err != nil {
					t.Errorf("Failed to decode response: %v", err)
				}
				if !response.Success {
					t.Error("Response success should be true")
				}
				if response.UserID == "" {
					t.Error("Response should contain user ID")
				}
				if response.Message != "User created successfully" {
					t.Errorf("Response message = %s, want 'User created successfully'", response.Message)
				}

				// Verify user was actually created in the mock database
				email := ""
				if strings.Contains(tt.requestBody, "success@example.com") {
					email = "success@example.com"
				} else if strings.Contains(tt.requestBody, "CaseTest@EXAMPLE.COM") {
					email = "casetest@example.com" // Should be normalized to lowercase
				} else if strings.Contains(tt.requestBody, "whitespace@example.com") {
					email = "whitespace@example.com" // Should be trimmed
				}

				if email != "" {
					user := mockDB.users[email]
					if user == nil {
						t.Error("User should have been created in database")
					} else {
						if user.Email != email {
							t.Errorf("User email = %s, want %s", user.Email, email)
						}
						if user.AuthProvider != models.AuthProviderLocal {
							t.Errorf("User auth provider = %s, want %s", user.AuthProvider, models.AuthProviderLocal)
						}
						if user.PasswordHash == nil || *user.PasswordHash == "" {
							t.Error("User should have password hash set")
						}
					}
				}
			}
		})
	}
}
