package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"

	"github.com/anish-chanda/cadence/backend/internal/auth"
	"github.com/anish-chanda/cadence/backend/internal/db"
	"github.com/anish-chanda/cadence/backend/internal/logger"
)

type SignupRequest struct {
	User   string `json:"user"`
	Passwd string `json:"passwd"`
}

type SignupResponse struct {
	Success bool   `json:"success"`
	UserID  string `json:"user_id"`
	Message string `json:"message"`
}

// SignupHandler handles user registration
func SignupHandler(database db.Database, log logger.ServiceLogger) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		var req SignupRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			log.Error("Failed to decode signup request", err)
			response := SignupResponse{
				Success: false,
				Message: "Invalid request format",
			}
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusBadRequest)
			json.NewEncoder(w).Encode(response)
			return
		}

		// Validate input
		email := strings.TrimSpace(strings.ToLower(req.User))
		password := req.Passwd

		if email == "" || password == "" {
			response := SignupResponse{
				Success: false,
				Message: "Email and password are required",
			}
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusBadRequest)
			json.NewEncoder(w).Encode(response)
			return
		}

		if !strings.Contains(email, "@") {
			response := SignupResponse{
				Success: false,
				Message: "Invalid email format",
			}
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusBadRequest)
			json.NewEncoder(w).Encode(response)
			return
		}

		if len(password) < 6 {
			response := SignupResponse{
				Success: false,
				Message: "Password must be at least 6 characters long",
			}
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusBadRequest)
			json.NewEncoder(w).Encode(response)
			return
		}

		// Check if user already exists
		existingUser, err := database.GetUserByEmail(r.Context(), email)
		if err != nil {
			log.Error("Failed to check existing user", err)
			response := SignupResponse{
				Success: false,
				Message: "Internal server error",
			}
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusInternalServerError)
			json.NewEncoder(w).Encode(response)
			return
		}

		if existingUser != nil {
			response := SignupResponse{
				Success: false,
				Message: "User with this email already exists",
			}
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusConflict)
			json.NewEncoder(w).Encode(response)
			return
		}

		// Create new user
		user, err := auth.CreateUser(database, email, password)
		if err != nil {
			log.Error("Failed to create user", err)
			response := SignupResponse{
				Success: false,
				Message: "Failed to create user account",
			}
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusInternalServerError)
			json.NewEncoder(w).Encode(response)
			return
		}

		log.Info(fmt.Sprintf("User created successfully: %s", email))

		response := SignupResponse{
			Success: true,
			UserID:  user.ID,
			Message: "User created successfully",
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(response)
	}
}
