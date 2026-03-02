package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"encoding/xml"
	"fmt"
	"io"
	"net/http"
	"path/filepath"
	"strings"
	"time"

	"github.com/anish-chanda/cadence/backend/internal/db"
	"github.com/anish-chanda/cadence/backend/internal/logger"
	"github.com/anish-chanda/cadence/backend/internal/models"
	"github.com/anish-chanda/cadence/backend/internal/store"
	"github.com/anish-chanda/cadence/backend/internal/valhalla"
	"github.com/google/uuid"
	gpxlib "github.com/twpayne/go-gpx"
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

		// Parse file based on type to extract samples, metadata and whether elevation is embedded
		var samples []Sample
		var metadata ActivityMetadata
		var hasElevation bool
		switch ext {
		case ".gpx":
			samples, metadata, hasElevation, err = processGPXFile(fileContent, filename)
		case ".fit":
			samples, metadata, hasElevation, err = processFITFile(fileContent, filename)
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

		// Process GPS data to create polyline and calculate metrics
		polyline, totalDistance, bounds := processGPSData(samples)

		// Call Valhalla if enrichment requested AND file does not already have elevation data.
		var elevationData *valhalla.ElevationChange
		var elevationHeights []float64

		if shouldEnrich && !hasElevation {
			elevationData, elevationHeights = getElevationDataAndHeights(ctx, valhallaClient, polyline, log)

			// For GPX uploads we can write the elevation back into the file so the stored copy
			// reflects the enriched data.
			if ext == ".gpx" && elevationHeights != nil {
				if updated, enrichErr := enrichGPXWithElevation(fileContent, elevationHeights); enrichErr != nil {
					log.Error("Failed to enrich GPX with elevation data, storing original", enrichErr)
				} else {
					fileContent = updated
				}
			}
		} else if hasElevation {
			// File already carries elevation, derive stats from the embedded sample values so the
			// activity record has valid gain/loss/max/min.
			elevationData = calculateElevationStatsFromSamples(samples)
		}

		// Calculate time-based metrics
		elapsedSeconds := calculateElapsedSeconds(samples)
		avgSpeedMs := calculateAverageSpeed(totalDistance, elapsedSeconds)

		// Build activity model with metadata and calculated stats
		var descPtr *string
		if metadata.Description != "" {
			descPtr = &metadata.Description
		}
		uploadReq := CreateActivityRequest{
			ClientActivityID: uuid.New(),
			ActivityType:     string(metadata.ActivityType),
			Title:            metadata.Title,
			Description:      descPtr,
			Samples:          samples,
		}
		activity := buildActivityModel(uploadReq, userID, polyline, totalDistance, bounds, elevationData, elapsedSeconds, avgSpeedMs)

		// Store the file to disk in original format (GPX or FIT), including elevation if enrichment was applied
		originalFileKey := fmt.Sprintf("activities/%s/%s%s", userID, activity.ID.String(), ext)
		fileReader := bytes.NewReader(fileContent)
		if err := objectStore.PutObject(ctx, originalFileKey, fileReader, int64(len(fileContent))); err != nil {
			log.Error("Failed to store uploaded file", err)
			http.Error(w, "Failed to store uploaded file", http.StatusInternalServerError)
			return
		}
		activity.FileURL = &originalFileKey

		// Process full-resolution streams from samples
		fullStream := processFullResolutionStreams(samples, elevationData, elevationHeights)

		// Validate stream alignment
		if err := validateStreamAlignment(fullStream, len(samples)); err != nil {
			log.Error("Stream alignment validation failed", err)
			http.Error(w, "Internal stream processing error", http.StatusInternalServerError)
			return
		}

		// Create medium LOD streams using distance decimation
		keepIndices := decimateByDistance(fullStream, MediumLODTargetPoints)

		// Create compressed medium LOD streams
		activityStreams, err := createCompressedStreams(activity.ID, keepIndices, fullStream)
		if err != nil {
			log.Error("Failed to create compressed streams", err)
			http.Error(w, "Failed to process stream data", http.StatusInternalServerError)
			return
		}

		// Save activity to database
		if err := database.CreateActivity(ctx, activity); err != nil {
			log.Error("Failed to save activity to database", err)
			http.Error(w, "Failed to save activity", http.StatusInternalServerError)
			return
		}

		// Save activity streams to database
		if len(activityStreams) > 0 {
			if err := database.CreateActivityStreams(ctx, activityStreams); err != nil {
				log.Error("Failed to save activity streams to database", err)
				// Log error but don't fail the request since main activity was saved
				log.Info("Activity created successfully but streams failed to save")
			} else {
				log.Debug(fmt.Sprintf("Successfully saved %d streams for activity: %s", len(activityStreams), activity.ID.String()))
			}
		}

		log.Info(fmt.Sprintf("Successfully processed %s file upload for user %s, activity: %s", strings.ToUpper(ext[1:]), userID, activity.ID.String()))

		// Return response with activity ID
		response := UploadResponse{
			ID: activity.ID.String(),
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(w).Encode(response)
	}
}

// processGPXFile parses a GPX file and extracts samples, metadata, and whether embedded elevation is present.
// Parsers must convert activity types from GPX/FIT formats to our models.ActivityType enum.
func processGPXFile(fileContent []byte, filename string) ([]Sample, ActivityMetadata, bool, error) {
	g, err := gpxlib.Read(bytes.NewReader(fileContent))
	if err != nil {
		return nil, ActivityMetadata{}, false, fmt.Errorf("failed to parse GPX file: %w", err)
	}

	if len(g.Trk) == 0 {
		return nil, ActivityMetadata{}, false, fmt.Errorf("GPX file contains no tracks")
	}

	var samples []Sample
	hasElevation := false

	for _, trk := range g.Trk {
		for _, seg := range trk.TrkSeg {
			for _, pt := range seg.TrkPt {
				if pt.Time.IsZero() {
					continue // skip points without a valid timestamp
				}

				s := Sample{
					T:   pt.Time.UnixMilli(),
					Lat: pt.Lat,
					Lon: pt.Lon,
				}

				if pt.Ele != 0 {
					ele := pt.Ele
					s.Ele = &ele
					hasElevation = true
				}

				samples = append(samples, s)
			}
		}
	}

	if len(samples) == 0 {
		return nil, ActivityMetadata{}, false, fmt.Errorf("GPX file contains no track points with valid timestamps")
	}

	// Extract metadata
	var metadata ActivityMetadata

	// Title: metadata name takes priority, then first track name; handler assigns the default when empty
	if g.Metadata != nil && g.Metadata.Name != "" {
		metadata.Title = g.Metadata.Name
	} else if g.Trk[0].Name != "" {
		metadata.Title = g.Trk[0].Name
	}

	// Description: only use the explicit metadata description
	if g.Metadata != nil && g.Metadata.Desc != "" {
		metadata.Description = g.Metadata.Desc
	}

	// Activity type from the first track's Type field
	if g.Trk[0].Type != "" {
		metadata.ActivityType = mapGPXActivityType(g.Trk[0].Type)
	}

	return samples, metadata, hasElevation, nil
}

// mapGPXActivityType maps a raw GPX/Strava/Garmin activity type string to our models.ActivityType.
func mapGPXActivityType(gpxType string) models.ActivityType {
	normalized := strings.ToLower(strings.TrimSpace(gpxType))
	switch {
	case strings.Contains(normalized, "run"):
		return models.ActivityTypeRun
	case strings.Contains(normalized, "cycl") ||
		strings.Contains(normalized, "bike") ||
		strings.Contains(normalized, "biking") ||
		normalized == "road_bike":
		return models.ActivityTypeRoadBike
	default:
		// Return as-is and let the caller's validation surface an unsupported type error.
		return models.ActivityType(normalized)
	}
}

// enrichGPXWithElevation writes Valhalla-sourced elevation values back into the GPX track points
// and returns the re-serialised XML bytes. Only points with valid timestamps are updated (matching
// the order they were extracted by processGPXFile).
func enrichGPXWithElevation(fileContent []byte, heights []float64) ([]byte, error) {
	g, err := gpxlib.Read(bytes.NewReader(fileContent))
	if err != nil {
		return nil, fmt.Errorf("failed to re-parse GPX for enrichment: %w", err)
	}

	// Ensure metadata block exists and carries a modification timestamp
	if g.Metadata == nil {
		g.Metadata = &gpxlib.MetadataType{}
	}
	if g.Metadata.Time.IsZero() {
		g.Metadata.Time = time.Now().UTC()
	}

	heightIdx := 0
	for _, trk := range g.Trk {
		for _, seg := range trk.TrkSeg {
			for _, pt := range seg.TrkPt {
				if pt.Time.IsZero() {
					continue
				}
				if heightIdx < len(heights) {
					pt.Ele = heights[heightIdx]
					heightIdx++
				}
			}
		}
	}

	var buf bytes.Buffer
	buf.WriteString(xml.Header)
	if err := g.Write(&buf); err != nil {
		return nil, fmt.Errorf("failed to serialise enriched GPX: %w", err)
	}

	return buf.Bytes(), nil
}

// calculateElevationStatsFromSamples derives elevation metrics from samples that already carry
// embedded elevation data, reusing the same threshold-based calculation as the Valhalla path.
func calculateElevationStatsFromSamples(samples []Sample) *valhalla.ElevationChange {
	heights := make([]*float64, len(samples))
	for i, s := range samples {
		if s.Ele != nil {
			h := *s.Ele
			heights[i] = &h
		}
	}
	result := valhalla.CalculateElevationChange(&valhalla.HeightResponse{Height: heights}, 2.0)
	return &result
}

// processFITFile parses a FIT file and extracts samples, metadata, and whether embedded elevation is present.
// Parsers must convert activity types from GPX/FIT formats to our models.ActivityType enum.
func processFITFile(fileContent []byte, filename string) ([]Sample, ActivityMetadata, bool, error) {
	// TODO: Implement FIT parsing logic
	return nil, ActivityMetadata{}, false, fmt.Errorf("FIT processing not yet implemented")
}
