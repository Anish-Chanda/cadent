package local_store

import (
	"context"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/anish-chanda/cadence/backend/internal/logger"
	"github.com/anish-chanda/cadence/backend/internal/store"
)

type LocalStore struct {
	basePath string
	log      logger.ServiceLogger
}

func NewLocalStore(log logger.ServiceLogger) *LocalStore {
	return &LocalStore{
		log: log,
	}
}

// Connect initializes the local store by parsing DSN and creating the base directory
func (s *LocalStore) Connect(dsn string) error {
	config, err := store.ParseStorageDSN(dsn)
	if err != nil {
		return fmt.Errorf("failed to parse storage DSN: %w", err)
	}

	if config.Type != "local" {
		return fmt.Errorf("invalid storage type for local store: %s", config.Type)
	}

	s.basePath = config.Path
	s.log.Debug(fmt.Sprintf("Initializing local store at: %s", s.basePath))

	if err := os.MkdirAll(s.basePath, 0755); err != nil {
		s.log.Error("Failed to create storage directory", err)
		return fmt.Errorf("failed to create storage directory: %w", err)
	}

	s.log.Info(fmt.Sprintf("Local store initialized at: %s", s.basePath))
	return nil
}

// PutObject uploads an object to the configured store
func (s *LocalStore) PutObject(ctx context.Context, key string, data io.Reader, size int64) error {
	s.log.Debug(fmt.Sprintf("Uploading object with key: %s", key))

	// Sanitize the key to prevent directory traversal
	cleanKey := s.sanitizeKey(key)
	filePath := filepath.Join(s.basePath, cleanKey)

	// Create directory structure if needed
	dir := filepath.Dir(filePath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		s.log.Error(fmt.Sprintf("Failed to create directory for key: %s", key), err)
		return fmt.Errorf("failed to create directory: %w", err)
	}

	// Create and write to file
	file, err := os.Create(filePath)
	if err != nil {
		s.log.Error(fmt.Sprintf("Failed to create file for key: %s", key), err)
		return fmt.Errorf("failed to create file: %w", err)
	}
	defer file.Close()

	_, err = io.Copy(file, data)
	if err != nil {
		s.log.Error(fmt.Sprintf("Failed to write data for key: %s", key), err)
		return fmt.Errorf("failed to write data: %w", err)
	}

	s.log.Info(fmt.Sprintf("Successfully uploaded object with key: %s", key))
	return nil
}

// GetObject downloads an object form the configured store
func (s *LocalStore) GetObject(ctx context.Context, key string) (io.ReadCloser, error) {
	s.log.Debug(fmt.Sprintf("Downloading object with key: %s", key))

	cleanKey := s.sanitizeKey(key)
	filePath := filepath.Join(s.basePath, cleanKey)

	file, err := os.Open(filePath)
	if err != nil {
		if os.IsNotExist(err) {
			s.log.Debug(fmt.Sprintf("Object not found with key: %s", key))
			return nil, fmt.Errorf("object not found: %s", key)
		}
		s.log.Error(fmt.Sprintf("Failed to open file for key: %s", key), err)
		return nil, fmt.Errorf("failed to open file: %w", err)
	}

	s.log.Debug(fmt.Sprintf("Successfully opened object with key: %s", key))
	return file, nil
}

// DeleteObject deletes an object from the configured store
func (s *LocalStore) DeleteObject(ctx context.Context, key string) error {
	s.log.Debug(fmt.Sprintf("Deleting object with key: %s", key))

	cleanKey := s.sanitizeKey(key)
	filePath := filepath.Join(s.basePath, cleanKey)

	err := os.Remove(filePath)
	if err != nil {
		if os.IsNotExist(err) {
			s.log.Debug(fmt.Sprintf("Object not found for deletion with key: %s", key))
			return fmt.Errorf("object not found: %s", key)
		}
		s.log.Error(fmt.Sprintf("Failed to delete file for key: %s", key), err)
		return fmt.Errorf("failed to delete file: %w", err)
	}

	s.log.Info(fmt.Sprintf("Successfully deleted object with key: %s", key))
	return nil
}

// Close is a no-op for local store as there's no connection to close
func (s *LocalStore) Close() error {
	s.log.Debug("Closing local store (no-op)")
	// here we will handle other storage types accordingly
	return nil
}

// sanitizeKey removes dangerous characters and path elements from keys for Linux filesystem
func (s *LocalStore) sanitizeKey(key string) string {
	// Normalize path separators to forward slashes (Linux standard)
	clean := strings.ReplaceAll(key, "\\", "/")

	// Remove leading slashes to prevent absolute paths
	clean = strings.TrimPrefix(clean, "/")

	// Remove any null bytes
	clean = strings.ReplaceAll(clean, "\x00", "")

	// Split path into components and process with stack-based approach
	parts := strings.Split(clean, "/")
	var stack []string

	for _, part := range parts {
		if part == "" || part == "." {
			// Skip empty parts and current directory references
			continue
		} else if part == ".." {
			// Parent directory - pop from stack if possible
			if len(stack) > 0 {
				stack = stack[:len(stack)-1]
			}
		} else {
			// Regular directory/file name - push to stack
			stack = append(stack, part)
		}
	}

	return strings.Join(stack, "/")
}
