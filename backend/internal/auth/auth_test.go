package auth

import (
	"context"
	"testing"

	"github.com/anish-chanda/cadence/backend/internal/models"
	"golang.org/x/crypto/bcrypt"
)

// MockDatabase implements the Database interface for testing
type MockDatabase struct {
	users map[string]*models.UserRecord
}

func NewMockDatabase() *MockDatabase {
	return &MockDatabase{
		users: make(map[string]*models.UserRecord),
	}
}

func (m *MockDatabase) GetUserByEmail(ctx context.Context, email string) (*models.UserRecord, error) {
	user, exists := m.users[email]
	if !exists {
		return nil, nil
	}
	return user, nil
}

func (m *MockDatabase) CreateUser(ctx context.Context, user *models.UserRecord) error {
	m.users[user.Email] = user
	return nil
}

func (m *MockDatabase) Connect(dsn string) error {
	return nil
}

func (m *MockDatabase) Close() error {
	return nil
}

func (m *MockDatabase) Migrate() error {
	return nil
}

func TestHandleLogin_ValidCredentials(t *testing.T) {
	db := NewMockDatabase()
	
	// Create a test user with hashed password
	password := "testpassword123"
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		t.Fatalf("Failed to hash password: %v", err)
	}
	
	passwordStr := string(hashedPassword)
	testUser := &models.UserRecord{
		ID:           "test-user-id",
		Email:        "test@example.com",
		PasswordHash: &passwordStr,
		AuthProvider: models.AuthProviderLocal,
		CreatedAt:    1234567890,
		UpdatedAt:    1234567890,
	}
	
	// Add user to mock database
	db.users["test@example.com"] = testUser
	
	// Test valid login
	success, err := HandleLogin(db, "test@example.com", password)
	if err != nil {
		t.Errorf("Expected no error, got: %v", err)
	}
	if !success {
		t.Error("Expected login to succeed")
	}
}

func TestHandleLogin_InvalidPassword(t *testing.T) {
	db := NewMockDatabase()
	
	// Create a test user with hashed password
	password := "testpassword123"
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		t.Fatalf("Failed to hash password: %v", err)
	}
	
	passwordStr := string(hashedPassword)
	testUser := &models.UserRecord{
		ID:           "test-user-id",
		Email:        "test@example.com",
		PasswordHash: &passwordStr,
		AuthProvider: models.AuthProviderLocal,
		CreatedAt:    1234567890,
		UpdatedAt:    1234567890,
	}
	
	// Add user to mock database
	db.users["test@example.com"] = testUser
	
	// Test invalid password
	success, err := HandleLogin(db, "test@example.com", "wrongpassword")
	if err != nil {
		t.Errorf("Expected no error, got: %v", err)
	}
	if success {
		t.Error("Expected login to fail with wrong password")
	}
}

func TestHandleLogin_UserNotFound(t *testing.T) {
	db := NewMockDatabase()
	
	// Test login for non-existent user
	success, err := HandleLogin(db, "nonexistent@example.com", "password")
	if err != nil {
		t.Errorf("Expected no error, got: %v", err)
	}
	if success {
		t.Error("Expected login to fail for non-existent user")
	}
}

func TestHandleLogin_NonLocalAuthProvider(t *testing.T) {
	db := NewMockDatabase()
	
	// Create a test user with OAuth provider
	testUser := &models.UserRecord{
		ID:           "test-user-id",
		Email:        "test@example.com",
		PasswordHash: nil,
		AuthProvider: "google", // Non-local provider
		CreatedAt:    1234567890,
		UpdatedAt:    1234567890,
	}
	
	// Add user to mock database
	db.users["test@example.com"] = testUser
	
	// Test login should fail for non-local auth provider
	success, err := HandleLogin(db, "test@example.com", "password")
	if err == nil {
		t.Error("Expected error for non-local auth provider")
	}
	if success {
		t.Error("Expected login to fail for non-local auth provider")
	}
}

func TestCreateUser_Success(t *testing.T) {
	db := NewMockDatabase()
	
	email := "newuser@example.com"
	password := "newpassword123"
	
	user, err := CreateUser(db, email, password)
	if err != nil {
		t.Fatalf("Expected no error, got: %v", err)
	}
	
	// Verify user was created correctly
	if user.Email != email {
		t.Errorf("Expected email %s, got %s", email, user.Email)
	}
	
	if user.AuthProvider != models.AuthProviderLocal {
		t.Errorf("Expected auth provider %s, got %s", models.AuthProviderLocal, user.AuthProvider)
	}
	
	if user.PasswordHash == nil {
		t.Error("Expected password hash to be set")
	}
	
	if user.ID == "" {
		t.Error("Expected user ID to be generated")
	}
	
	if user.CreatedAt == 0 {
		t.Error("Expected CreatedAt to be set")
	}
	
	if user.UpdatedAt == 0 {
		t.Error("Expected UpdatedAt to be set")
	}
	
	// Verify password was hashed correctly
	err = bcrypt.CompareHashAndPassword([]byte(*user.PasswordHash), []byte(password))
	if err != nil {
		t.Error("Password was not hashed correctly")
	}
	
	// Verify user was saved to database
	savedUser, err := db.GetUserByEmail(context.Background(), email)
	if err != nil {
		t.Fatalf("Failed to retrieve saved user: %v", err)
	}
	
	if savedUser == nil {
		t.Error("User was not saved to database")
	}
}

func TestGenerateUserID(t *testing.T) {
	id1, err := generateUserID()
	if err != nil {
		t.Fatalf("Failed to generate user ID: %v", err)
	}
	
	id2, err := generateUserID()
	if err != nil {
		t.Fatalf("Failed to generate user ID: %v", err)
	}
	
	// IDs should be non-empty
	if id1 == "" {
		t.Error("Generated ID should not be empty")
	}
	
	if id2 == "" {
		t.Error("Generated ID should not be empty")
	}
	
	// IDs should be unique
	if id1 == id2 {
		t.Error("Generated IDs should be unique")
	}
	
	// IDs should be valid UUIDs (36 characters with hyphens)
	if len(id1) != 36 {
		t.Errorf("Expected UUID length 36, got %d", len(id1))
	}
}
