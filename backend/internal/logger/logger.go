package logger

import (
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/rs/zerolog"
)

// ServiceLogger wraps zerolog with service-specific context
type ServiceLogger struct {
	logger zerolog.Logger
}

// Config holds logger configuration
type Config struct {
	Level       string `json:"level" env:"LOG_LEVEL" envDefault:"info"`
	Environment string `json:"environment" env:"ENVIRONMENT" envDefault:"development"`
	ServiceName string `json:"service_name" env:"SERVICE_NAME" envDefault:"unknown"`
}

// New creates a new service logger with the given configuration
func New(config Config) *ServiceLogger {
	// Set global log level
	level, err := zerolog.ParseLevel(config.Level)
	if err != nil {
		level = zerolog.InfoLevel
	}
	zerolog.SetGlobalLevel(level)

	// Configure output format based on environment
	var logger zerolog.Logger
	if config.Environment == "development" || config.Environment == "dev" {
		// Pretty console output for development with ANSI colors
		colorForLevel := func(level string) string {
			switch strings.ToLower(level) {
			case "debug":
				return "\u001b[36m" // cyan
			case "info":
				return "\u001b[32m" // green
			case "warn", "warning":
				return "\u001b[33m" // yellow
			case "error":
				return "\u001b[31m" // red
			case "fatal", "panic":
				return "\u001b[35m" // magenta
			default:
				return "\u001b[0m" // reset
			}
		}

		reset := "\u001b[0m"

		output := zerolog.ConsoleWriter{
			Out:        os.Stdout,
			TimeFormat: time.RFC3339,
			FormatLevel: func(i interface{}) string {
				lvl := fmt.Sprintf("%v", i)
				color := colorForLevel(lvl)
				return fmt.Sprintf("%s| %-6s|%s", color, strings.ToUpper(lvl), reset)
			},
			FormatMessage: func(i interface{}) string {
				return fmt.Sprintf("%-50s", i)
			},
			FormatFieldName: func(i interface{}) string {
				return fmt.Sprintf("%s:%s", i, "")
			},
			FormatFieldValue: func(i interface{}) string {
				return fmt.Sprintf("%s", i)
			},
		}

		logger = zerolog.New(output).With().Timestamp().Logger()
	} else {
		// JSON output for production
		logger = zerolog.New(os.Stdout).With().Timestamp().Logger()
	}

	// Add service context
	logger = logger.With().
		Str("service", config.ServiceName).
		Logger()

	return &ServiceLogger{
		logger: logger,
	}
}

// WithContext adds additional context to the logger
func (s *ServiceLogger) WithContext(key, value string) *ServiceLogger {
	return &ServiceLogger{
		logger: s.logger.With().Str(key, value).Logger(),
	}
}

// WithFields adds multiple fields to the logger
func (s *ServiceLogger) WithFields(fields map[string]interface{}) *ServiceLogger {
	event := s.logger.With()
	for k, v := range fields {
		event = event.Interface(k, v)
	}
	return &ServiceLogger{
		logger: event.Logger(),
	}
}

// Debug logs a debug message
func (s *ServiceLogger) Debug(msg string, fields ...map[string]interface{}) {
	event := s.logger.Debug()
	s.addFields(event, fields...)
	event.Msg(msg)
}

// Info logs an info message
func (s *ServiceLogger) Info(msg string, fields ...map[string]interface{}) {
	event := s.logger.Info()
	s.addFields(event, fields...)
	event.Msg(msg)
}

// Warn logs a warning message
func (s *ServiceLogger) Warn(msg string, fields ...map[string]interface{}) {
	event := s.logger.Warn()
	s.addFields(event, fields...)
	event.Msg(msg)
}

// Error logs an error message
func (s *ServiceLogger) Error(msg string, err error, fields ...map[string]interface{}) {
	event := s.logger.Error()
	if err != nil {
		event = event.Err(err)
	}
	s.addFields(event, fields...)
	event.Msg(msg)
}

// Fatal logs a fatal message and exits
func (s *ServiceLogger) Fatal(msg string, err error, fields ...map[string]interface{}) {
	event := s.logger.Fatal()
	if err != nil {
		event = event.Err(err)
	}
	s.addFields(event, fields...)
	event.Msg(msg)
}

// Panic logs a panic message and panics
func (s *ServiceLogger) Panic(msg string, err error, fields ...map[string]interface{}) {
	event := s.logger.Panic()
	if err != nil {
		event = event.Err(err)
	}
	s.addFields(event, fields...)
	event.Msg(msg)
}

// addFields adds multiple field maps to an event
func (s *ServiceLogger) addFields(event *zerolog.Event, fieldMaps ...map[string]interface{}) {
	for _, fields := range fieldMaps {
		for k, v := range fields {
			event = event.Interface(k, v)
		}
	}
}

// GetZerolog returns the underlying zerolog logger for advanced usage
func (s *ServiceLogger) GetZerolog() zerolog.Logger {
	return s.logger
}
