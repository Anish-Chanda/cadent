package handlers

import (
	"context"
	"crypto/rand"
	"crypto/subtle"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"net/mail"
	"strings"
	"time"

	"github.com/anish-chanda/cadence/backend/internal/db"
	"github.com/anish-chanda/cadence/backend/internal/logger"
	"github.com/anish-chanda/cadence/backend/internal/models"
	"github.com/google/uuid"
	"golang.org/x/crypto/argon2"
)

const (
	argonTime    = 1
	argonMemory  = 64 * 1024
	argonThreads = 4
	argonSaltLen = 16
	argonKeyLen  = 32
)

type SignupRequest struct {
	User   string `json:"user"`
	Passwd string `json:"passwd"`
	Name   string `json:"name"`
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
		name := strings.TrimSpace(req.Name)

		if email == "" || password == "" || name == "" {
			response := SignupResponse{
				Success: false,
				Message: "Email, password, and name are required",
			}
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusBadRequest)
			json.NewEncoder(w).Encode(response)
			return
		}

		// Validate email format using RFC 5322
		if _, err := mail.ParseAddress(email); err != nil {
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
		user, err := createUser(database, email, password, name)
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

// hashPassword applies Argon2id with OWASP‐recommended params and returns
// a single string in the standard "$argon2id$v=19$m=…,t=…,p=…$salt$hash" format.
func hashPassword(password string) (string, error) {
	salt := make([]byte, argonSaltLen)
	if _, err := rand.Read(salt); err != nil {
		return "", err
	}
	hash := argon2.IDKey(
		[]byte(password),
		salt,
		argonTime,
		argonMemory,
		argonThreads,
		argonKeyLen,
	)
	b64Salt := base64.RawStdEncoding.EncodeToString(salt)
	b64Hash := base64.RawStdEncoding.EncodeToString(hash)
	parts := []string{
		"argon2id",
		fmt.Sprintf("v=%d", argon2.Version),
		fmt.Sprintf("m=%d,t=%d,p=%d", argonMemory, argonTime, argonThreads),
		b64Salt,
		b64Hash,
	}
	return "$" + strings.Join(parts, "$"), nil
}

// verifyPassword parses and verifies an encoded Argon2id hash.
func verifyPassword(password, encoded string) (bool, error) {
	// encoded: $argon2id$v=19$m=...,t=...,p=...$<salt>$<hash>
	fields := strings.Split(encoded, "$")
	if len(fields) != 6 || fields[1] != "argon2id" {
		return false, fmt.Errorf("invalid hash format")
	}
	var memory, timeParam, threads uint32
	if _, err := fmt.Sscanf(fields[3], "m=%d,t=%d,p=%d", &memory, &timeParam, &threads); err != nil {
		return false, err
	}
	salt, err := base64.RawStdEncoding.DecodeString(fields[4])
	if err != nil {
		return false, err
	}
	hash, err := base64.RawStdEncoding.DecodeString(fields[5])
	if err != nil {
		return false, err
	}

	computed := argon2.IDKey([]byte(password), salt, timeParam, memory, uint8(threads), uint32(len(hash)))
	// constant-time compare
	if subtle.ConstantTimeCompare(computed, hash) == 1 {
		return true, nil
	}
	return false, nil
}

// HandleLogin handles local authentication by checking email and password
func HandleLogin(database db.Database, email, password string) (bool, error) {
	// Normalize email
	email = strings.TrimSpace(strings.ToLower(email))

	// Get user by email
	user, err := database.GetUserByEmail(context.TODO(), email)
	if err != nil {
		return false, fmt.Errorf("failed to get user: %w", err)
	}

	// User not found
	if user == nil {
		return false, nil
	}

	// Check if user uses local authentication
	if user.AuthProvider != models.AuthProviderLocal {
		return false, fmt.Errorf("user %s does not use local authentication", email)
	}

	// Check if password hash exists
	if user.PasswordHash == nil {
		return false, fmt.Errorf("user %s has no password set", email)
	}

	// Verify password
	isValid, err := verifyPassword(password, *user.PasswordHash)
	if err != nil {
		return false, fmt.Errorf("failed to verify password: %w", err)
	}
	if !isValid {
		return false, nil // Invalid password
	}

	return true, nil
}

// createUser creates a new user with hashed password
func createUser(database db.Database, email, password, name string) (*models.UserRecord, error) {
	// Generate unique ID
	userID, err := generateUserID()
	if err != nil {
		return nil, fmt.Errorf("failed to generate user ID: %w", err)
	}

	// Hash password
	hashedPassword, err := hashPassword(password)
	if err != nil {
		return nil, fmt.Errorf("failed to hash password: %w", err)
	}

	// Create user record
	now := time.Now().Unix()
	user := &models.UserRecord{
		ID:           userID,
		Email:        email,
		Name:         name,
		PasswordHash: &hashedPassword,
		AuthProvider: models.AuthProviderLocal,
		CreatedAt:    now,
		UpdatedAt:    now,
	}

	// Save to database
	err = database.CreateUser(context.TODO(), user)
	if err != nil {
		return nil, fmt.Errorf("failed to create user: %w", err)
	}

	return user, nil
}

// generateUserID generates a random hex string for user ID
func generateUserID() (string, error) {
	id := uuid.New().String()
	if id == "" {
		return "", fmt.Errorf("failed to generate UUID")
	}
	return id, nil
}
