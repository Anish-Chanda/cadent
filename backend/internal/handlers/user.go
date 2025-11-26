package handlers

import (
	"context"
	"encoding/json"
	"net/http"

	"github.com/anish-chanda/cadence/backend/internal/db"
	"github.com/anish-chanda/cadence/backend/internal/logger"
	"github.com/go-pkgz/auth/v2/token"
)

func HandleGetName(database db.Database, log logger.ServiceLogger) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := context.Background()

		// Get authenticated user information using go-pkgz/auth token package
		user, err := token.GetUserInfo(r)
		if err != nil {
			log.Error("Failed to get user info from token", err)
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}

		// The go-pkgz/auth package generates its own user IDs, but we need to map to our database user ID
		// Extract email from the token (stored as "Name" field by go-pkgz/auth local provider)
		userEmail := user.Name
		if userEmail == "" {
			log.Error("No email found in user token", nil)
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}

		// Look up the actual database user ID using the email
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

		userID := dbUser.ID

		// Get user's activities from database
		name, err := database.GetNameByUserID(ctx, userID)
		if err != nil {
			log.Error("Failed to get name from database", err)
			http.Error(w, "Failed to retrieve name", http.StatusInternalServerError)
			return
		}

		response := name

		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(response)
	}
}

func HandleChangeName(database db.Database, log logger.ServiceLogger) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := context.Background()

		// Get authenticated user information using go-pkgz/auth token package
		user, err := token.GetUserInfo(r)
		if err != nil {
			log.Error("Failed to get user info from token", err)
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}

		// The go-pkgz/auth package generates its own user IDs, but we need to map to our database user ID
		// Extract email from the token (stored as "Name" field by go-pkgz/auth local provider)
		userEmail := user.Name
		if userEmail == "" {
			log.Error("No email found in user token", nil)
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}

		// Look up the actual database user ID using the email
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

		userID := dbUser.ID

        var body struct {
            NewName string `json:"newName"`
        }

		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
            log.Error("Failed to decode request body", err)
            http.Error(w, "Invalid request body", http.StatusBadRequest)
            return
        }

        if body.NewName == "" {
            log.Error("New name is empty", nil)
            http.Error(w, "Name cannot be empty", http.StatusBadRequest)
            return
        }

        // Update the user's name in the database
        updatedName, err := database.ChangeNameByUserID(ctx, userID, body.NewName)
        if err != nil {
            log.Error("Failed to update name in database", err)
            http.Error(w, "Failed to update name", http.StatusInternalServerError)
            return
        }

        if updatedName == false {
            // This means no user was found with the ID
            log.Error("User not found when updating name", nil)
            http.Error(w, "User not found", http.StatusNotFound)
            return
        }

        response := map[string]bool{
            "success": updatedName,
        }

        w.Header().Set("Content-Type", "application/json")
        _ = json.NewEncoder(w).Encode(response)
	}
}