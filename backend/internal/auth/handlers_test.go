package auth

import (
	"context"
	"errors"
	"testing"

	"github.com/anish-chanda/cadence/backend/internal/models"
)

// mockDB implements the minimal db.Database interface needed for tests.
type mockDB struct {
	getUserFunc func(ctx context.Context, email string) (*models.UserRecord, error)
}

func (m *mockDB) GetUserByEmail(ctx context.Context, email string) (*models.UserRecord, error) {
	if m.getUserFunc != nil {
		return m.getUserFunc(ctx, email)
	}
	return nil, nil
}

// The rest of the interface methods are not used by HandleLocalLogin; provide
// no-op implementations to satisfy the interface.
func (m *mockDB) CreateUser(ctx context.Context, user *models.UserRecord) error       { return nil }
func (m *mockDB) CreateActivity(ctx context.Context, activity *models.Activity) error { return nil }
func (m *mockDB) GetActivitiesByUserID(ctx context.Context, userID string) ([]models.Activity, error) {
	return nil, nil
}
func (m *mockDB) CheckIdempotency(ctx context.Context, clientActivityID string) (bool, error) {
	return false, nil
}
func (m *mockDB) GetActivityByID(ctx context.Context, activityID string) (*models.Activity, error) {
	return nil, nil
}
func (m *mockDB) GetActivityStreams(ctx context.Context, activityID string, lod models.StreamLOD) ([]models.ActivityStream, error) {
	return nil, nil
}
func (m *mockDB) CreateActivityStreams(ctx context.Context, streams []models.ActivityStream) error {
	return nil
}
func (m *mockDB) Connect(dsn string) error { return nil }
func (m *mockDB) Close() error             { return nil }
func (m *mockDB) Migrate() error           { return nil }

func ptr(s string) *string { return &s }

func TestHandleLocalLogin_Behavior(t *testing.T) {
	// DB error
	dbErr := &mockDB{getUserFunc: func(ctx context.Context, email string) (*models.UserRecord, error) {
		return nil, errors.New("db failure")
	}}
	ok, err := HandleLocalLogin(dbErr, "u@example.com", "pw")
	if ok || err == nil {
		t.Fatalf("expected db error, got ok=%v err=%v", ok, err)
	}

	// No user
	dbNoUser := &mockDB{getUserFunc: func(ctx context.Context, email string) (*models.UserRecord, error) {
		return nil, nil
	}}
	ok, err = HandleLocalLogin(dbNoUser, "u@example.com", "pw")
	if ok || err != nil {
		t.Fatalf("expected no user (ok=false, err=nil), got ok=%v err=%v", ok, err)
	}

	// User exists but has no password
	dbNoPass := &mockDB{getUserFunc: func(ctx context.Context, email string) (*models.UserRecord, error) {
		return &models.UserRecord{Email: email, PasswordHash: nil}, nil
	}}
	ok, err = HandleLocalLogin(dbNoPass, "u@example.com", "pw")
	if ok || err == nil || err.Error() != "user has no password set" {
		t.Fatalf("expected 'user has no password set', got ok=%v err=%v", ok, err)
	}

	// Verification returns an error (invalid hash format)
	dbBadHash := &mockDB{getUserFunc: func(ctx context.Context, email string) (*models.UserRecord, error) {
		h := "bad-hash"
		return &models.UserRecord{Email: email, PasswordHash: &h}, nil
	}}
	ok, err = HandleLocalLogin(dbBadHash, "u@example.com", "pw")
	if ok || err == nil || !contains(err.Error(), "failed to verify password") {
		t.Fatalf("expected verify-password error, got ok=%v err=%v", ok, err)
	}

	// Invalid credentials (hash valid but password wrong)
	goodHash, herr := HashPassword("correct-password")
	if herr != nil {
		t.Fatalf("HashPassword failed: %v", herr)
	}
	dbWrongPass := &mockDB{getUserFunc: func(ctx context.Context, email string) (*models.UserRecord, error) {
		return &models.UserRecord{Email: email, PasswordHash: &goodHash}, nil
	}}
	ok, err = HandleLocalLogin(dbWrongPass, "u@example.com", "incorrect")
	if ok || err == nil || err.Error() != "invalid credentials" {
		t.Fatalf("expected invalid credentials, got ok=%v err=%v", ok, err)
	}

	// Success
	goodHash2, herr2 := HashPassword("s3cret")
	if herr2 != nil {
		t.Fatalf("HashPassword failed: %v", herr2)
	}
	dbGood := &mockDB{getUserFunc: func(ctx context.Context, email string) (*models.UserRecord, error) {
		return &models.UserRecord{Email: email, PasswordHash: &goodHash2}, nil
	}}
	ok, err = HandleLocalLogin(dbGood, "u@example.com", "s3cret")
	if !ok || err != nil {
		t.Fatalf("expected success, got ok=%v err=%v", ok, err)
	}
}

func contains(haystack, needle string) bool {
	return len(needle) == 0 || (len(haystack) >= len(needle) && (stringIndex(haystack, needle) >= 0))
}

// simple implementation of strings.Contains to avoid importing extra packages
func stringIndex(s, sep string) int {
	for i := 0; i+len(sep) <= len(s); i++ {
		if s[i:i+len(sep)] == sep {
			return i
		}
	}
	return -1
}
