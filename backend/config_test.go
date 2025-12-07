package main

import (
	"os"
	"testing"
)

func TestLoadConfig(t *testing.T) {
	tests := []struct {
		name     string
		envVars  map[string]string
		expected Config
		wantErr  bool
	}{
		{
			name: "all required env vars set",
			envVars: map[string]string{
				"POSTGRES_DSN": "postgres://user:pass@localhost/db",
				"JWT_SECRET":   "secret123",
				"PORT":         "3000",
			},
			expected: Config{
				Dsn:               "postgres://user:pass@localhost/db",
				Port:              3000,
				LogLevel:          "info",
				Environment:       "production",
				JWTSecret:         "secret123",
				BaseURL:           "http://localhost:8080",
				AvatarPath:        "/data/auth/avatars",
				TokenDuration:     5,
				CookieDuration:    24,
				StorageDsn:        "local://./data",
				AvatarStoragePath: "/data/auth/avatars",
				ValhallaURL:       "https://valhalla.anishchanda.dev",
			},
			wantErr: false,
		},
		{
			name: "all env vars set with custom values",
			envVars: map[string]string{
				"POSTGRES_DSN":           "postgres://custom:pass@localhost/custom",
				"JWT_SECRET":             "customsecret",
				"PORT":                   "4000",
				"LOG_LEVEL":              "debug",
				"ENVIRONMENT":            "development",
				"BASE_URL":               "http://localhost:4000",
				"AVATAR_PATH":            "/custom/avatars",
				"TOKEN_DURATION_MINUTES": "10",
				"COOKIE_DURATION_HOURS":  "48",
				"STORAGE_DSN":            "s3://bucket",
				"AVATAR_STORAGE_PATH":    "/custom/storage",
				"VALHALLA_URL":           "https://custom.valhalla.com",
			},
			expected: Config{
				Dsn:               "postgres://custom:pass@localhost/custom",
				Port:              4000,
				LogLevel:          "debug",
				Environment:       "development",
				JWTSecret:         "customsecret",
				BaseURL:           "http://localhost:4000",
				AvatarPath:        "/custom/avatars",
				TokenDuration:     10,
				CookieDuration:    48,
				StorageDsn:        "s3://bucket",
				AvatarStoragePath: "/custom/storage",
				ValhallaURL:       "https://custom.valhalla.com",
			},
			wantErr: false,
		},
		{
			name: "minimal required env vars with defaults",
			envVars: map[string]string{
				"POSTGRES_DSN": "postgres://min:pass@localhost/min",
				"JWT_SECRET":   "minsecret",
			},
			expected: Config{
				Dsn:               "postgres://min:pass@localhost/min",
				Port:              8080,
				LogLevel:          "info",
				Environment:       "production",
				JWTSecret:         "minsecret",
				BaseURL:           "http://localhost:8080",
				AvatarPath:        "/data/auth/avatars",
				TokenDuration:     5,
				CookieDuration:    24,
				StorageDsn:        "local://./data",
				AvatarStoragePath: "/data/auth/avatars",
				ValhallaURL:       "https://valhalla.anishchanda.dev",
			},
			wantErr: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Clear environment
			clearEnv()

			// Set test environment variables
			for key, value := range tt.envVars {
				os.Setenv(key, value)
			}

			// Cleanup after test
			defer func() {
				for key := range tt.envVars {
					os.Unsetenv(key)
				}
			}()

			// Test LoadConfig
			config := LoadConfig()

			// Verify all fields
			if config.Dsn != tt.expected.Dsn {
				t.Errorf("Dsn = %v, want %v", config.Dsn, tt.expected.Dsn)
			}
			if config.Port != tt.expected.Port {
				t.Errorf("Port = %v, want %v", config.Port, tt.expected.Port)
			}
			if config.LogLevel != tt.expected.LogLevel {
				t.Errorf("LogLevel = %v, want %v", config.LogLevel, tt.expected.LogLevel)
			}
			if config.Environment != tt.expected.Environment {
				t.Errorf("Environment = %v, want %v", config.Environment, tt.expected.Environment)
			}
			if config.JWTSecret != tt.expected.JWTSecret {
				t.Errorf("JWTSecret = %v, want %v", config.JWTSecret, tt.expected.JWTSecret)
			}
			if config.BaseURL != tt.expected.BaseURL {
				t.Errorf("BaseURL = %v, want %v", config.BaseURL, tt.expected.BaseURL)
			}
			if config.AvatarPath != tt.expected.AvatarPath {
				t.Errorf("AvatarPath = %v, want %v", config.AvatarPath, tt.expected.AvatarPath)
			}
			if config.TokenDuration != tt.expected.TokenDuration {
				t.Errorf("TokenDuration = %v, want %v", config.TokenDuration, tt.expected.TokenDuration)
			}
			if config.CookieDuration != tt.expected.CookieDuration {
				t.Errorf("CookieDuration = %v, want %v", config.CookieDuration, tt.expected.CookieDuration)
			}
			if config.StorageDsn != tt.expected.StorageDsn {
				t.Errorf("StorageDsn = %v, want %v", config.StorageDsn, tt.expected.StorageDsn)
			}
			if config.AvatarStoragePath != tt.expected.AvatarStoragePath {
				t.Errorf("AvatarStoragePath = %v, want %v", config.AvatarStoragePath, tt.expected.AvatarStoragePath)
			}
			if config.ValhallaURL != tt.expected.ValhallaURL {
				t.Errorf("ValhallaURL = %v, want %v", config.ValhallaURL, tt.expected.ValhallaURL)
			}
		})
	}
}

func TestLoadConfigPanicOnMissingRequired(t *testing.T) {
	tests := []struct {
		name        string
		envVars     map[string]string
		missingVar  string
		shouldPanic bool
	}{
		{
			name: "missing POSTGRES_DSN",
			envVars: map[string]string{
				"JWT_SECRET": "secret",
			},
			missingVar:  "POSTGRES_DSN",
			shouldPanic: true,
		},
		{
			name: "missing JWT_SECRET",
			envVars: map[string]string{
				"POSTGRES_DSN": "postgres://localhost/db",
			},
			missingVar:  "JWT_SECRET",
			shouldPanic: true,
		},
		{
			name: "both required vars missing",
			envVars: map[string]string{
				"PORT": "8080",
			},
			missingVar:  "POSTGRES_DSN", // Will panic on the first missing one
			shouldPanic: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Clear environment
			clearEnv()

			// Set test environment variables
			for key, value := range tt.envVars {
				os.Setenv(key, value)
			}

			// Cleanup after test
			defer func() {
				for key := range tt.envVars {
					os.Unsetenv(key)
				}
			}()

			defer func() {
				if r := recover(); r != nil {
					if !tt.shouldPanic {
						t.Errorf("LoadConfig() panicked unexpectedly: %v", r)
					}
					// Check if panic message contains the expected missing variable
					if msg, ok := r.(string); ok {
						if !contains(msg, tt.missingVar) {
							t.Errorf("Panic message '%s' does not contain expected variable '%s'", msg, tt.missingVar)
						}
					}
				} else if tt.shouldPanic {
					t.Error("LoadConfig() should have panicked but did not")
				}
			}()

			LoadConfig()
		})
	}
}

func TestGetRequiredEnv(t *testing.T) {
	tests := []struct {
		name        string
		key         string
		value       string
		shouldPanic bool
	}{
		{
			name:        "env var exists",
			key:         "TEST_VAR",
			value:       "test_value",
			shouldPanic: false,
		},
		{
			name:        "env var empty",
			key:         "EMPTY_VAR",
			value:       "",
			shouldPanic: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.value != "" {
				os.Setenv(tt.key, tt.value)
				defer os.Unsetenv(tt.key)
			} else {
				os.Unsetenv(tt.key)
			}

			defer func() {
				if r := recover(); r != nil {
					if !tt.shouldPanic {
						t.Errorf("getRequiredEnv() panicked unexpectedly: %v", r)
					}
				} else if tt.shouldPanic {
					t.Error("getRequiredEnv() should have panicked but did not")
				}
			}()

			result := getRequiredEnv(tt.key)
			if !tt.shouldPanic && result != tt.value {
				t.Errorf("getRequiredEnv() = %v, want %v", result, tt.value)
			}
		})
	}
}

func TestGetEnvOrDefault(t *testing.T) {
	tests := []struct {
		name         string
		key          string
		defaultValue string
		envValue     string
		setEnv       bool
		expected     string
	}{
		{
			name:         "env var exists",
			key:          "TEST_VAR",
			defaultValue: "default",
			envValue:     "actual",
			setEnv:       true,
			expected:     "actual",
		},
		{
			name:         "env var does not exist",
			key:          "NONEXISTENT_VAR",
			defaultValue: "default",
			setEnv:       false,
			expected:     "default",
		},
		{
			name:         "env var empty string",
			key:          "EMPTY_VAR",
			defaultValue: "default",
			envValue:     "",
			setEnv:       true,
			expected:     "default",
		},
		{
			name:         "env var with whitespace",
			key:          "WHITESPACE_VAR",
			defaultValue: "default",
			envValue:     " value ",
			setEnv:       true,
			expected:     " value ",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.setEnv {
				os.Setenv(tt.key, tt.envValue)
				defer os.Unsetenv(tt.key)
			} else {
				os.Unsetenv(tt.key)
			}

			result := getEnvOrDefault(tt.key, tt.defaultValue)
			if result != tt.expected {
				t.Errorf("getEnvOrDefault() = %v, want %v", result, tt.expected)
			}
		})
	}
}

func TestGetEnvIntOrDefault(t *testing.T) {
	tests := []struct {
		name         string
		key          string
		defaultValue int
		envValue     string
		setEnv       bool
		expected     int
	}{
		{
			name:         "valid integer",
			key:          "INT_VAR",
			defaultValue: 100,
			envValue:     "42",
			setEnv:       true,
			expected:     42,
		},
		{
			name:         "env var does not exist",
			key:          "NONEXISTENT_INT",
			defaultValue: 100,
			setEnv:       false,
			expected:     100,
		},
		{
			name:         "invalid integer",
			key:          "INVALID_INT",
			defaultValue: 100,
			envValue:     "not_a_number",
			setEnv:       true,
			expected:     100,
		},
		{
			name:         "empty string",
			key:          "EMPTY_INT",
			defaultValue: 100,
			envValue:     "",
			setEnv:       true,
			expected:     100,
		},
		{
			name:         "negative integer",
			key:          "NEG_INT",
			defaultValue: 100,
			envValue:     "-50",
			setEnv:       true,
			expected:     -50,
		},
		{
			name:         "zero",
			key:          "ZERO_INT",
			defaultValue: 100,
			envValue:     "0",
			setEnv:       true,
			expected:     0,
		},
		{
			name:         "float should fail",
			key:          "FLOAT_INT",
			defaultValue: 100,
			envValue:     "42.5",
			setEnv:       true,
			expected:     100,
		},
		{
			name:         "integer with whitespace should fail",
			key:          "SPACE_INT",
			defaultValue: 100,
			envValue:     " 42 ",
			setEnv:       true,
			expected:     100,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.setEnv {
				os.Setenv(tt.key, tt.envValue)
				defer os.Unsetenv(tt.key)
			} else {
				os.Unsetenv(tt.key)
			}

			result := getEnvIntOrDefault(tt.key, tt.defaultValue)
			if result != tt.expected {
				t.Errorf("getEnvIntOrDefault() = %v, want %v", result, tt.expected)
			}
		})
	}
}

// Helper functions for tests
func clearEnv() {
	keys := []string{
		"POSTGRES_DSN", "JWT_SECRET", "PORT", "LOG_LEVEL", "ENVIRONMENT",
		"BASE_URL", "AVATAR_PATH", "TOKEN_DURATION_MINUTES", "COOKIE_DURATION_HOURS",
		"STORAGE_DSN", "AVATAR_STORAGE_PATH", "VALHALLA_URL",
	}
	for _, key := range keys {
		os.Unsetenv(key)
	}
}

func contains(str, substr string) bool {
	return len(str) >= len(substr) && str[:len(substr)] == substr ||
		(len(str) > len(substr) && indexOf(str, substr) != -1)
}

func indexOf(str, substr string) int {
	for i := 0; i <= len(str)-len(substr); i++ {
		if str[i:i+len(substr)] == substr {
			return i
		}
	}
	return -1
}
