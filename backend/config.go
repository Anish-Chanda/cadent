package main

import (
	"fmt"
	"os"
	"strconv"
)

// Config holds all application configuration
type Config struct {
	// Database configuration
	Dsn string

	// Server configuration
	Port uint

	// Logging configuration
	LogLevel    string
	Environment string

	// Authentication configuration
	JWTSecret      string
	BaseURL        string
	AvatarPath     string
	TokenDuration  int // in minutes
	CookieDuration int // in hours

	// Storage configuration
	StorageDsn   string
	AvatarStoragePath string

	// Valhalla configuration
	ValhallaURL string
}

// LoadConfig loads configuration from environment variables with sensible defaults
func LoadConfig() Config {
	return Config{
		// Database
		Dsn: getRequiredEnv("POSTGRES_DSN"),

		// Server
		Port: uint(getEnvIntOrDefault("PORT", 8080)),

		// Logging
		LogLevel:    getEnvOrDefault("LOG_LEVEL", "info"),
		Environment: getEnvOrDefault("ENVIRONMENT", "production"),

		// Authentication
		JWTSecret:      getRequiredEnv("JWT_SECRET"),
		BaseURL:        getEnvOrDefault("BASE_URL", "http://localhost:8080"),
		AvatarPath:     getEnvOrDefault("AVATAR_PATH", "/data/auth/avatars"),
		TokenDuration:  getEnvIntOrDefault("TOKEN_DURATION_MINUTES", 5),
		CookieDuration: getEnvIntOrDefault("COOKIE_DURATION_HOURS", 24),

		// Storage
		StorageDsn:        getEnvOrDefault("STORAGE_DSN", "local://./data"),
		AvatarStoragePath: getEnvOrDefault("AVATAR_STORAGE_PATH", "/data/auth/avatars"),

		// Valhalla
		ValhallaURL: getEnvOrDefault("VALHALLA_URL", "https://valhalla.anishchanda.dev"),
	}
}

// getRequiredEnv gets an environment variable and panics if it's not set
func getRequiredEnv(key string) string {
	value := os.Getenv(key)
	if value == "" {
		panic(fmt.Sprintf("Required environment variable %s is not set", key))
	}
	return value
}

// Helper functions for environment variable parsing
func getEnvOrDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEnvIntOrDefault(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		if intValue, err := strconv.Atoi(value); err == nil {
			return intValue
		}
	}
	return defaultValue
}
