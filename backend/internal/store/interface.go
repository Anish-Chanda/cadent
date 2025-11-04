package store

import (
	"context"
	"fmt"
	"io"
	"net/url"
	"path/filepath"
	"strings"
)

// ObjectStore interface defines methods for object storage operations
type ObjectStore interface {
	// PutObject uploads an object to the store
	PutObject(ctx context.Context, key string, data io.Reader, size int64) error

	// GetObject downloads an object from the store
	GetObject(ctx context.Context, key string) (io.ReadCloser, error)

	// DeleteObject deletes an object from the store
	DeleteObject(ctx context.Context, key string) error

	// Connect initializes the store connection with DSN
	Connect(dsn string) error

	// Close closes the store connection
	Close() error
}

// StorageConfig represents parsed storage configuration
type StorageConfig struct {
	Type string // "local" or "s3"
	Path string // file path for local, bucket name for s3
	Host string // empty for local, endpoint for s3
}

// ParseStorageDSN parses a storage DSN and returns configuration
// Supported formats:
// - local://path/to/storage
// - s3://bucket-name
// - s3://endpoint/bucket-name
func ParseStorageDSN(dsn string) (*StorageConfig, error) {
	if dsn == "" {
		return nil, fmt.Errorf("storage DSN cannot be empty")
	}

	u, err := url.Parse(dsn)
	if err != nil {
		return nil, fmt.Errorf("invalid storage DSN format: %w", err)
	}

	config := &StorageConfig{
		Type: u.Scheme,
	}

	switch u.Scheme {
	case "local":
		var path string
		if u.Host == "." {
			// Handle relative path: local://./storage -> Host: ".", Path: "/storage"
			path = strings.TrimPrefix(u.Path, "/")
		} else {
			// Handle absolute path: local:///var/storage -> Host: "", Path: "/var/storage"
			path = u.Path
		}

		if path == "" {
			return nil, fmt.Errorf("local storage DSN must specify a path")
		}

		config.Path = filepath.Clean(path)

	case "s3":
		if u.Host == "" {
			return nil, fmt.Errorf("s3 storage DSN must specify bucket name")
		}

		if u.Path == "" {
			// Format: s3://bucket-name (AWS S3) - bucket name is in the host part
			config.Path = u.Host
		} else {
			// Format: s3://endpoint/bucket-name
			config.Host = u.Host
			config.Path = strings.TrimPrefix(u.Path, "/")
		}

		if config.Path == "" {
			return nil, fmt.Errorf("s3 storage DSN must specify bucket name")
		}

	default:
		return nil, fmt.Errorf("unsupported storage type: %s", u.Scheme)
	}

	return config, nil
}
