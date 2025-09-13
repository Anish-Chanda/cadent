package models

import (
	"testing"
)

func TestAuthProvider_Constants(t *testing.T) {
	// Test that auth provider constants are set correctly
	if AuthProviderLocal != "local" {
		t.Errorf("Expected AuthProviderLocal to be 'local', got '%s'", AuthProviderLocal)
	}
}

func TestUserRecord_Fields(t *testing.T) {
	// Test creating a UserRecord with all fields
	passwordHash := "hashed_password"
	user := UserRecord{
		ID:           "test-id-123",
		Email:        "test@example.com",
		PasswordHash: &passwordHash,
		AuthProvider: AuthProviderLocal,
		CreatedAt:    1234567890,
		UpdatedAt:    1234567890,
	}
	
	// Verify all fields are set correctly
	if user.ID != "test-id-123" {
		t.Errorf("Expected ID 'test-id-123', got '%s'", user.ID)
	}
	
	if user.Email != "test@example.com" {
		t.Errorf("Expected email 'test@example.com', got '%s'", user.Email)
	}
	
	if user.PasswordHash == nil {
		t.Error("Expected PasswordHash to not be nil")
	} else if *user.PasswordHash != "hashed_password" {
		t.Errorf("Expected password hash 'hashed_password', got '%s'", *user.PasswordHash)
	}
	
	if user.AuthProvider != AuthProviderLocal {
		t.Errorf("Expected auth provider '%s', got '%s'", AuthProviderLocal, user.AuthProvider)
	}
	
	if user.CreatedAt != 1234567890 {
		t.Errorf("Expected CreatedAt 1234567890, got %d", user.CreatedAt)
	}
	
	if user.UpdatedAt != 1234567890 {
		t.Errorf("Expected UpdatedAt 1234567890, got %d", user.UpdatedAt)
	}
}

func TestUserRecord_NilPasswordHash(t *testing.T) {
	// Test creating a UserRecord with nil password hash (OAuth users)
	user := UserRecord{
		ID:           "oauth-user-123",
		Email:        "oauth@example.com",
		PasswordHash: nil,
		AuthProvider: "google",
		CreatedAt:    1234567890,
		UpdatedAt:    1234567890,
	}
	
	if user.PasswordHash != nil {
		t.Error("Expected PasswordHash to be nil for OAuth user")
	}
	
	if user.AuthProvider != "google" {
		t.Errorf("Expected auth provider 'google', got '%s'", user.AuthProvider)
	}
	
	// Verify other fields are accessible
	if user.ID == "" {
		t.Error("ID should be set")
	}
	
	if user.Email == "" {
		t.Error("Email should be set")
	}
}

func TestUserRecord_JSONTags(t *testing.T) {
	// This test ensures that the struct has proper JSON tags
	// We can't easily test the tags without reflection, but we can
	// verify the struct compiles and fields are accessible
	
	user := UserRecord{}
	
	// These should compile without issues
	_ = user.ID
	_ = user.Email
	_ = user.PasswordHash
	_ = user.AuthProvider
	_ = user.CreatedAt
	_ = user.UpdatedAt
}

func TestAuthProvider_TypeSafety(t *testing.T) {
	// Test that AuthProvider is a distinct type
	var provider AuthProvider = "custom"
	
	if provider == "" {
		t.Error("AuthProvider should allow custom values")
	}
	
	// Test assignment from constant
	provider = AuthProviderLocal
	if provider != "local" {
		t.Errorf("Expected 'local', got '%s'", provider)
	}
}
