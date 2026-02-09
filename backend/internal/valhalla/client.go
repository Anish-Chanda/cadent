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

// Height API structures
type HeightRequest struct {
	Range           bool   `json:"range"`
	EncodedPolyline string `json:"encoded_polyline"`
	HeightPrecision int    `json:"height_precision"`
}

type HeightResponse struct {
	EncodedPolyline string     `json:"encoded_polyline"`
	Height          []*float64 `json:"height"` // Array of nullable floats for decimal precision
}

func (c *Client) GetHeight(ctx context.Context, req HeightRequest) (*HeightResponse, error) {
	if req.EncodedPolyline == "" {
		return nil, fmt.Errorf("encoded_polyline cannot be empty")
	}

	requestBody := map[string]interface{}{
		"range":            req.Range,
		"encoded_polyline": req.EncodedPolyline,
		"height_precision": req.HeightPrecision,
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
