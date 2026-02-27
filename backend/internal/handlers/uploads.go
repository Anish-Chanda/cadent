package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"path/filepath"
	"strings"

	"github.com/anish-chanda/cadence/backend/internal/db"
	"github.com/anish-chanda/cadence/backend/internal/logger"
	"github.com/anish-chanda/cadence/backend/internal/models"
	"github.com/anish-chanda/cadence/backend/internal/store"
	"github.com/anish-chanda/cadence/backend/internal/valhalla"
	"github.com/google/uuid"
)

const (
	maxUploadSize = 25 * 1024 * 1024 // 25MB in bytes
)

// ActivityMetadata holds parsed metadata from a GPX/FIT file
type ActivityMetadata struct {
	Title        string
	Description  string
	ActivityType models.ActivityType // must be one of our supported activity types
}

// UploadResponse is the response returned after successfully uploading an activity
type UploadResponse struct {
	ID string `json:"id"`
}

// HandleActivityUpload supports uploading/importing activites from GPX and FIT files.
// Parameters- enrich (true) to add elevation data, title and description to override file metadata
func HandleActivityUpload(database db.Database, valhallaClient *valhalla.Client, objectStore store.ObjectStore, log logger.ServiceLogger) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := context.Background()

		// Limit request body size
		r.Body = http.MaxBytesReader(w, r.Body, maxUploadSize)

		// Parse multipart form with size limit
		if err := r.ParseMultipartForm(maxUploadSize); err != nil {
			log.Error("Failed to parse multipart form", err)
			// Check if it's a size error or content-type error
			if strings.Contains(err.Error(), "Content-Type") || strings.Contains(err.Error(), "multipart") {
				http.Error(w, "Request must use multipart/form-data Content-Type", http.StatusBadRequest)
			} else {
				http.Error(w, "File size exceeds maximum allowed size of 25MB", http.StatusRequestEntityTooLarge)
			}
			return
		}

		// Get the file from form data
		file, header, err := r.FormFile("file")
		if err != nil {
			log.Error("Failed to get file from form", err)
			http.Error(w, "Missing or invalid 'file' field in form data", http.StatusBadRequest)
			return
		}
		defer file.Close()

		// Determine file type from extension
		filename := header.Filename
		ext := strings.ToLower(filepath.Ext(filename))

		// Validate file type
		if ext != ".gpx" && ext != ".fit" {
			http.Error(w, "Unsupported file type. Only GPX and FIT files are allowed", http.StatusBadRequest)
			return
		}

		// Get form parameters
		enrichParam := r.FormValue("enrich")
		shouldEnrich := enrichParam == "true"
		titleOverride := r.FormValue("title")
		descriptionOverride := r.FormValue("description")

		// Get authenticated user ID
		userID, err := getAuthenticatedUserID(ctx, r, database, log)
		if err != nil {
			http.Error(w, err.Error(), http.StatusUnauthorized)
			return
		}

		// Read file content
		fileContent, err := io.ReadAll(file)
		if err != nil {
			log.Error("Failed to read file content", err)
			http.Error(w, "Failed to read uploaded file", http.StatusInternalServerError)
			return
		}

		// Parse file based on type to extract samples and metadata
		var samples []Sample
		var metadata ActivityMetadata
		if ext == ".gpx" {
			samples, metadata, err = processGPXFile(fileContent, filename)
		} else if ext == ".fit" {
			samples, metadata, err = processFITFile(fileContent, filename)
		}

		if err != nil {
			log.Error(fmt.Sprintf("Failed to process %s file", strings.ToUpper(ext[1:])), err)
			http.Error(w, fmt.Sprintf("Failed to process %s file: %v", strings.ToUpper(ext[1:]), err), http.StatusBadRequest)
			return
		}

		// Validate we have minimum samples
		if len(samples) < 2 {
			http.Error(w, "File must contain at least 2 GPS points", http.StatusBadRequest)
			return
		}

		// Override metadata with form values if provided
		if titleOverride != "" {
			metadata.Title = titleOverride
		}
		if descriptionOverride != "" {
			metadata.Description = descriptionOverride
		}

		// Use default title if still empty
		if metadata.Title == "" {
			metadata.Title = fmt.Sprintf("Uploaded %s Activity", strings.ToUpper(ext[1:]))
		}

		// Validate activity type is present (must come from file)
		if metadata.ActivityType == "" {
			http.Error(w, "Activity type not found in file. GPX/FIT file must contain activity type metadata", http.StatusBadRequest)
			return
		}

		// Validate activity type
		if metadata.ActivityType != models.ActivityTypeRun && metadata.ActivityType != models.ActivityTypeRoadBike {
			log.Error("Invalid activity type", fmt.Errorf("unsupported activity_type: %s", metadata.ActivityType))
			http.Error(w, fmt.Sprintf("Invalid activity_type: %s. Supported types: run, road_bike", metadata.ActivityType), http.StatusBadRequest)
			return
		}

		// Generate activity ID upfront for file storage
		activityID := uuid.New()

		// Process GPS data to create polyline and calculate metrics

		// Get elevation data from Valhalla if enrich is enabled

		// Build activity model with metadata and calculated stats

		// Process full-resolution streams from samples

		// Create medium LOD streams using distance decimation

		// Create compressed medium LOD streams

		// If enrichment was requested, update the file content with elevation data
		// TODO: Update fileContent with elevation data from Valhalla if shouldEnrich is true
		_ = shouldEnrich // suppress unused until implemented

		// Store the file to disk in original format (GPX or FIT), including elevation if enrichment requested
		originalFileKey := fmt.Sprintf("activities/%s/%s%s", userID, activityID.String(), ext)
		// TODO: Write fileContent to objectStore at originalFileKey
		_ = originalFileKey // suppress unused until implemented

		// Save activity to database

		// Save activity streams to database

		log.Info(fmt.Sprintf("Successfully processed %s file upload for user %s, activity: %s", strings.ToUpper(ext[1:]), userID, activityID.String()))

		// Return response with activity ID
		response := UploadResponse{
			ID: activityID.String(),
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(w).Encode(response)
	}
}

// processGPXFile parses a GPX file and extracts samples and metadata
// Parsers must convert activity types from GPX/FIT formats to our models.ActivityType enum
func processGPXFile(fileContent []byte, filename string) ([]Sample, ActivityMetadata, error) {
	// TODO: Implement GPX parsing logic
	return nil, ActivityMetadata{}, fmt.Errorf("GPX processing not yet implemented")
}

// processFITFile parses a FIT file and extracts samples and metadata
// Parsers must convert activity types from GPX/FIT formats to our models.ActivityType enum
func processFITFile(fileContent []byte, filename string) ([]Sample, ActivityMetadata, error) {
	// TODO: Implement FIT parsing logic
	return nil, ActivityMetadata{}, fmt.Errorf("FIT processing not yet implemented")
}
