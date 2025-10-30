package valhalla

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

// Client represents a Valhalla API client
type Client struct {
	baseURL    string
	httpClient *http.Client
}

func NewClient(baseURL string) *Client {
	return &Client{
		baseURL: baseURL,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

type GPSPoint struct {
	Lat  float64 `json:"lat"`
	Lon  float64 `json:"lon"`
	Time *int64  `json:"time,omitempty"` // seconds since epoch
}

type ShapeMatch string

const (
	ShapeMatchEdgeWalk   ShapeMatch = "edge_walk"
	ShapeMatchMapSnap    ShapeMatch = "map_snap"
	ShapeMatchWalkOrSnap ShapeMatch = "walk_or_snap"
)

type Costing string

const (
	CostingAuto       Costing = "auto"
	CostingBicycle    Costing = "bicycle"
	CostingPedestrian Costing = "pedestrian"
	CostingTaxi       Costing = "taxi"
	CostingBus        Costing = "bus"
)

type TraceOptions struct {
	SearchRadius          *int `json:"search_radius,omitempty"`
	GPSAccuracy           *int `json:"gps_accuracy,omitempty"`
	BreakageDistance      *int `json:"breakage_distance,omitempty"`
	InterpolationDistance *int `json:"interpolation_distance,omitempty"`
}

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

type Summary struct {
	Time   float64 `json:"time"`
	Length float64 `json:"length"`
	MinLat float64 `json:"min_lat"`
	MinLon float64 `json:"min_lon"`
	MaxLat float64 `json:"max_lat"`
	MaxLon float64 `json:"max_lon"`
}

type Leg struct {
	Summary Summary `json:"summary"`
	Shape   string  `json:"shape"`
}

type Trip struct {
	Legs          []Leg   `json:"legs"`
	Summary       Summary `json:"summary"`
	Status        int     `json:"status"`
	StatusMessage string  `json:"status_message"`
	Units         string  `json:"units"`
}

type Alternate struct {
	Trip Trip `json:"trip"`
}

type TraceRouteResponse struct {
	Trip       Trip        `json:"trip"`
	Alternates []Alternate `json:"alternates,omitempty"`
	Warnings   []string    `json:"warnings,omitempty"`
}

// Height API structures
type HeightRequest struct {
	Range           bool   `json:"range"`
	EncodedPolyline string `json:"encoded_polyline"`
}

type HeightResponse struct {
	EncodedPolyline string  `json:"encoded_polyline"`
	RangeHeight     [][]int `json:"range_height"`
}

func (c *Client) TraceRoute(ctx context.Context, req TraceRouteRequest) (*TraceRouteResponse, error) {
	if len(req.Shape) == 0 {
		return nil, fmt.Errorf("shape cannot be empty")
	}
	if req.ShapeMatch == nil {
		def := ShapeMatchMapSnap
		req.ShapeMatch = &def
	}
	if req.Costing == "" {
		req.Costing = CostingBicycle
	}

	requestBody := map[string]interface{}{
		"shape":       req.Shape,
		"costing":     req.Costing,
		"shape_match": req.ShapeMatch,
	}
	if req.BeginTime != nil {
		requestBody["begin_time"] = *req.BeginTime
	}
	if req.Durations != nil && len(req.Durations) > 0 {
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
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}

	url := fmt.Sprintf("%s/trace_route", c.baseURL)
	httpReq, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("API request failed: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %w", err)
	}
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("API returned status %d: %s", resp.StatusCode, string(body))
	}

	var result TraceRouteResponse
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, fmt.Errorf("failed to parse response: %w", err)
	}
	return &result, nil
}

func (c *Client) GetHeight(ctx context.Context, req HeightRequest) (*HeightResponse, error) {
	if req.EncodedPolyline == "" {
		return nil, fmt.Errorf("encoded_polyline cannot be empty")
	}

	requestBody := map[string]interface{}{
		"range":            req.Range,
		"encoded_polyline": req.EncodedPolyline,
	}

	jsonData, err := json.Marshal(requestBody)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal height request: %w", err)
	}

	url := fmt.Sprintf("%s/height", c.baseURL)
	httpReq, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return nil, fmt.Errorf("failed to create height request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("height API request failed: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read height response: %w", err)
	}
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("height API returned status %d: %s", resp.StatusCode, string(body))
	}

	var result HeightResponse
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, fmt.Errorf("failed to parse height response: %w", err)
	}
	return &result, nil
}
