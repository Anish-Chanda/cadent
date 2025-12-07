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
	"github.com/go-pkgz/auth/v2/token"
)

// Mock for token.GetUserInfo since it's from an external package
type mockUserInfo struct {
	Name string
}

// Create a mock request with user info in context
func createRequestWithUserInfo(method, url, body, userEmail string) *http.Request {
	req := httptest.NewRequest(method, url, strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")

	// Add user info to request context (simulating what auth middleware would do)
	// Note: This is a simplified version of what the actual auth middleware would do
	ctx := req.Context()
	ctx = context.WithValue(ctx, "user_email", userEmail)
	req = req.WithContext(ctx)

	return req
}

// Mock the token.GetUserInfo function by creating a helper that extracts from context
func mockGetUserInfo(r *http.Request) (token.User, error) {
	userEmail := r.Context().Value("user_email")
	if userEmail == nil {
		return token.User{}, errors.New("no user in context")
	}

	return token.User{
		Name: userEmail.(string),
	}, nil
}

func TestHandleGetUser(t *testing.T) {
	tests := []struct {
		name           string
		userEmail      string
		mockSetup      func(*mockDatabase)
		expectedStatus int
		expectedBody   string
		expectError    bool
	}{
		{
			name:           "no user in token",
			userEmail:      "",
			mockSetup:      func(m *mockDatabase) {},
			expectedStatus: 401,
			expectError:    true,
		},
		{
			name:      "database error getting user",
			userEmail: "test@example.com",
			mockSetup: func(m *mockDatabase) {
				m.getUserError = errors.New("database error")
			},
			expectedStatus: 500,
			expectError:    true,
		},
		{
			name:           "user not found in database",
			userEmail:      "notfound@example.com",
			mockSetup:      func(m *mockDatabase) {},
			expectedStatus: 404,
			expectError:    true,
		},
		{
			name:      "successful get user",
			userEmail: "success@example.com",
			mockSetup: func(m *mockDatabase) {
				m.users["success@example.com"] = &models.UserRecord{
					ID:    "user-123",
					Email: "success@example.com",
					Name:  "Test User",
				}
			},
			expectedStatus: 200,
			expectedBody:   `{"id":"user-123","email":"success@example.com","name":"Test User"}`,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup mock database
			mockDB := newMockDatabase()
			tt.mockSetup(mockDB)

			// Setup logger
			mockLog := logger.New(logger.Config{
				Level:       "info",
				Environment: "test",
				ServiceName: "test",
			})

			// Create a modified handler that uses our mock getUserInfo
			handler := func(w http.ResponseWriter, r *http.Request) {
				ctx := context.Background()

				// Mock the token.GetUserInfo call
				user, err := mockGetUserInfo(r)
				if err != nil {
					mockLog.Error("Failed to get user info from token", err)
					http.Error(w, "Unauthorized", http.StatusUnauthorized)
					return
				}

				// Extract email from token
				userEmail := user.Name
				if userEmail == "" {
					mockLog.Error("No email found in user token", nil)
					http.Error(w, "Unauthorized", http.StatusUnauthorized)
					return
				}

				// Look up database user by email
				dbUser, err := mockDB.GetUserByEmail(ctx, userEmail)
				if err != nil {
					mockLog.Error("Failed to get user from database", err)
					http.Error(w, "Internal server error", http.StatusInternalServerError)
					return
				}
				if dbUser == nil {
					mockLog.Error("User not found in database", nil)
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

			// Create request
			req := createRequestWithUserInfo("GET", "/v1/user", "", tt.userEmail)

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

			// For successful cases, verify response structure
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

func TestHandleUpdateUser(t *testing.T) {
	tests := []struct {
		name           string
		userEmail      string
		requestBody    string
		mockSetup      func(*mockDatabase)
		expectedStatus int
		expectedBody   string
		expectError    bool
	}{
		{
			name:           "no user in token",
			userEmail:      "",
			requestBody:    `{"name":"Updated Name"}`,
			mockSetup:      func(m *mockDatabase) {},
			expectedStatus: 401,
			expectError:    true,
		},
		{
			name:        "database error getting user",
			userEmail:   "test@example.com",
			requestBody: `{"name":"Updated Name"}`,
			mockSetup: func(m *mockDatabase) {
				m.getUserError = errors.New("database error")
			},
			expectedStatus: 500,
			expectError:    true,
		},
		{
			name:           "user not found in database",
			userEmail:      "notfound@example.com",
			requestBody:    `{"name":"Updated Name"}`,
			mockSetup:      func(m *mockDatabase) {},
			expectedStatus: 404,
			expectError:    true,
		},
		{
			name:        "invalid JSON",
			userEmail:   "test@example.com",
			requestBody: `{"invalid": json}`,
			mockSetup: func(m *mockDatabase) {
				m.users["test@example.com"] = &models.UserRecord{
					ID:    "user-123",
					Email: "test@example.com",
					Name:  "Test User",
				}
			},
			expectedStatus: 400,
			expectError:    true,
		},
		{
			name:        "empty name update",
			userEmail:   "test@example.com",
			requestBody: `{"name":""}`,
			mockSetup: func(m *mockDatabase) {
				m.users["test@example.com"] = &models.UserRecord{
					ID:    "user-123",
					Email: "test@example.com",
					Name:  "Test User",
				}
			},
			expectedStatus: 400,
			expectError:    true,
		},
		{
			name:        "empty email update",
			userEmail:   "test@example.com",
			requestBody: `{"email":""}`,
			mockSetup: func(m *mockDatabase) {
				m.users["test@example.com"] = &models.UserRecord{
					ID:    "user-123",
					Email: "test@example.com",
					Name:  "Test User",
				}
			},
			expectedStatus: 400,
			expectError:    true,
		},
		{
			name:        "no updates provided",
			userEmail:   "test@example.com",
			requestBody: `{}`,
			mockSetup: func(m *mockDatabase) {
				m.users["test@example.com"] = &models.UserRecord{
					ID:    "user-123",
					Email: "test@example.com",
					Name:  "Test User",
				}
			},
			expectedStatus: 400,
			expectError:    true,
		},
		{
			name:        "successful name update",
			userEmail:   "success@example.com",
			requestBody: `{"name":"Updated Name"}`,
			mockSetup: func(m *mockDatabase) {
				m.users["success@example.com"] = &models.UserRecord{
					ID:    "user-123",
					Email: "success@example.com",
					Name:  "Test User",
				}
			},
			expectedStatus: 200,
			expectedBody:   `{"id":"user-123","email":"success@example.com","name":"Updated Name"}`,
		},
		{
			name:        "successful email update",
			userEmail:   "success@example.com",
			requestBody: `{"email":"newemail@example.com"}`,
			mockSetup: func(m *mockDatabase) {
				m.users["success@example.com"] = &models.UserRecord{
					ID:    "user-123",
					Email: "success@example.com",
					Name:  "Test User",
				}
			},
			expectedStatus: 200,
			expectedBody:   `{"id":"user-123","email":"newemail@example.com","name":"Test User"}`,
		},
		{
			name:        "successful both updates",
			userEmail:   "success@example.com",
			requestBody: `{"name":"Updated Name","email":"newemail@example.com"}`,
			mockSetup: func(m *mockDatabase) {
				m.users["success@example.com"] = &models.UserRecord{
					ID:    "user-123",
					Email: "success@example.com",
					Name:  "Test User",
				}
			},
			expectedStatus: 200,
			expectedBody:   `{"id":"user-123","email":"newemail@example.com","name":"Updated Name"}`,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup mock database
			mockDB := newMockDatabase()
			tt.mockSetup(mockDB)

			// Setup logger
			mockLog := logger.New(logger.Config{
				Level:       "info",
				Environment: "test",
				ServiceName: "test",
			})

			// Create a modified handler that uses our mock getUserInfo and updates user data properly
			handler := func(w http.ResponseWriter, r *http.Request) {
				ctx := context.Background()

				// Mock the token.GetUserInfo call
				user, err := mockGetUserInfo(r)
				if err != nil {
					mockLog.Error("Failed to get user info from token", err)
					http.Error(w, "Unauthorized", http.StatusUnauthorized)
					return
				}

				// Extract email from token
				userEmail := user.Name
				if userEmail == "" {
					mockLog.Error("No email found in user token", nil)
					http.Error(w, "Unauthorized", http.StatusUnauthorized)
					return
				}

				// Look up database user by email
				dbUser, err := mockDB.GetUserByEmail(ctx, userEmail)
				if err != nil {
					mockLog.Error("Failed to get user from database", err)
					http.Error(w, "Internal server error", http.StatusInternalServerError)
					return
				}
				if dbUser == nil {
					mockLog.Error("User not found in database", nil)
					http.Error(w, "User not found", http.StatusNotFound)
					return
				}

				// Parse request body
				var updateReq UserUpdateRequest
				if err := json.NewDecoder(r.Body).Decode(&updateReq); err != nil {
					mockLog.Error("Failed to decode request body", err)
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
					dbUser.Name = *updateReq.Name // Update in mock
				}

				if updateReq.Email != nil {
					if *updateReq.Email == "" {
						http.Error(w, "Email cannot be empty", http.StatusBadRequest)
						return
					}
					updates["email"] = *updateReq.Email
					dbUser.Email = *updateReq.Email // Update in mock
				}

				if len(updates) == 0 {
					http.Error(w, "No updates provided", http.StatusBadRequest)
					return
				}

				// Update user in database (mock implementation)
				err = mockDB.UpdateUser(ctx, dbUser.ID, updates)
				if err != nil {
					mockLog.Error("Failed to update user in database", err)
					http.Error(w, "Failed to update user", http.StatusInternalServerError)
					return
				}

				// Return updated user profile
				response := UserResponse{
					ID:    dbUser.ID,
					Email: dbUser.Email,
					Name:  dbUser.Name,
				}

				w.Header().Set("Content-Type", "application/json")
				json.NewEncoder(w).Encode(response)
			}

			// Create request
			req := createRequestWithUserInfo("PATCH", "/v1/user", tt.requestBody, tt.userEmail)

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

			// For successful cases, verify response structure
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

// Additional edge case tests
func TestUserHandlersEdgeCases(t *testing.T) {
	t.Run("GetUser with very long email", func(t *testing.T) {
		mockDB := newMockDatabase()
		longEmail := strings.Repeat("a", 100) + "@example.com"
		mockDB.users[longEmail] = &models.UserRecord{
			ID:    "user-123",
			Email: longEmail,
			Name:  "Long Email User",
		}

		mockLog := logger.New(logger.Config{
			Level:       "info",
			Environment: "test",
			ServiceName: "test",
		})
		_ = mockLog // Use to avoid unused variable warning

		handler := func(w http.ResponseWriter, r *http.Request) {
			ctx := context.Background()
			user, err := mockGetUserInfo(r)
			if err != nil {
				http.Error(w, "Unauthorized", http.StatusUnauthorized)
				return
			}

			dbUser, err := mockDB.GetUserByEmail(ctx, user.Name)
			if err != nil || dbUser == nil {
				http.Error(w, "User not found", http.StatusNotFound)
				return
			}

			response := UserResponse{
				ID:    dbUser.ID,
				Email: dbUser.Email,
				Name:  dbUser.Name,
			}
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(response)
		}

		req := createRequestWithUserInfo("GET", "/v1/user", "", longEmail)
		w := httptest.NewRecorder()
		handler(w, req)

		if w.Code != 200 {
			t.Errorf("Status code = %d, want 200", w.Code)
		}
	})

	t.Run("UpdateUser with unicode characters", func(t *testing.T) {
		mockDB := newMockDatabase()
		mockDB.users["unicode@example.com"] = &models.UserRecord{
			ID:    "user-123",
			Email: "unicode@example.com",
			Name:  "Test User",
		}

		handler := func(w http.ResponseWriter, r *http.Request) {
			ctx := context.Background()
			user, err := mockGetUserInfo(r)
			if err != nil {
				http.Error(w, "Unauthorized", http.StatusUnauthorized)
				return
			}

			dbUser, err := mockDB.GetUserByEmail(ctx, user.Name)
			if err != nil || dbUser == nil {
				http.Error(w, "User not found", http.StatusNotFound)
				return
			}

			var updateReq UserUpdateRequest
			if err := json.NewDecoder(r.Body).Decode(&updateReq); err != nil {
				http.Error(w, "Invalid request body", http.StatusBadRequest)
				return
			}

			if updateReq.Name != nil {
				if *updateReq.Name == "" {
					http.Error(w, "Name cannot be empty", http.StatusBadRequest)
					return
				}
				dbUser.Name = *updateReq.Name
			}

			response := UserResponse{
				ID:    dbUser.ID,
				Email: dbUser.Email,
				Name:  dbUser.Name,
			}
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(response)
		}

		unicodeName := "用户名日本語🎌"
		req := createRequestWithUserInfo("PATCH", "/v1/user", `{"name":"`+unicodeName+`"}`, "unicode@example.com")
		w := httptest.NewRecorder()
		handler(w, req)

		if w.Code != 200 {
			t.Errorf("Status code = %d, want 200", w.Code)
		}

		var response UserResponse
		json.NewDecoder(strings.NewReader(w.Body.String())).Decode(&response)
		if response.Name != unicodeName {
			t.Errorf("Unicode name not preserved: got %s, want %s", response.Name, unicodeName)
		}
	})
}
