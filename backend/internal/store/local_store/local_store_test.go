package local_store

import (
	"context"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/anish-chanda/cadence/backend/internal/logger"
)

func setupTestStore(t *testing.T) (*LocalStore, string) {
	// Create temporary directory for testing
	tempDir, err := os.MkdirTemp("", "local_store_test_*")
	if err != nil {
		t.Fatalf("Failed to create temp directory: %v", err)
	}

	// Create a test logger
	loggerConfig := logger.Config{
		Level:       "error", // Set to error to suppress logs during tests
		Environment: "test",
	}
	testLogger := logger.New(loggerConfig)

	store := NewLocalStore(*testLogger)
	return store, tempDir
}

func cleanupTestStore(t *testing.T, tempDir string) {
	if err := os.RemoveAll(tempDir); err != nil {
		t.Errorf("Failed to cleanup temp directory: %v", err)
	}
}

func TestLocalStore_Connect(t *testing.T) {
	store, tempDir := setupTestStore(t)
	defer cleanupTestStore(t, tempDir)

	dsn := "local://" + tempDir
	err := store.Connect(dsn)
	if err != nil {
		t.Errorf("Connect() failed: %v", err)
	}

	// Check if directory exists
	if _, err := os.Stat(tempDir); os.IsNotExist(err) {
		t.Error("Connect() did not ensure base directory exists")
	}
}

func TestLocalStore_Connect_InvalidDSN(t *testing.T) {
	store, tempDir := setupTestStore(t)
	defer cleanupTestStore(t, tempDir)

	tests := []struct {
		name string
		dsn  string
	}{
		{"invalid scheme", "s3://bucket"},
		{"empty dsn", ""},
		{"malformed dsn", "not-a-dsn"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := store.Connect(tt.dsn)
			if err == nil {
				t.Errorf("Connect() should have failed for DSN: %s", tt.dsn)
			}
		})
	}
}

func TestLocalStore_PutObject(t *testing.T) {
	store, tempDir := setupTestStore(t)
	defer cleanupTestStore(t, tempDir)

	dsn := "local://" + tempDir
	err := store.Connect(dsn)
	if err != nil {
		t.Fatalf("Connect() failed: %v", err)
	}

	ctx := context.Background()
	key := "test/file.txt"
	content := "test content"
	data := strings.NewReader(content)
	size := int64(len(content))

	err = store.PutObject(ctx, key, data, size)
	if err != nil {
		t.Errorf("PutObject() failed: %v", err)
	}

	// Check if file was created
	filePath := filepath.Join(tempDir, "test", "file.txt")
	if _, err := os.Stat(filePath); os.IsNotExist(err) {
		t.Error("PutObject() did not create file")
	}

	// Check file content
	fileContent, err := os.ReadFile(filePath)
	if err != nil {
		t.Errorf("Failed to read uploaded file: %v", err)
	}
	if string(fileContent) != content {
		t.Errorf("File content mismatch. Expected: '%s', got: '%s'", content, string(fileContent))
	}
}

func TestLocalStore_GetObject(t *testing.T) {
	store, tempDir := setupTestStore(t)
	defer cleanupTestStore(t, tempDir)

	dsn := "local://" + tempDir
	err := store.Connect(dsn)
	if err != nil {
		t.Fatalf("Connect() failed: %v", err)
	}

	ctx := context.Background()
	key := "test/file.txt"
	content := "test content"

	// First put an object
	data := strings.NewReader(content)
	size := int64(len(content))
	err = store.PutObject(ctx, key, data, size)
	if err != nil {
		t.Fatalf("PutObject() failed: %v", err)
	}

	// Now get it
	reader, err := store.GetObject(ctx, key)
	if err != nil {
		t.Errorf("GetObject() failed: %v", err)
	}
	defer reader.Close()

	// Read the content
	retrievedContent, err := io.ReadAll(reader)
	if err != nil {
		t.Errorf("Failed to read downloaded content: %v", err)
	}

	if string(retrievedContent) != content {
		t.Errorf("Downloaded content mismatch. Expected: '%s', got: '%s'", content, string(retrievedContent))
	}
}

func TestLocalStore_GetObject_NotFound(t *testing.T) {
	store, tempDir := setupTestStore(t)
	defer cleanupTestStore(t, tempDir)

	dsn := "local://" + tempDir
	err := store.Connect(dsn)
	if err != nil {
		t.Fatalf("Connect() failed: %v", err)
	}

	ctx := context.Background()
	key := "nonexistent/file.txt"

	_, err = store.GetObject(ctx, key)
	if err == nil {
		t.Error("GetObject() should have failed for non-existent file")
	}

	if !strings.Contains(err.Error(), "object not found") {
		t.Errorf("Expected 'object not found' error, got: %v", err)
	}
}

func TestLocalStore_DeleteObject(t *testing.T) {
	store, tempDir := setupTestStore(t)
	defer cleanupTestStore(t, tempDir)

	dsn := "local://" + tempDir
	err := store.Connect(dsn)
	if err != nil {
		t.Fatalf("Connect() failed: %v", err)
	}

	ctx := context.Background()
	key := "test/file.txt"
	content := "test content"

	// Put an object first
	data := strings.NewReader(content)
	size := int64(len(content))
	err = store.PutObject(ctx, key, data, size)
	if err != nil {
		t.Fatalf("PutObject() failed: %v", err)
	}

	// Delete the object
	err = store.DeleteObject(ctx, key)
	if err != nil {
		t.Errorf("DeleteObject() failed: %v", err)
	}

	// Check if file was deleted
	filePath := filepath.Join(tempDir, "test", "file.txt")
	if _, err := os.Stat(filePath); !os.IsNotExist(err) {
		t.Error("DeleteObject() did not remove file")
	}
}

func TestLocalStore_DeleteObject_NotFound(t *testing.T) {
	store, tempDir := setupTestStore(t)
	defer cleanupTestStore(t, tempDir)

	dsn := "local://" + tempDir
	err := store.Connect(dsn)
	if err != nil {
		t.Fatalf("Connect() failed: %v", err)
	}

	ctx := context.Background()
	key := "nonexistent/file.txt"

	err = store.DeleteObject(ctx, key)
	if err == nil {
		t.Error("DeleteObject() should have failed for non-existent file")
	}

	if !strings.Contains(err.Error(), "object not found") {
		t.Errorf("Expected 'object not found' error, got: %v", err)
	}
}

func TestLocalStore_SanitizeKey(t *testing.T) {
	store, tempDir := setupTestStore(t)
	defer cleanupTestStore(t, tempDir)

	tests := []struct {
		input    string
		expected string
	}{
		{"normal/path.txt", "normal/path.txt"},
		{"../dangerous.txt", "dangerous.txt"},
		{"path/../file.txt", "file.txt"},
		{"/absolute/path.txt", "absolute/path.txt"},
		{"path\\with\\backslashes.txt", "path/with/backslashes.txt"},
		{"path/./current/./file.txt", "path/current/file.txt"},
		{"path//double//slashes.txt", "path/double/slashes.txt"},
		{"path/with\x00null.txt", "path/withnull.txt"},
		{"./relative/../path.txt", "path.txt"},
		{"", ""},
	}

	for _, tt := range tests {
		t.Run("sanitize_"+tt.input, func(t *testing.T) {
			result := store.sanitizeKey(tt.input)
			if result != tt.expected {
				t.Errorf("sanitizeKey(%q) = %q, expected %q", tt.input, result, tt.expected)
			}
		})
	}
}

func TestLocalStore_Close(t *testing.T) {
	store, tempDir := setupTestStore(t)
	defer cleanupTestStore(t, tempDir)

	// Close should not return an error for local store
	err := store.Close()
	if err != nil {
		t.Errorf("Close() failed: %v", err)
	}
}

func TestLocalStore_PutObject_NestedPath(t *testing.T) {
	store, tempDir := setupTestStore(t)
	defer cleanupTestStore(t, tempDir)

	dsn := "local://" + tempDir
	err := store.Connect(dsn)
	if err != nil {
		t.Fatalf("Connect() failed: %v", err)
	}

	ctx := context.Background()
	key := "deeply/nested/path/file.txt"
	content := "nested content"
	data := strings.NewReader(content)
	size := int64(len(content))

	err = store.PutObject(ctx, key, data, size)
	if err != nil {
		t.Errorf("PutObject() failed for nested path: %v", err)
	}

	// Check if nested directory structure was created
	filePath := filepath.Join(tempDir, "deeply", "nested", "path", "file.txt")
	if _, err := os.Stat(filePath); os.IsNotExist(err) {
		t.Error("PutObject() did not create nested directory structure")
	}
}
