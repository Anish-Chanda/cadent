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
	JWTSecret     string
	BaseURL       string
	AvatarPath    string
	TokenDuration int // in minutes
	CookieDuration int // in hours
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
		AvatarPath:     getEnvOrDefault("AVATAR_PATH", "/tmp/avatars"),
		TokenDuration:  getEnvIntOrDefault("TOKEN_DURATION_MINUTES", 5),
		CookieDuration: getEnvIntOrDefault("COOKIE_DURATION_HOURS", 24),
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

func getEnvFloatOrDefault(key string, defaultValue float32) float32 {
	if value := os.Getenv(key); value != "" {
		if floatValue, err := strconv.ParseFloat(value, 32); err == nil {
			return float32(floatValue)
		}
	}
	return defaultValue
}

func getEnvUint32OrDefault(key string, defaultValue uint32) uint32 {
	if value := os.Getenv(key); value != "" {
		if intValue, err := strconv.ParseUint(value, 10, 32); err == nil {
			return uint32(intValue)
		}
	}
	return defaultValue
}

func getEnvUintOrPanic(key string) uint64 {
	value := getRequiredEnv(key)
	if uintValue, err := strconv.ParseUint(value, 10, 32); err == nil {
		return uintValue
	}
	panic("Environment variable " + key + " must be a valid unsigned integer")
}
