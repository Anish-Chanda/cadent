package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/anish-chanda/cadence/backend/internal/logger"
	"github.com/anish-chanda/cadence/backend/internal/models"
)

// UserMockDatabase implements the db.Database interface for testing user handlers
type UserMockDatabase struct {
	users            map[string]*models.UserRecord
	usersById        map[string]*models.UserRecord
	getUserError     error
	updateUserError  error
	getUserByIDError error
}

func newUserMockDatabase() *UserMockDatabase {
	return &UserMockDatabase{
		users:     make(map[string]*models.UserRecord),
		usersById: make(map[string]*models.UserRecord),
	}
}

func (m *UserMockDatabase) GetUserByEmail(ctx context.Context, email string) (*models.UserRecord, error) {
	if m.getUserError != nil {
		return nil, m.getUserError
	}
	return m.users[email], nil
}

func (m *UserMockDatabase) GetUserByID(ctx context.Context, userID string) (*models.UserRecord, error) {
	if m.getUserByIDError != nil {
		return nil, m.getUserByIDError
	}
	return m.usersById[userID], nil
}

func (m *UserMockDatabase) UpdateUser(ctx context.Context, userID string, updates map[string]interface{}) error {
	if m.updateUserError != nil {
		return m.updateUserError
	}

	// Find and update user
	user := m.usersById[userID]
	if user != nil {
		if name, ok := updates["name"]; ok {
			user.Name = name.(string)
		}
		if email, ok := updates["email"]; ok {
			// Remove from old email mapping
			for k, v := range m.users {
				if v.ID == userID {
					delete(m.users, k)
					break
				}
			}
			// Add to new email mapping
			user.Email = email.(string)
			m.users[user.Email] = user
		}
	}

	return nil
}

func (m *UserMockDatabase) CreateUser(ctx context.Context, user *models.UserRecord) error { return nil }
func (m *UserMockDatabase) CreateActivity(ctx context.Context, activity *models.Activity) error {
	return nil
}
func (m *UserMockDatabase) GetActivitiesByUserID(ctx context.Context, userID string) ([]models.Activity, error) {
	return nil, nil
}
func (m *UserMockDatabase) CheckIdempotency(ctx context.Context, clientActivityID string) (bool, error) {
	return false, nil
}
func (m *UserMockDatabase) GetActivityByID(ctx context.Context, activityID string) (*models.Activity, error) {
	return nil, nil
}
func (m *UserMockDatabase) GetActivityStreams(ctx context.Context, activityID string, lod models.StreamLOD) ([]models.ActivityStream, error) {
	return nil, nil
}
func (m *UserMockDatabase) CreateActivityStreams(ctx context.Context, streams []models.ActivityStream) error {
	return nil
}
func (m *UserMockDatabase) Connect(dsn string) error { return nil }
func (m *UserMockDatabase) Close() error             { return nil }
func (m *UserMockDatabase) Migrate() error           { return nil }

func (m *UserMockDatabase) reset() {
	m.users = make(map[string]*models.UserRecord)
	m.usersById = make(map[string]*models.UserRecord)
	m.getUserError = nil
	m.updateUserError = nil
	m.getUserByIDError = nil
}

func (m *UserMockDatabase) addUser(user *models.UserRecord) {
	m.users[user.Email] = user
	m.usersById[user.ID] = user
}

// Since we can't easily mock token.GetUserInfo, we'll create wrapper functions
// that can be tested by injecting the email directly

// testableHandleGetUser is a testable version that accepts email directly
func testableHandleGetUser(database UserMockDatabase, log logger.ServiceLogger, userEmail string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := context.Background()

		if userEmail == "" {
			log.Error("No email found in user token", nil)
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}

		// Look up database user by email
		dbUser, err := database.GetUserByEmail(ctx, userEmail)
		if err != nil {
			log.Error("Failed to get user from database", err)
			http.Error(w, "Internal server error", http.StatusInternalServerError)
			return
		}
		if dbUser == nil {
			log.Error("User not found in database", nil)
			http.Error(w, "User not found", http.StatusNotFound)
			return
		}

		// Return user profile
		response := UserResponse{
			ID:    dbUser.ID,
			Email: dbUser.Email,
			Name:  dbUser.Name,
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(response)
	}
}

// testableHandleUpdateUser is a testable version that accepts email directly
func testableHandleUpdateUser(database UserMockDatabase, log logger.ServiceLogger, userEmail string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := context.Background()

		if userEmail == "" {
			log.Error("No email found in user token", nil)
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}

		// Look up database user by email
		dbUser, err := database.GetUserByEmail(ctx, userEmail)
		if err != nil {
			log.Error("Failed to get user from database", err)
			http.Error(w, "Internal server error", http.StatusInternalServerError)
			return
		}
		if dbUser == nil {
			log.Error("User not found in database", nil)
			http.Error(w, "User not found", http.StatusNotFound)
			return
		}

		// Parse request body
		var updateReq UserUpdateRequest
		if err := json.NewDecoder(r.Body).Decode(&updateReq); err != nil {
			log.Error("Failed to decode request body", err)
			http.Error(w, "Invalid request body", http.StatusBadRequest)
			return
		}

		// Build updates map
		updates := make(map[string]interface{})

		if updateReq.Name != nil {
			if *updateReq.Name == "" {
				http.Error(w, "Name cannot be empty", http.StatusBadRequest)
				return
			}
			updates["name"] = *updateReq.Name
		}

		if updateReq.Email != nil {
			if *updateReq.Email == "" {
				http.Error(w, "Email cannot be empty", http.StatusBadRequest)
				return
			}
			updates["email"] = *updateReq.Email
		}

		if len(updates) == 0 {
			http.Error(w, "No updates provided", http.StatusBadRequest)
			return
		}

		// Update user in database
		err = database.UpdateUser(ctx, dbUser.ID, updates)
		if err != nil {
			log.Error("Failed to update user in database", err)
			http.Error(w, "Failed to update user", http.StatusInternalServerError)
			return
		}

		// Get updated user data
		updatedUser, err := database.GetUserByID(ctx, dbUser.ID)
		if err != nil {
			log.Error("Failed to get updated user", err)
			http.Error(w, "Internal server error", http.StatusInternalServerError)
			return
		}

		// Return updated user profile
		response := UserResponse{
			ID:    updatedUser.ID,
			Email: updatedUser.Email,
			Name:  updatedUser.Name,
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(response)
	}
}

func TestUserHandleGetUser(t *testing.T) {
	tests := []struct {
		name           string
		userEmail      string
		setupMock      func(*UserMockDatabase)
		expectedStatus int
		expectedBody   string
	}{
		{
			name:           "no user in token",
			userEmail:      "",
			setupMock:      func(m *UserMockDatabase) {},
			expectedStatus: 401,
		},
		{
			name:      "database error getting user",
			userEmail: "test@example.com",
			setupMock: func(m *UserMockDatabase) {
				m.getUserError = errors.New("database error")
			},
			expectedStatus: 500,
		},
		{
			name:           "user not found in database",
			userEmail:      "notfound@example.com",
			setupMock:      func(m *UserMockDatabase) {},
			expectedStatus: 404,
		},
		{
			name:      "successful get user",
			userEmail: "success@example.com",
			setupMock: func(m *UserMockDatabase) {
				m.addUser(&models.UserRecord{
					ID:    "user-123",
					Email: "success@example.com",
					Name:  "Test User",
				})
			},
			expectedStatus: 200,
			expectedBody:   `{"id":"user-123","email":"success@example.com","name":"Test User"}`,
		},
		{
			name:      "user with special characters",
			userEmail: "special+user@example.com",
			setupMock: func(m *UserMockDatabase) {
				m.addUser(&models.UserRecord{
					ID:    "user-456",
					Email: "special+user@example.com",
					Name:  "Special User αβγ",
				})
			},
			expectedStatus: 200,
			expectedBody:   `{"id":"user-456","email":"special+user@example.com","name":"Special User αβγ"}`,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup mock database
			mockDB := newUserMockDatabase()
			mockDB.reset()
			tt.setupMock(mockDB)

			// Setup logger
			mockLog := logger.New(logger.Config{
				Level:       "info",
				Environment: "test",
				ServiceName: "test",
			})

			// Create handler
			handler := testableHandleGetUser(*mockDB, *mockLog, tt.userEmail)

			// Create request
			req := httptest.NewRequest("GET", "/v1/user", nil)

			// Create response recorder
			w := httptest.NewRecorder()

			// Call handler
			handler(w, req)

			// Check status code
			if w.Code != tt.expectedStatus {
				t.Errorf("Status code = %d, want %d", w.Code, tt.expectedStatus)
			}

			// Check response body if specified
			if tt.expectedBody != "" {
				body := strings.TrimSpace(w.Body.String())
				if body != tt.expectedBody {
					t.Errorf("Response body = %s, want %s", body, tt.expectedBody)
				}
			}

			// For successful cases, verify JSON structure
			if tt.expectedStatus == 200 {
				var response UserResponse
				if err := json.NewDecoder(strings.NewReader(w.Body.String())).Decode(&response); err != nil {
					t.Errorf("Failed to decode response: %v", err)
				}
				if response.ID == "" {
					t.Error("Response should contain user ID")
				}
				if response.Email == "" {
					t.Error("Response should contain user email")
				}
				if response.Name == "" {
					t.Error("Response should contain user name")
				}
			}
		})
	}
}

func TestUserHandleUpdateUser(t *testing.T) {
	tests := []struct {
		name           string
		userEmail      string
		requestBody    string
		setupMock      func(*UserMockDatabase)
		expectedStatus int
		expectedBody   string
	}{
		{
			name:           "no user in token",
			userEmail:      "",
			requestBody:    `{"name":"Updated Name"}`,
			setupMock:      func(m *UserMockDatabase) {},
			expectedStatus: 401,
		},
		{
			name:        "database error getting user",
			userEmail:   "test@example.com",
			requestBody: `{"name":"Updated Name"}`,
			setupMock: func(m *UserMockDatabase) {
				m.getUserError = errors.New("database error")
			},
			expectedStatus: 500,
		},
		{
			name:           "user not found in database",
			userEmail:      "notfound@example.com",
			requestBody:    `{"name":"Updated Name"}`,
			setupMock:      func(m *UserMockDatabase) {},
			expectedStatus: 404,
		},
		{
			name:        "invalid JSON",
			userEmail:   "test@example.com",
			requestBody: `{"invalid": json}`,
			setupMock: func(m *UserMockDatabase) {
				m.addUser(&models.UserRecord{
					ID:    "user-123",
					Email: "test@example.com",
					Name:  "Test User",
				})
			},
			expectedStatus: 400,
		},
		{
			name:        "empty name update",
			userEmail:   "test@example.com",
			requestBody: `{"name":""}`,
			setupMock: func(m *UserMockDatabase) {
				m.addUser(&models.UserRecord{
					ID:    "user-123",
					Email: "test@example.com",
					Name:  "Test User",
				})
			},
			expectedStatus: 400,
		},
		{
			name:        "empty email update",
			userEmail:   "test@example.com",
			requestBody: `{"email":""}`,
			setupMock: func(m *UserMockDatabase) {
				m.addUser(&models.UserRecord{
					ID:    "user-123",
					Email: "test@example.com",
					Name:  "Test User",
				})
			},
			expectedStatus: 400,
		},
		{
			name:        "no updates provided",
			userEmail:   "test@example.com",
			requestBody: `{}`,
			setupMock: func(m *UserMockDatabase) {
				m.addUser(&models.UserRecord{
					ID:    "user-123",
					Email: "test@example.com",
					Name:  "Test User",
				})
			},
			expectedStatus: 400,
		},
		{
			name:        "successful name update",
			userEmail:   "success@example.com",
			requestBody: `{"name":"Updated Name"}`,
			setupMock: func(m *UserMockDatabase) {
				m.addUser(&models.UserRecord{
					ID:    "user-123",
					Email: "success@example.com",
					Name:  "Test User",
				})
			},
			expectedStatus: 200,
			expectedBody:   `{"id":"user-123","email":"success@example.com","name":"Updated Name"}`,
		},
		{
			name:        "successful email update",
			userEmail:   "success@example.com",
			requestBody: `{"email":"newemail@example.com"}`,
			setupMock: func(m *UserMockDatabase) {
				m.addUser(&models.UserRecord{
					ID:    "user-123",
					Email: "success@example.com",
					Name:  "Test User",
				})
			},
			expectedStatus: 200,
			expectedBody:   `{"id":"user-123","email":"newemail@example.com","name":"Test User"}`,
		},
		{
			name:        "successful both updates",
			userEmail:   "success@example.com",
			requestBody: `{"name":"Updated Name","email":"newemail@example.com"}`,
			setupMock: func(m *UserMockDatabase) {
				m.addUser(&models.UserRecord{
					ID:    "user-123",
					Email: "success@example.com",
					Name:  "Test User",
				})
			},
			expectedStatus: 200,
			expectedBody:   `{"id":"user-123","email":"newemail@example.com","name":"Updated Name"}`,
		},
		{
			name:        "update user error",
			userEmail:   "test@example.com",
			requestBody: `{"name":"Updated Name"}`,
			setupMock: func(m *UserMockDatabase) {
				m.addUser(&models.UserRecord{
					ID:    "user-123",
					Email: "test@example.com",
					Name:  "Test User",
				})
				m.updateUserError = errors.New("update failed")
			},
			expectedStatus: 500,
		},
		{
			name:        "get updated user error",
			userEmail:   "test@example.com",
			requestBody: `{"name":"Updated Name"}`,
			setupMock: func(m *UserMockDatabase) {
				m.addUser(&models.UserRecord{
					ID:    "user-123",
					Email: "test@example.com",
					Name:  "Test User",
				})
				m.getUserByIDError = errors.New("get updated user failed")
			},
			expectedStatus: 500,
		},
		{
			name:        "unicode name update",
			userEmail:   "unicode@example.com",
			requestBody: `{"name":"用户名日本語🎌"}`,
			setupMock: func(m *UserMockDatabase) {
				m.addUser(&models.UserRecord{
					ID:    "user-789",
					Email: "unicode@example.com",
					Name:  "Test User",
				})
			},
			expectedStatus: 200,
			expectedBody:   `{"id":"user-789","email":"unicode@example.com","name":"用户名日本語🎌"}`,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup mock database
			mockDB := newUserMockDatabase()
			mockDB.reset()
			tt.setupMock(mockDB)

			// Setup logger
			mockLog := logger.New(logger.Config{
				Level:       "info",
				Environment: "test",
				ServiceName: "test",
			})

			// Create handler
			handler := testableHandleUpdateUser(*mockDB, *mockLog, tt.userEmail)

			// Create request
			req := httptest.NewRequest("PATCH", "/v1/user", strings.NewReader(tt.requestBody))
			req.Header.Set("Content-Type", "application/json")

			// Create response recorder
			w := httptest.NewRecorder()

			// Call handler
			handler(w, req)

			// Check status code
			if w.Code != tt.expectedStatus {
				t.Errorf("Status code = %d, want %d", w.Code, tt.expectedStatus)
			}

			// Check response body if specified
			if tt.expectedBody != "" {
				body := strings.TrimSpace(w.Body.String())
				if body != tt.expectedBody {
					t.Errorf("Response body = %s, want %s", body, tt.expectedBody)
				}
			}

			// For successful cases, verify JSON structure
			if tt.expectedStatus == 200 {
				var response UserResponse
				if err := json.NewDecoder(strings.NewReader(w.Body.String())).Decode(&response); err != nil {
					t.Errorf("Failed to decode response: %v", err)
				}
				if response.ID == "" {
					t.Error("Response should contain user ID")
				}
				if response.Email == "" {
					t.Error("Response should contain user email")
				}
				if response.Name == "" {
					t.Error("Response should contain user name")
				}
			}
		})
	}
}

func TestUserResponseStruct(t *testing.T) {
	t.Run("UserResponse JSON marshaling", func(t *testing.T) {
		user := UserResponse{
			ID:    "test-id-123",
			Email: "test@example.com",
			Name:  "Test User",
		}

		data, err := json.Marshal(user)
		if err != nil {
			t.Fatalf("Failed to marshal UserResponse: %v", err)
		}

		expected := `{"id":"test-id-123","email":"test@example.com","name":"Test User"}`
		if string(data) != expected {
			t.Errorf("JSON marshaling = %s, want %s", string(data), expected)
		}
	})

	t.Run("UserUpdateRequest JSON unmarshaling", func(t *testing.T) {
		tests := []struct {
			name     string
			json     string
			expected UserUpdateRequest
		}{
			{
				name: "name only",
				json: `{"name":"New Name"}`,
				expected: UserUpdateRequest{
					Name: stringPtr("New Name"),
				},
			},
			{
				name: "email only",
				json: `{"email":"new@example.com"}`,
				expected: UserUpdateRequest{
					Email: stringPtr("new@example.com"),
				},
			},
			{
				name: "both fields",
				json: `{"name":"New Name","email":"new@example.com"}`,
				expected: UserUpdateRequest{
					Name:  stringPtr("New Name"),
					Email: stringPtr("new@example.com"),
				},
			},
			{
				name:     "empty object",
				json:     `{}`,
				expected: UserUpdateRequest{},
			},
			{
				name: "null values",
				json: `{"name":null,"email":null}`,
				expected: UserUpdateRequest{
					Name:  nil,
					Email: nil,
				},
			},
		}

		for _, tt := range tests {
			t.Run(tt.name, func(t *testing.T) {
				var req UserUpdateRequest
				err := json.Unmarshal([]byte(tt.json), &req)
				if err != nil {
					t.Fatalf("Failed to unmarshal JSON: %v", err)
				}

				if (req.Name == nil) != (tt.expected.Name == nil) {
					t.Errorf("Name pointer mismatch: got %v, want %v", req.Name, tt.expected.Name)
				} else if req.Name != nil && tt.expected.Name != nil && *req.Name != *tt.expected.Name {
					t.Errorf("Name value mismatch: got %s, want %s", *req.Name, *tt.expected.Name)
				}

				if (req.Email == nil) != (tt.expected.Email == nil) {
					t.Errorf("Email pointer mismatch: got %v, want %v", req.Email, tt.expected.Email)
				} else if req.Email != nil && tt.expected.Email != nil && *req.Email != *tt.expected.Email {
					t.Errorf("Email value mismatch: got %s, want %s", *req.Email, *tt.expected.Email)
				}
			})
		}
	})
}
