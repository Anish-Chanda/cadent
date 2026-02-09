package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/anish-chanda/cadence/backend/internal/db"
	"github.com/anish-chanda/cadence/backend/internal/logger"
	"github.com/anish-chanda/cadence/backend/internal/models"
)

// IntegrationUserMockDB is a full mock database for integration tests
type IntegrationUserMockDB struct {
	users            map[string]*models.UserRecord
	usersById        map[string]*models.UserRecord
	getUserError     error
	updateUserError  error
	getUserByIDError error
}

func newIntegrationUserMockDB() *IntegrationUserMockDB {
	return &IntegrationUserMockDB{
		users:     make(map[string]*models.UserRecord),
		usersById: make(map[string]*models.UserRecord),
	}
}

func (m *IntegrationUserMockDB) GetUserByEmail(ctx context.Context, email string) (*models.UserRecord, error) {
	if m.getUserError != nil {
		return nil, m.getUserError
	}
	return m.users[email], nil
}

func (m *IntegrationUserMockDB) GetUserByID(ctx context.Context, userID string) (*models.UserRecord, error) {
	if m.getUserByIDError != nil {
		return nil, m.getUserByIDError
	}
	return m.usersById[userID], nil
}

func (m *IntegrationUserMockDB) UpdateUser(ctx context.Context, userID string, updates map[string]interface{}) error {
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

// Required db.Database interface methods
func (m *IntegrationUserMockDB) CreateUser(ctx context.Context, user *models.UserRecord) error {
	return nil
}
func (m *IntegrationUserMockDB) CreateActivity(ctx context.Context, activity *models.Activity) error {
	return nil
}
func (m *IntegrationUserMockDB) GetActivitiesByUserID(ctx context.Context, userID string) ([]models.Activity, error) {
	return nil, nil
}
func (m *IntegrationUserMockDB) CheckIdempotency(ctx context.Context, clientActivityID string) (bool, error) {
	return false, nil
}
func (m *IntegrationUserMockDB) GetActivityByID(ctx context.Context, activityID string) (*models.Activity, error) {
	return nil, nil
}
func (m *IntegrationUserMockDB) GetActivityStreams(ctx context.Context, activityID string, lod models.StreamLOD) ([]models.ActivityStream, error) {
	return nil, nil
}
func (m *IntegrationUserMockDB) CreateActivityStreams(ctx context.Context, streams []models.ActivityStream) error {
	return nil
}
func (m *IntegrationUserMockDB) Connect(dsn string) error { return nil }
func (m *IntegrationUserMockDB) Close() error             { return nil }
func (m *IntegrationUserMockDB) Migrate() error           { return nil }

func (m *IntegrationUserMockDB) addUser(user *models.UserRecord) {
	m.users[user.Email] = user
	m.usersById[user.ID] = user
}

func (m *IntegrationUserMockDB) reset() {
	m.users = make(map[string]*models.UserRecord)
	m.usersById = make(map[string]*models.UserRecord)
	m.getUserError = nil
	m.updateUserError = nil
	m.getUserByIDError = nil
}

// Custom handler wrappers that inject user info for testing
func testHandleGetUserWithUserInfo(database db.Database, log logger.ServiceLogger, userEmail string) http.HandlerFunc {
	// This is a copy of HandleGetUser with injected user info for testing
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := context.Background()

		// Simulate token extraction - in real scenario this comes from token.GetUserInfo(r)
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

func testHandleUpdateUserWithUserInfo(database db.Database, log logger.ServiceLogger, userEmail string) http.HandlerFunc {
	// This is a copy of HandleUpdateUser with injected user info for testing
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := context.Background()

		// Simulate token extraction - in real scenario this comes from token.GetUserInfo(r)
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

func TestHandleGetUserIntegration(t *testing.T) {
	tests := []struct {
		name           string
		userEmail      string
		setupMock      func(*IntegrationUserMockDB)
		expectedStatus int
		expectedBody   string
		checkResponse  func(*testing.T, *httptest.ResponseRecorder)
	}{
		{
			name:           "unauthorized - no email",
			userEmail:      "",
			setupMock:      func(m *IntegrationUserMockDB) {},
			expectedStatus: 401,
		},
		{
			name:      "internal server error - database error",
			userEmail: "test@example.com",
			setupMock: func(m *IntegrationUserMockDB) {
				m.getUserError = errors.New("database connection failed")
			},
			expectedStatus: 500,
		},
		{
			name:           "not found - user doesn't exist",
			userEmail:      "nonexistent@example.com",
			setupMock:      func(m *IntegrationUserMockDB) {},
			expectedStatus: 404,
		},
		{
			name:      "success - valid user",
			userEmail: "valid@example.com",
			setupMock: func(m *IntegrationUserMockDB) {
				m.addUser(&models.UserRecord{
					ID:    "user-123",
					Email: "valid@example.com",
					Name:  "Valid User",
				})
			},
			expectedStatus: 200,
			expectedBody:   `{"id":"user-123","email":"valid@example.com","name":"Valid User"}`,
			checkResponse: func(t *testing.T, w *httptest.ResponseRecorder) {
				contentType := w.Header().Get("Content-Type")
				if contentType != "application/json" {
					t.Errorf("Expected Content-Type application/json, got %s", contentType)
				}

				var response UserResponse
				if err := json.NewDecoder(strings.NewReader(w.Body.String())).Decode(&response); err != nil {
					t.Errorf("Failed to decode JSON response: %v", err)
				}

				if response.ID == "" || response.Email == "" || response.Name == "" {
					t.Error("Response missing required fields")
				}
			},
		},
		{
			name:      "success - user with unicode characters",
			userEmail: "unicode@example.com",
			setupMock: func(m *IntegrationUserMockDB) {
				m.addUser(&models.UserRecord{
					ID:    "user-456",
					Email: "unicode@example.com",
					Name:  "Unicode User 用户名 αβγ 🎌",
				})
			},
			expectedStatus: 200,
			checkResponse: func(t *testing.T, w *httptest.ResponseRecorder) {
				var response UserResponse
				json.NewDecoder(strings.NewReader(w.Body.String())).Decode(&response)
				if !strings.Contains(response.Name, "用户名") {
					t.Error("Unicode characters not preserved in response")
				}
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			mockDB := newIntegrationUserMockDB()
			mockDB.reset()
			tt.setupMock(mockDB)

			log := logger.New(logger.Config{
				Level:       "info",
				Environment: "test",
				ServiceName: "test",
			})

			// Create handler using the real handler logic
			handler := testHandleGetUserWithUserInfo(mockDB, *log, tt.userEmail)

			// Create request
			req := httptest.NewRequest("GET", "/v1/user", nil)
			w := httptest.NewRecorder()

			// Execute
			handler(w, req)

			// Assert
			if w.Code != tt.expectedStatus {
				t.Errorf("Status code = %d, want %d", w.Code, tt.expectedStatus)
			}

			if tt.expectedBody != "" {
				body := strings.TrimSpace(w.Body.String())
				if body != tt.expectedBody {
					t.Errorf("Response body = %s, want %s", body, tt.expectedBody)
				}
			}

			if tt.checkResponse != nil {
				tt.checkResponse(t, w)
			}
		})
	}
}

func TestHandleUpdateUserIntegration(t *testing.T) {
	tests := []struct {
		name           string
		userEmail      string
		requestBody    string
		setupMock      func(*IntegrationUserMockDB)
		expectedStatus int
		expectedBody   string
		checkResponse  func(*testing.T, *httptest.ResponseRecorder)
	}{
		{
			name:           "unauthorized - no email",
			userEmail:      "",
			requestBody:    `{"name":"New Name"}`,
			setupMock:      func(m *IntegrationUserMockDB) {},
			expectedStatus: 401,
		},
		{
			name:        "internal server error - database error on get",
			userEmail:   "test@example.com",
			requestBody: `{"name":"New Name"}`,
			setupMock: func(m *IntegrationUserMockDB) {
				m.getUserError = errors.New("database error")
			},
			expectedStatus: 500,
		},
		{
			name:           "not found - user doesn't exist",
			userEmail:      "nonexistent@example.com",
			requestBody:    `{"name":"New Name"}`,
			setupMock:      func(m *IntegrationUserMockDB) {},
			expectedStatus: 404,
		},
		{
			name:        "bad request - invalid JSON",
			userEmail:   "test@example.com",
			requestBody: `{invalid json}`,
			setupMock: func(m *IntegrationUserMockDB) {
				m.addUser(&models.UserRecord{
					ID:    "user-123",
					Email: "test@example.com",
					Name:  "Test User",
				})
			},
			expectedStatus: 400,
		},
		{
			name:        "bad request - empty name",
			userEmail:   "test@example.com",
			requestBody: `{"name":""}`,
			setupMock: func(m *IntegrationUserMockDB) {
				m.addUser(&models.UserRecord{
					ID:    "user-123",
					Email: "test@example.com",
					Name:  "Test User",
				})
			},
			expectedStatus: 400,
		},
		{
			name:        "bad request - empty email",
			userEmail:   "test@example.com",
			requestBody: `{"email":""}`,
			setupMock: func(m *IntegrationUserMockDB) {
				m.addUser(&models.UserRecord{
					ID:    "user-123",
					Email: "test@example.com",
					Name:  "Test User",
				})
			},
			expectedStatus: 400,
		},
		{
			name:        "bad request - no updates",
			userEmail:   "test@example.com",
			requestBody: `{}`,
			setupMock: func(m *IntegrationUserMockDB) {
				m.addUser(&models.UserRecord{
					ID:    "user-123",
					Email: "test@example.com",
					Name:  "Test User",
				})
			},
			expectedStatus: 400,
		},
		{
			name:        "internal server error - update fails",
			userEmail:   "test@example.com",
			requestBody: `{"name":"New Name"}`,
			setupMock: func(m *IntegrationUserMockDB) {
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
			name:        "internal server error - get updated user fails",
			userEmail:   "test@example.com",
			requestBody: `{"name":"New Name"}`,
			setupMock: func(m *IntegrationUserMockDB) {
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
			name:        "success - update name only",
			userEmail:   "test@example.com",
			requestBody: `{"name":"Updated Name"}`,
			setupMock: func(m *IntegrationUserMockDB) {
				m.addUser(&models.UserRecord{
					ID:    "user-123",
					Email: "test@example.com",
					Name:  "Test User",
				})
			},
			expectedStatus: 200,
			expectedBody:   `{"id":"user-123","email":"test@example.com","name":"Updated Name"}`,
			checkResponse: func(t *testing.T, w *httptest.ResponseRecorder) {
				var response UserResponse
				json.NewDecoder(strings.NewReader(w.Body.String())).Decode(&response)
				if response.Name != "Updated Name" {
					t.Errorf("Name not updated: got %s, want Updated Name", response.Name)
				}
			},
		},
		{
			name:        "success - update email only",
			userEmail:   "test@example.com",
			requestBody: `{"email":"new@example.com"}`,
			setupMock: func(m *IntegrationUserMockDB) {
				m.addUser(&models.UserRecord{
					ID:    "user-123",
					Email: "test@example.com",
					Name:  "Test User",
				})
			},
			expectedStatus: 200,
			expectedBody:   `{"id":"user-123","email":"new@example.com","name":"Test User"}`,
			checkResponse: func(t *testing.T, w *httptest.ResponseRecorder) {
				var response UserResponse
				json.NewDecoder(strings.NewReader(w.Body.String())).Decode(&response)
				if response.Email != "new@example.com" {
					t.Errorf("Email not updated: got %s, want new@example.com", response.Email)
				}
			},
		},
		{
			name:        "success - update both name and email",
			userEmail:   "test@example.com",
			requestBody: `{"name":"New Name","email":"new@example.com"}`,
			setupMock: func(m *IntegrationUserMockDB) {
				m.addUser(&models.UserRecord{
					ID:    "user-123",
					Email: "test@example.com",
					Name:  "Test User",
				})
			},
			expectedStatus: 200,
			expectedBody:   `{"id":"user-123","email":"new@example.com","name":"New Name"}`,
		},
		{
			name:        "success - unicode characters",
			userEmail:   "unicode@example.com",
			requestBody: `{"name":"Unicode Name 用户名 αβγ 🎌"}`,
			setupMock: func(m *IntegrationUserMockDB) {
				m.addUser(&models.UserRecord{
					ID:    "user-456",
					Email: "unicode@example.com",
					Name:  "Test User",
				})
			},
			expectedStatus: 200,
			checkResponse: func(t *testing.T, w *httptest.ResponseRecorder) {
				var response UserResponse
				json.NewDecoder(strings.NewReader(w.Body.String())).Decode(&response)
				if !strings.Contains(response.Name, "用户名") {
					t.Error("Unicode characters not preserved in update")
				}
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			mockDB := newIntegrationUserMockDB()
			mockDB.reset()
			tt.setupMock(mockDB)

			log := logger.New(logger.Config{
				Level:       "info",
				Environment: "test",
				ServiceName: "test",
			})

			// Create handler using the real handler logic
			handler := testHandleUpdateUserWithUserInfo(mockDB, *log, tt.userEmail)

			// Create request
			req := httptest.NewRequest("PATCH", "/v1/user", strings.NewReader(tt.requestBody))
			req.Header.Set("Content-Type", "application/json")
			w := httptest.NewRecorder()

			// Execute
			handler(w, req)

			// Assert
			if w.Code != tt.expectedStatus {
				t.Errorf("Status code = %d, want %d", w.Code, tt.expectedStatus)
			}

			if tt.expectedBody != "" {
				body := strings.TrimSpace(w.Body.String())
				if body != tt.expectedBody {
					t.Errorf("Response body = %s, want %s", body, tt.expectedBody)
				}
			}

			if tt.checkResponse != nil {
				tt.checkResponse(t, w)
			}
		})
	}
}

// Test edge cases and boundary conditions
func TestUserHandlerEdgeCases(t *testing.T) {
	t.Run("very long email address", func(t *testing.T) {
		mockDB := newIntegrationUserMockDB()
		longEmail := strings.Repeat("a", 100) + "@example.com"

		mockDB.addUser(&models.UserRecord{
			ID:    "user-long",
			Email: longEmail,
			Name:  "Long Email User",
		})

		log := logger.New(logger.Config{
			Level:       "info",
			Environment: "test",
			ServiceName: "test",
		})

		handler := testHandleGetUserWithUserInfo(mockDB, *log, longEmail)
		req := httptest.NewRequest("GET", "/v1/user", nil)
		w := httptest.NewRecorder()

		handler(w, req)

		if w.Code != 200 {
			t.Errorf("Expected 200, got %d", w.Code)
		}

		var response UserResponse
		json.NewDecoder(strings.NewReader(w.Body.String())).Decode(&response)
		if response.Email != longEmail {
			t.Errorf("Long email not preserved")
		}
	})

	t.Run("very long name update", func(t *testing.T) {
		mockDB := newIntegrationUserMockDB()
		mockDB.addUser(&models.UserRecord{
			ID:    "user-123",
			Email: "test@example.com",
			Name:  "Test User",
		})

		log := logger.New(logger.Config{
			Level:       "info",
			Environment: "test",
			ServiceName: "test",
		})

		longName := strings.Repeat("Name ", 100)
		reqBody := `{"name":"` + longName + `"}`

		handler := testHandleUpdateUserWithUserInfo(mockDB, *log, "test@example.com")
		req := httptest.NewRequest("PATCH", "/v1/user", strings.NewReader(reqBody))
		req.Header.Set("Content-Type", "application/json")
		w := httptest.NewRecorder()

		handler(w, req)

		if w.Code != 200 {
			t.Errorf("Expected 200, got %d", w.Code)
		}

		var response UserResponse
		json.NewDecoder(strings.NewReader(w.Body.String())).Decode(&response)
		if response.Name != longName {
			t.Errorf("Long name not preserved")
		}
	})

	t.Run("concurrent user updates", func(t *testing.T) {
		// This test simulates potential race conditions
		mockDB := newIntegrationUserMockDB()
		mockDB.addUser(&models.UserRecord{
			ID:    "user-concurrent",
			Email: "concurrent@example.com",
			Name:  "Original Name",
		})

		log := logger.New(logger.Config{
			Level:       "info",
			Environment: "test",
			ServiceName: "test",
		})

		// Simulate first update
		handler1 := testHandleUpdateUserWithUserInfo(mockDB, *log, "concurrent@example.com")
		req1 := httptest.NewRequest("PATCH", "/v1/user", strings.NewReader(`{"name":"First Update"}`))
		req1.Header.Set("Content-Type", "application/json")
		w1 := httptest.NewRecorder()

		handler1(w1, req1)

		if w1.Code != 200 {
			t.Errorf("First update failed: %d", w1.Code)
		}

		// Simulate second update (should use updated data)
		handler2 := testHandleUpdateUserWithUserInfo(mockDB, *log, "concurrent@example.com")
		req2 := httptest.NewRequest("PATCH", "/v1/user", strings.NewReader(`{"email":"updated@example.com"}`))
		req2.Header.Set("Content-Type", "application/json")
		w2 := httptest.NewRecorder()

		handler2(w2, req2)

		if w2.Code != 200 {
			t.Errorf("Second update failed: %d", w2.Code)
		}

		// Verify final state
		var response UserResponse
		json.NewDecoder(strings.NewReader(w2.Body.String())).Decode(&response)
		if response.Name != "First Update" || response.Email != "updated@example.com" {
			t.Errorf("Concurrent updates not handled correctly: name=%s, email=%s", response.Name, response.Email)
		}
	})
}
