package main

import (
	"context"
	"fmt"
	"net/http"
	"time"

	"github.com/anish-chanda/cadence/backend/internal/auth"
	"github.com/anish-chanda/cadence/backend/internal/db"
	"github.com/anish-chanda/cadence/backend/internal/db/postgres"
	"github.com/anish-chanda/cadence/backend/internal/handlers"
	"github.com/anish-chanda/cadence/backend/internal/logger"
	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	authpkg "github.com/go-pkgz/auth/v2"
	"github.com/go-pkgz/auth/v2/avatar"
	"github.com/go-pkgz/auth/v2/provider"
	"github.com/go-pkgz/auth/v2/token"
)

func main() {
	// Load and validate config
	cfg := LoadConfig()

	logConfig := logger.Config{
		Level:       cfg.LogLevel,
		Environment: cfg.Environment,
		ServiceName: "api",
	}

	log := logger.New(logConfig)

	log.Info("Initializing database")
	var database db.Database = postgres.NewPostgresDB(*log)
	if err := database.Connect(cfg.Dsn); err != nil {
		log.Error("Failed to connect to database", err)
		return
	}

	defer gracefulShutdown(database, *log)

	// Run DB migrations
	log.Info("Running database migrations")
	if err := database.Migrate(); err != nil {
		log.Error("Failed to run migrations", err)
		return
	}

	// Setup auth options
	authOptions := authpkg.Opts{
		SecretReader: token.SecretFunc(func(id string) (string, error) { // secret key for JWT
			return cfg.JWTSecret, nil
		}),
		TokenDuration:  time.Duration(cfg.TokenDuration) * time.Minute, // token expires in X minutes
		CookieDuration: time.Duration(cfg.CookieDuration) * time.Hour,  // cookie expires in X hours
		Issuer:         "cadence",
		URL:            cfg.BaseURL,
		DisableXSRF:    true,
		ClaimsUpd: token.ClaimsUpdFunc(func(cl token.Claims) token.Claims {
			if cl.User.Name == "" {
				return cl
			}
			u, err := database.GetUserByEmail(context.TODO(), cl.User.Name)
			if err != nil || u == nil {
				return cl
			}
			cl.User.SetStrAttr("uid", u.ID)
			return cl
		}),
		AvatarStore: avatar.NewLocalFS(cfg.AvatarPath),
	}

	// Create auth service with providers
	authService := authpkg.NewService(authOptions)
	authService.AddDirectProvider("local", provider.CredCheckerFunc(func(user, password string) (ok bool, err error) {
		return auth.HandleLogin(database, user, password)
	}))

	// Create router
	router := chi.NewRouter()

	// Add middlewares
	router.Use(middleware.Logger)
	router.Use(middleware.Recoverer)
	// router.Use(middleware.RealIP)

	// Mount auth routes
	authHandler, avatarHandler := authService.Handlers()
	router.Mount("/auth", authHandler)
	router.Mount("/avatar", avatarHandler)

	// Mount V1 API routes
	router.Route("/v1", func(r chi.Router) {
		r.HandleFunc("/placeholder", handlers.Placeholder(database))
		// TODO: Add more API routes here
	})

	// Start listening
	log.Info(fmt.Sprintf("Starting server on port %d", cfg.Port))
	if err := http.ListenAndServe(fmt.Sprintf(":%d", cfg.Port), router); err != nil {
		log.Error("Server failed to start", err)
	}
}

func gracefulShutdown(database db.Database, log logger.ServiceLogger) {
	log.Info("Shutting down gracefully...")
	if err := database.Close(); err != nil {
		log.Error("Error closing database connection", err)
	} else {
		log.Info("Database connection closed successfully")
	}
}
