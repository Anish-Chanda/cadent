package auth

import (
	"context"
	"fmt"
	"time"

	"github.com/anish-chanda/cadence/backend/internal/db"
	"github.com/anish-chanda/cadence/backend/internal/models"
	"github.com/google/uuid"
)

// HandleLogin handles local authentication by checking email and password
func HandleLogin(database db.Database, email, password string) (bool, error) {
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
	isValid, err := VerifyPassword(password, *user.PasswordHash)
	if err != nil {
		return false, fmt.Errorf("failed to verify password: %w", err)
	}
	if !isValid {
		return false, nil // Invalid password
	}

	return true, nil
}

// CreateUser creates a new user with hashed password
func CreateUser(database db.Database, email, password, name string) (*models.UserRecord, error) {
	// Generate unique ID
	userID, err := generateUserID()
	if err != nil {
		return nil, fmt.Errorf("failed to generate user ID: %w", err)
	}

	// Hash password
	hashedPassword, err := HashPassword(password)
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
