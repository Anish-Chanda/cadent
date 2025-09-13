package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/anish-chanda/cadence/backend/internal/db"
)

func Placeholder(database db.Database) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		response := map[string]string{
			"message": "Placeholder endpoint - API under development",
			"status":  "ok",
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(response)
	}
}
