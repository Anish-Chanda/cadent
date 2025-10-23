package valhalla

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/anish-chanda/cadence/backend/internal/logger"
)

// Client represents a Valhalla API client
type Client struct {
	baseURL    string
	httpClient *http.Client
	log        logger.ServiceLogger
}

// NewClient creates a new Valhalla client
func NewClient(baseURL string, log logger.ServiceLogger) *Client {
	return &Client{
		baseURL: baseURL,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
		log: log,
	}
}

// GPSPoint represents a GPS coordinate point
type GPSPoint struct {
	Lat float64 `json:"lat"`
	Lon float64 `json:"lon"`
}

// ShapeMatch represents the shape matching algorithm type
type ShapeMatch string

const (
	ShapeMatchEdgeWalk   ShapeMatch = "edge_walk"
	ShapeMatchMapSnap    ShapeMatch = "map_snap"
	ShapeMatchWalkOrSnap ShapeMatch = "walk_or_snap"
)

// Costing represents the costing model for routing
type Costing string

const (
	CostingAuto       Costing = "auto"
	CostingBicycle    Costing = "bicycle"
	CostingPedestrian Costing = "pedestrian"
	CostingTaxi       Costing = "taxi"
	CostingBus        Costing = "bus"
)

// TraceOptions contains additional options for trace requests
type TraceOptions struct {
	SearchRadius          *int `json:"search_radius,omitempty"`
	GPSAccuracy           *int `json:"gps_accuracy,omitempty"`
	BreakageDistance      *int `json:"breakage_distance,omitempty"`
	InterpolationDistance *int `json:"interpolation_distance,omitempty"`
}

// TraceRouteRequest represents a map matching request for trace_route
type TraceRouteRequest struct {
	Shape            []GPSPoint    `json:"shape"`
	ShapeMatch       *ShapeMatch   `json:"shape_match,omitempty"`
	Costing          Costing       `json:"costing"`
	BeginTime        *int64        `json:"begin_time,omitempty"`
	Durations        []int         `json:"durations,omitempty"`
	UseTimestamps    *bool         `json:"use_timestamps,omitempty"`
	TraceOptions     *TraceOptions `json:"trace_options,omitempty"`
	LinearReferences *bool         `json:"linear_references,omitempty"`
}

// Leg represents a route leg in the response
type Leg struct {
	Summary struct {
		Time   float64 `json:"time"`
		Length float64 `json:"length"`
		MinLat float64 `json:"min_lat"`
		MinLon float64 `json:"min_lon"`
		MaxLat float64 `json:"max_lat"`
		MaxLon float64 `json:"max_lon"`
	} `json:"summary"`
	Shape string `json:"shape"`
}

// TraceRouteResponse represents the response from trace_route
type TraceRouteResponse struct {
	Trip struct {
		Legs    []Leg `json:"legs"`
		Summary struct {
			Time   float64 `json:"time"`
			Length float64 `json:"length"`
			MinLat float64 `json:"min_lat"`
			MinLon float64 `json:"min_lon"`
			MaxLat float64 `json:"max_lat"`
			MaxLon float64 `json:"max_lon"`
		} `json:"summary"`
		Status        int    `json:"status"`
		StatusMessage string `json:"status_message"`
		Units         string `json:"units"`
	} `json:"trip"`
	Alternates []interface{} `json:"alternates,omitempty"`
	Warnings   []string      `json:"warnings,omitempty"`
}

// TraceRoute performs map matching using the trace_route action
func (c *Client) TraceRoute(ctx context.Context, req TraceRouteRequest) (*TraceRouteResponse, error) {
	c.log.Debug("Performing Valhalla trace_route map matching")

	if len(req.Shape) == 0 {
		return nil, fmt.Errorf("shape cannot be empty")
	}

	// Set default shape match if not provided
	if req.ShapeMatch == nil {
		defaultMatch := ShapeMatchMapSnap
		req.ShapeMatch = &defaultMatch
	}

	// Set default costing if not provided
	if req.Costing == "" {
		req.Costing = CostingAuto
	}

	// Prepare the request body
	requestBody := map[string]interface{}{
		"shape":       req.Shape,
		"costing":     req.Costing,
		"shape_match": req.ShapeMatch,
	}

	if req.BeginTime != nil {
		requestBody["begin_time"] = *req.BeginTime
	}
	if req.Durations != nil {
		requestBody["durations"] = req.Durations
	}
	if req.UseTimestamps != nil {
		requestBody["use_timestamps"] = *req.UseTimestamps
	}
	if req.TraceOptions != nil {
		requestBody["trace_options"] = req.TraceOptions
	}
	if req.LinearReferences != nil {
		requestBody["linear_references"] = *req.LinearReferences
	}

	jsonData, err := json.Marshal(requestBody)
	if err != nil {
		c.log.Error("Failed to marshal trace_route request", err)
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}

	// Make the HTTP request
	url := fmt.Sprintf("%s/trace_route", c.baseURL)
	httpReq, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		c.log.Error("Failed to create HTTP request", err)
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	httpReq.Header.Set("Content-Type", "application/json")

	c.log.Debug(fmt.Sprintf("Making Valhalla API call to %s with %d GPS points", url, len(req.Shape)))

	resp, err := c.httpClient.Do(httpReq)
	if err != nil {
		c.log.Error("Valhalla API request failed", err)
		return nil, fmt.Errorf("API request failed: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		c.log.Error("Failed to read response body", err)
		return nil, fmt.Errorf("failed to read response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		c.log.Error(fmt.Sprintf("Valhalla API returned status %d", resp.StatusCode), fmt.Errorf("response: %s", string(body)))
		return nil, fmt.Errorf("API returned status %d: %s", resp.StatusCode, string(body))
	}

	var result TraceRouteResponse
	if err := json.Unmarshal(body, &result); err != nil {
		c.log.Error("Failed to unmarshal response", err)
		return nil, fmt.Errorf("failed to parse response: %w", err)
	}

	c.log.Info(fmt.Sprintf("Successfully map-matched %d GPS points, got %.2fkm route", len(req.Shape), result.Trip.Summary.Length))

	return &result, nil
}
