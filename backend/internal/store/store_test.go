package store

import (
	"testing"
)

func TestParseStorageDSN(t *testing.T) {
	tests := []struct {
		name      string
		dsn       string
		expected  *StorageConfig
		expectErr bool
	}{
		{
			name: "valid local DSN with absolute path",
			dsn:  "local:///var/storage",
			expected: &StorageConfig{
				Type: "local",
				Path: "/var/storage",
			},
			expectErr: false,
		},
		{
			name: "valid local DSN with relative path",
			dsn:  "local://./storage",
			expected: &StorageConfig{
				Type: "local",
				Path: "storage",
			},
			expectErr: false,
		},
		{
			name: "valid s3 DSN with AWS format",
			dsn:  "s3://my-bucket",
			expected: &StorageConfig{
				Type: "s3",
				Path: "my-bucket",
				Host: "",
			},
			expectErr: false,
		},
		{
			name: "valid s3 DSN with custom endpoint",
			dsn:  "s3://minio.example.com/my-bucket",
			expected: &StorageConfig{
				Type: "s3",
				Path: "my-bucket",
				Host: "minio.example.com",
			},
			expectErr: false,
		},
		{
			name: "valid s3 DSN with port",
			dsn:  "s3://localhost:9000/test-bucket",
			expected: &StorageConfig{
				Type: "s3",
				Path: "test-bucket",
				Host: "localhost:9000",
			},
			expectErr: false,
		},
		{
			name:      "empty DSN",
			dsn:       "",
			expected:  nil,
			expectErr: true,
		},
		{
			name:      "invalid DSN format",
			dsn:       "not-a-url",
			expected:  nil,
			expectErr: true,
		},
		{
			name:      "unsupported scheme",
			dsn:       "ftp://example.com/path",
			expected:  nil,
			expectErr: true,
		},
		{
			name:      "local DSN without path",
			dsn:       "local://",
			expected:  nil,
			expectErr: true,
		},
		{
			name:      "s3 DSN without bucket",
			dsn:       "s3://",
			expected:  nil,
			expectErr: true,
		},
		{
			name:      "s3 DSN with endpoint but no bucket",
			dsn:       "s3://minio.example.com/",
			expected:  nil,
			expectErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			config, err := ParseStorageDSN(tt.dsn)

			if tt.expectErr {
				if err == nil {
					t.Errorf("ParseStorageDSN() expected error, got nil")
				}
				return
			}

			if err != nil {
				t.Errorf("ParseStorageDSN() unexpected error: %v", err)
				return
			}

			if config.Type != tt.expected.Type {
				t.Errorf("ParseStorageDSN() Type = %v, expected %v", config.Type, tt.expected.Type)
			}

			if config.Path != tt.expected.Path {
				t.Errorf("ParseStorageDSN() Path = %v, expected %v", config.Path, tt.expected.Path)
			}

			if config.Host != tt.expected.Host {
				t.Errorf("ParseStorageDSN() Host = %v, expected %v", config.Host, tt.expected.Host)
			}
		})
	}
}

func TestParseStorageDSN_EdgeCases(t *testing.T) {
	// Test path cleaning for local storage
	config, err := ParseStorageDSN("local://./path/../storage/./files")
	if err != nil {
		t.Errorf("ParseStorageDSN() unexpected error: %v", err)
	}

	expectedPath := "storage/files"
	if config.Path != expectedPath {
		t.Errorf("ParseStorageDSN() path cleaning failed: got %v, expected %v", config.Path, expectedPath)
	}

	// Test bucket name extraction with complex path
	config, err = ParseStorageDSN("s3://s3.amazonaws.com/my-bucket-name")
	if err != nil {
		t.Errorf("ParseStorageDSN() unexpected error: %v", err)
	}

	if config.Host != "s3.amazonaws.com" {
		t.Errorf("ParseStorageDSN() Host = %v, expected s3.amazonaws.com", config.Host)
	}

	if config.Path != "my-bucket-name" {
		t.Errorf("ParseStorageDSN() Path = %v, expected my-bucket-name", config.Path)
	}
}
