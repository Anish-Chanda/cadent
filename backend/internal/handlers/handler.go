package handlers

import (
	"github.com/anish-chanda/cadent/backend/internal/db"
	"github.com/anish-chanda/cadent/backend/internal/logger"
	"github.com/anish-chanda/cadent/backend/internal/store"
	"github.com/anish-chanda/cadent/backend/internal/valhalla"
)

// Handler groups shared dependencies used by HTTP and auth handlers.
type Handler struct {
	database       db.Database
	valhallaClient *valhalla.Client
	objectStore    store.ObjectStore
	log            logger.ServiceLogger
}

// NewHandler creates a handler set with shared dependencies.
func NewHandler(database db.Database, valhallaClient *valhalla.Client, objectStore store.ObjectStore, log logger.ServiceLogger) *Handler {
	return &Handler{
		database:       database,
		valhallaClient: valhallaClient,
		objectStore:    objectStore,
		log:            log,
	}
}
