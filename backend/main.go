package main

import (
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/anish-chanda/cadence/backend/internal/db"
	"github.com/anish-chanda/cadence/backend/internal/db/postgres"
	"github.com/anish-chanda/cadence/backend/internal/handlers"
	"github.com/anish-chanda/cadence/backend/internal/logger"
	"github.com/anish-chanda/cadence/backend/internal/store"
	"github.com/anish-chanda/cadence/backend/internal/store/local_store"
	"github.com/anish-chanda/cadence/backend/internal/valhalla"
	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	authpkg "github.com/go-pkgz/auth/v2"
	"github.com/go-pkgz/auth/v2/avatar"
	"github.com/go-pkgz/auth/v2/provider"
	"github.com/go-pkgz/auth/v2/token"
	"github.com/jackc/pgx/v5/pgxpool"
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

	// Log version information
	if Version == "" || BuildHash == "" {
		log.Warn("Running development build - version info not injected")
	} else {
		log.Info(fmt.Sprintf("Starting Cadent API - Version: %s, Build: %s", Version, BuildHash))
	}

	// Initialize storage
	log.Info("Initializing storage")
	storageConfig, err := store.ParseStorageDSN(cfg.StorageDsn)
	if err != nil {
		log.Error("Invalid storage DSN", err)
		return
	}

	var objectStore store.ObjectStore
	switch storageConfig.Type {
	case "local":
		objectStore = local_store.NewLocalStore(*log)
	case "s3":
		log.Error("S3 storage not yet implemented", nil)
		return
	default:
		log.Error(fmt.Sprintf("Unsupported storage type: %s", storageConfig.Type), nil)
		return
	}

	if err := objectStore.Connect(cfg.StorageDsn); err != nil {
		log.Error("Failed to connect to storage", err)
		return
	}

	// Initialize Valhalla client
	log.Info("Initializing Valhalla client")
	valhallaClient := valhalla.NewClient(cfg.ValhallaURL)

	log.Info("Initializing database")
	database := postgres.NewPostgresDB(*log)

	// Create pool configuration
	poolConfig, err := createPoolConfig(cfg)
	if err != nil {
		log.Error("Failed to create pool configuration", err)
		return
	}

	if err := database.ConnectWithPoolConfig(cfg.Dsn, poolConfig); err != nil {
		log.Error("Failed to connect to database", err)
		return
	}

	defer gracefulShutdown(database, objectStore, *log)

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
		Issuer:         "cadent",
		URL:            cfg.BaseURL,
		DisableXSRF:    true,
		AvatarStore:    avatar.NewLocalFS(cfg.AvatarPath),
	}

	// Create auth service with providers
	authService := authpkg.NewService(authOptions)

	authService.AddDirectProvider("local", provider.CredCheckerFunc(func(user, password string) (ok bool, err error) {
		return handlers.HandleLogin(database, user, password)
	}))

	// Create router
	router := chi.NewRouter()

	// Add middlewares
	router.Use(middleware.Logger)

  // Health check endpoint
  router.Get("/health", func(w http.ResponseWriter, r *http.Request) {
	  w.Header().Set("Content-Type", "application/json")
	  w.WriteHeader(http.StatusOK)
	  fmt.Fprint(w, `{"status":"ok"}`)
  })

  // Mount auth routes under /api
  authHandler, avatarHandler := authService.Handlers()

  // Wrap auth handler to fix HTTP status codes - return 401 for authentication failures instead of 403
  wrappedAuthHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
	  // Intercept status codes to convert 403 to 401 for login failures
	  // Per HTTP spec: 401 = authentication failed, 403 = authorization/permission denied
	  isLoginPath := strings.Contains(r.URL.Path, "/login")
	  rw := &statusCodeInterceptor{
		  ResponseWriter: w,
		  isLoginPath:    isLoginPath,
	  }
	  authHandler.ServeHTTP(rw, r)
  })

  router.Mount("/api/auth", wrappedAuthHandler)
  router.Mount("/api/avatar", avatarHandler)

	// Custom auth endpoints
	router.Post("/api/signup", handlers.SignupHandler(database, *log))

	// Mount V1 API routes
	router.Route("/api/v1", func(r chi.Router) {
		// Protected routes that require authentication
		r.Group(func(r chi.Router) {
			// Use auth middleware for protected routes
			authMiddleware := authService.Middleware()
			r.Use(authMiddleware.Auth)

			// Activity endpoints
			r.Post("/activities", handlers.HandleCreateActivity(database, valhallaClient, objectStore, *log))
			r.Get("/activities", handlers.HandleGetActivities(database, *log))
			r.Get("/activities/{id}/streams", handlers.HandleGetActivityStreams(database, *log))

			// User endpoints
			r.Get("/user", handlers.HandleGetUser(database, *log))
			r.Patch("/user", handlers.HandleUpdateUser(database, *log))
		})
	})

	// Catch-all: serve embedded React SPA for all non-API paths
	router.Handle("/*", spaHandler())

	// Start listening
	log.Info(fmt.Sprintf("Starting server on port %d", cfg.Port))
	if err := http.ListenAndServe(fmt.Sprintf(":%d", cfg.Port), router); err != nil {
		log.Error("Server failed to start", err)
	}
}

func gracefulShutdown(database db.Database, objectStore store.ObjectStore, log logger.ServiceLogger) {
	log.Info("Shutting down gracefully...")

	// Close storage connection
	if err := objectStore.Close(); err != nil {
		log.Error("Error closing storage connection", err)
	} else {
		log.Info("Storage connection closed successfully")
	}

	// Close database connection
	if err := database.Close(); err != nil {
		log.Error("Error closing database connection", err)
	} else {
		log.Info("Database connection closed successfully")
	}
}

func createPoolConfig(cfg Config) (*pgxpool.Config, error) {
	poolConfig, err := pgxpool.ParseConfig(cfg.Dsn)
	if err != nil {
		return nil, fmt.Errorf("failed to parse DSN: %w", err)
	}

	// Set pool configuration from config
	poolConfig.MaxConns = cfg.DBMaxConns
	poolConfig.MinConns = cfg.DBMinConns
	poolConfig.MaxConnLifetime = time.Duration(cfg.DBMaxConnLifetime) * time.Minute
	poolConfig.MaxConnIdleTime = time.Duration(cfg.DBMaxConnIdleTime) * time.Minute

	return poolConfig, nil
}

type statusCodeInterceptor struct {
	http.ResponseWriter
	isLoginPath bool
}

func (w *statusCodeInterceptor) WriteHeader(code int) {
	if w.isLoginPath && code == http.StatusForbidden {
		code = http.StatusUnauthorized
	}
	w.ResponseWriter.WriteHeader(code)
}
