package main

import (
	"os"
	"testing"
)

func TestGetEnvOrDefault(t *testing.T) {
	tests := []struct {
		name         string
		key          string
		defaultValue string
		envValue     string
		expected     string
	}{
		{
			name:         "Environment variable exists",
			key:          "TEST_ENV_VAR",
			defaultValue: "default",
			envValue:     "env_value",
			expected:     "env_value",
		},
		{
			name:         "Environment variable doesn't exist",
			key:          "NON_EXISTENT_VAR",
			defaultValue: "default",
			envValue:     "",
			expected:     "default",
		},
		{
			name:         "Empty environment variable",
			key:          "EMPTY_VAR",
			defaultValue: "default",
			envValue:     "",
			expected:     "default",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Clean up environment
			os.Unsetenv(tt.key)
			
			// Set environment variable if provided
			if tt.envValue != "" {
				os.Setenv(tt.key, tt.envValue)
				defer os.Unsetenv(tt.key)
			}
			
			result := getEnvOrDefault(tt.key, tt.defaultValue)
			if result != tt.expected {
				t.Errorf("Expected %s, got %s", tt.expected, result)
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
		expected     int
	}{
		{
			name:         "Valid integer environment variable",
			key:          "TEST_INT_VAR",
			defaultValue: 123,
			envValue:     "456",
			expected:     456,
		},
		{
			name:         "Invalid integer environment variable",
			key:          "TEST_INVALID_INT",
			defaultValue: 123,
			envValue:     "not_a_number",
			expected:     123,
		},
		{
			name:         "Environment variable doesn't exist",
			key:          "NON_EXISTENT_INT",
			defaultValue: 123,
			envValue:     "",
			expected:     123,
		},
		{
			name:         "Zero value",
			key:          "TEST_ZERO_VAR",
			defaultValue: 123,
			envValue:     "0",
			expected:     0,
		},
		{
			name:         "Negative value",
			key:          "TEST_NEG_VAR",
			defaultValue: 123,
			envValue:     "-42",
			expected:     -42,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Clean up environment
			os.Unsetenv(tt.key)
			
			// Set environment variable if provided
			if tt.envValue != "" {
				os.Setenv(tt.key, tt.envValue)
				defer os.Unsetenv(tt.key)
			}
			
			result := getEnvIntOrDefault(tt.key, tt.defaultValue)
			if result != tt.expected {
				t.Errorf("Expected %d, got %d", tt.expected, result)
			}
		})
	}
}

func TestGetEnvFloatOrDefault(t *testing.T) {
	tests := []struct {
		name         string
		key          string
		defaultValue float32
		envValue     string
		expected     float32
	}{
		{
			name:         "Valid float environment variable",
			key:          "TEST_FLOAT_VAR",
			defaultValue: 1.23,
			envValue:     "4.56",
			expected:     4.56,
		},
		{
			name:         "Invalid float environment variable",
			key:          "TEST_INVALID_FLOAT",
			defaultValue: 1.23,
			envValue:     "not_a_float",
			expected:     1.23,
		},
		{
			name:         "Environment variable doesn't exist",
			key:          "NON_EXISTENT_FLOAT",
			defaultValue: 1.23,
			envValue:     "",
			expected:     1.23,
		},
		{
			name:         "Integer value",
			key:          "TEST_INT_AS_FLOAT",
			defaultValue: 1.23,
			envValue:     "42",
			expected:     42.0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Clean up environment
			os.Unsetenv(tt.key)
			
			// Set environment variable if provided
			if tt.envValue != "" {
				os.Setenv(tt.key, tt.envValue)
				defer os.Unsetenv(tt.key)
			}
			
			result := getEnvFloatOrDefault(tt.key, tt.defaultValue)
			if result != tt.expected {
				t.Errorf("Expected %f, got %f", tt.expected, result)
			}
		})
	}
}

func TestGetRequiredEnv_Success(t *testing.T) {
	key := "REQUIRED_TEST_VAR"
	value := "required_value"
	
	os.Setenv(key, value)
	defer os.Unsetenv(key)
	
	result := getRequiredEnv(key)
	if result != value {
		t.Errorf("Expected %s, got %s", value, result)
	}
}

func TestGetRequiredEnv_Panic(t *testing.T) {
	key := "NON_EXISTENT_REQUIRED_VAR"
	
	// Ensure the variable doesn't exist
	os.Unsetenv(key)
	
	defer func() {
		if r := recover(); r == nil {
			t.Error("Expected panic for missing required environment variable")
		}
	}()
	
	getRequiredEnv(key)
}

func TestLoadConfig_WithDefaults(t *testing.T) {
	// Set only required environment variables
	os.Setenv("POSTGRES_DSN", "postgres://test")
	os.Setenv("JWT_SECRET", "test-secret")
	defer func() {
		os.Unsetenv("POSTGRES_DSN")
		os.Unsetenv("JWT_SECRET")
	}()
	
	// Clear other environment variables to test defaults
	envVars := []string{
		"PORT", "LOG_LEVEL", "ENVIRONMENT", "BASE_URL", 
		"AVATAR_PATH", "TOKEN_DURATION_MINUTES", "COOKIE_DURATION_HOURS",
	}
	
	for _, envVar := range envVars {
		os.Unsetenv(envVar)
	}
	
	cfg := LoadConfig()
	
	// Test required fields
	if cfg.Dsn != "postgres://test" {
		t.Errorf("Expected DSN 'postgres://test', got '%s'", cfg.Dsn)
	}
	
	if cfg.JWTSecret != "test-secret" {
		t.Errorf("Expected JWT secret 'test-secret', got '%s'", cfg.JWTSecret)
	}
	
	// Test defaults
	if cfg.Port != 8080 {
		t.Errorf("Expected default port 8080, got %d", cfg.Port)
	}
	
	if cfg.LogLevel != "info" {
		t.Errorf("Expected default log level 'info', got '%s'", cfg.LogLevel)
	}
	
	if cfg.Environment != "production" {
		t.Errorf("Expected default environment 'production', got '%s'", cfg.Environment)
	}
	
	if cfg.BaseURL != "http://localhost:8080" {
		t.Errorf("Expected default base URL 'http://localhost:8080', got '%s'", cfg.BaseURL)
	}
	
	if cfg.AvatarPath != "/tmp/avatars" {
		t.Errorf("Expected default avatar path '/tmp/avatars', got '%s'", cfg.AvatarPath)
	}
	
	if cfg.TokenDuration != 5 {
		t.Errorf("Expected default token duration 5, got %d", cfg.TokenDuration)
	}
	
	if cfg.CookieDuration != 24 {
		t.Errorf("Expected default cookie duration 24, got %d", cfg.CookieDuration)
	}
}

func TestLoadConfig_WithCustomValues(t *testing.T) {
	// Set all environment variables to custom values
	envVars := map[string]string{
		"POSTGRES_DSN":             "postgres://custom",
		"JWT_SECRET":               "custom-secret",
		"PORT":                     "9000",
		"LOG_LEVEL":                "debug",
		"ENVIRONMENT":              "development",
		"BASE_URL":                 "https://example.com",
		"AVATAR_PATH":              "/custom/avatars",
		"TOKEN_DURATION_MINUTES":   "10",
		"COOKIE_DURATION_HOURS":    "48",
	}
	
	for key, value := range envVars {
		os.Setenv(key, value)
	}
	
	defer func() {
		for key := range envVars {
			os.Unsetenv(key)
		}
	}()
	
	cfg := LoadConfig()
	
	// Test all custom values
	if cfg.Dsn != "postgres://custom" {
		t.Errorf("Expected DSN 'postgres://custom', got '%s'", cfg.Dsn)
	}
	
	if cfg.JWTSecret != "custom-secret" {
		t.Errorf("Expected JWT secret 'custom-secret', got '%s'", cfg.JWTSecret)
	}
	
	if cfg.Port != 9000 {
		t.Errorf("Expected port 9000, got %d", cfg.Port)
	}
	
	if cfg.LogLevel != "debug" {
		t.Errorf("Expected log level 'debug', got '%s'", cfg.LogLevel)
	}
	
	if cfg.Environment != "development" {
		t.Errorf("Expected environment 'development', got '%s'", cfg.Environment)
	}
	
	if cfg.BaseURL != "https://example.com" {
		t.Errorf("Expected base URL 'https://example.com', got '%s'", cfg.BaseURL)
	}
	
	if cfg.AvatarPath != "/custom/avatars" {
		t.Errorf("Expected avatar path '/custom/avatars', got '%s'", cfg.AvatarPath)
	}
	
	if cfg.TokenDuration != 10 {
		t.Errorf("Expected token duration 10, got %d", cfg.TokenDuration)
	}
	
	if cfg.CookieDuration != 48 {
		t.Errorf("Expected cookie duration 48, got %d", cfg.CookieDuration)
	}
}
