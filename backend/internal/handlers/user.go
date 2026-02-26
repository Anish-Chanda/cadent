package handlers

import (
	"context"
	"encoding/json"
	"net/http"
	"net/mail"
	"strings"

	"github.com/anish-chanda/cadence/backend/internal/db"
	"github.com/anish-chanda/cadence/backend/internal/logger"
	"github.com/go-pkgz/auth/v2/token"
)

// UserResponse represents the user data returned to clients
type UserResponse struct {
	ID    string `json:"id"`
	Email string `json:"email"`
	Name  string `json:"name"`
}

// UserUpdateRequest represents the request body for updating user data
type UserUpdateRequest struct {
	Name  *string `json:"name"`
	Email *string `json:"email"`
}

// HandleGetUser handles GET /v1/user - returns user profile information
func HandleGetUser(database db.Database, log logger.ServiceLogger) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := context.Background()

		// Get authenticated user information
		user, err := token.GetUserInfo(r)
		if err != nil {
			log.Error("Failed to get user info from token", err)
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}

		// Extract email from token
		userEmail := user.Name
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

// HandleUpdateUser handles PATCH /v1/user - updates user profile information
func HandleUpdateUser(database db.Database, log logger.ServiceLogger) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := context.Background()

		// Get authenticated user information
		user, err := token.GetUserInfo(r)
		if err != nil {
			log.Error("Failed to get user info from token", err)
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}

		// Extract email from token
		userEmail := user.Name
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
			trimmedName := strings.TrimSpace(*updateReq.Name)
			if trimmedName == "" {
				http.Error(w, "Name cannot be empty", http.StatusBadRequest)
				return
			}
			updates["name"] = trimmedName
		}

		if updateReq.Email != nil {
			trimmedEmail := strings.TrimSpace(strings.ToLower(*updateReq.Email))
			if trimmedEmail == "" {
				http.Error(w, "Email cannot be empty", http.StatusBadRequest)
				return
			}
			// Validate email format using RFC 5322
			if _, err := mail.ParseAddress(trimmedEmail); err != nil {
				http.Error(w, "Invalid email format", http.StatusBadRequest)
				return
			}
			updates["email"] = trimmedEmail
			//this might trigger email verification in future
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

		// Get updated user data, might have changed by other instances
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
