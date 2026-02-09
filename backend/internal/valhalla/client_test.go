package valhalla

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestNewClient(t *testing.T) {
	baseURL := "https://api.example.com"
	client := NewClient(baseURL)

	if client == nil {
		t.Fatal("NewClient() returned nil")
	}

	if client.baseURL != baseURL {
		t.Errorf("NewClient() baseURL = %s, want %s", client.baseURL, baseURL)
	}

	if client.httpClient == nil {
		t.Fatal("NewClient() httpClient is nil")
	}

	expectedTimeout := 30 * time.Second
	if client.httpClient.Timeout != expectedTimeout {
		t.Errorf("NewClient() timeout = %v, want %v", client.httpClient.Timeout, expectedTimeout)
	}
}

func TestClient_GetHeight_Success(t *testing.T) {
	// Mock server
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Validate request method and path
		if r.Method != "POST" {
			t.Errorf("Expected POST request, got %s", r.Method)
		}
		if r.URL.Path != "/height" {
			t.Errorf("Expected /height path, got %s", r.URL.Path)
		}

		// Validate content type
		contentType := r.Header.Get("Content-Type")
		if contentType != "application/json" {
			t.Errorf("Expected application/json content type, got %s", contentType)
		}

		// Parse and validate request body
		var req HeightRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			t.Errorf("Failed to decode request body: %v", err)
			return
		}

		if req.EncodedPolyline == "" {
			t.Error("Expected non-empty encoded_polyline")
		}

		// Mock response
		response := HeightResponse{
			EncodedPolyline: req.EncodedPolyline,
			Height: []*float64{
				floatPtr(100.5),
				floatPtr(105.2),
				nil, // Test null handling
				floatPtr(110.8),
			},
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(response)
	}))
	defer server.Close()

	client := NewClient(server.URL)
	ctx := context.Background()

	req := HeightRequest{
		Range:           true,
		EncodedPolyline: "test_polyline_123",
		HeightPrecision: 2,
	}

	resp, err := client.GetHeight(ctx, req)
	if err != nil {
		t.Errorf("GetHeight() error = %v, want nil", err)
		return
	}

	if resp == nil {
		t.Fatal("GetHeight() returned nil response")
	}

	if resp.EncodedPolyline != req.EncodedPolyline {
		t.Errorf("Response encoded_polyline = %s, want %s", resp.EncodedPolyline, req.EncodedPolyline)
	}

	if len(resp.Height) != 4 {
		t.Errorf("Response height length = %d, want 4", len(resp.Height))
	}

	// Check specific values
	if resp.Height[0] == nil || *resp.Height[0] != 100.5 {
		t.Errorf("Height[0] = %v, want 100.5", resp.Height[0])
	}
	if resp.Height[2] != nil {
		t.Errorf("Height[2] = %v, want nil", resp.Height[2])
	}
}

func TestClient_GetHeight_EmptyPolyline(t *testing.T) {
	client := NewClient("http://example.com")
	ctx := context.Background()

	req := HeightRequest{
		Range:           true,
		EncodedPolyline: "", // Empty polyline
		HeightPrecision: 2,
	}

	_, err := client.GetHeight(ctx, req)
	if err == nil {
		t.Error("GetHeight() with empty polyline should return error")
		return
	}

	expectedError := "encoded_polyline cannot be empty"
	if !strings.Contains(err.Error(), expectedError) {
		t.Errorf("GetHeight() error = %v, want error containing %s", err, expectedError)
	}
}

func TestClient_GetHeight_ServerError(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte("Internal Server Error"))
	}))
	defer server.Close()

	client := NewClient(server.URL)
	ctx := context.Background()

	req := HeightRequest{
		Range:           true,
		EncodedPolyline: "test_polyline",
		HeightPrecision: 2,
	}

	_, err := client.GetHeight(ctx, req)
	if err == nil {
		t.Error("GetHeight() with server error should return error")
		return
	}

	if !strings.Contains(err.Error(), "height API returned status 500") {
		t.Errorf("GetHeight() error = %v, want error containing status 500", err)
	}
}

func TestClient_GetHeight_InvalidJSON(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte("invalid json{"))
	}))
	defer server.Close()

	client := NewClient(server.URL)
	ctx := context.Background()

	req := HeightRequest{
		Range:           true,
		EncodedPolyline: "test_polyline",
		HeightPrecision: 2,
	}

	_, err := client.GetHeight(ctx, req)
	if err == nil {
		t.Error("GetHeight() with invalid JSON should return error")
		return
	}

	if !strings.Contains(err.Error(), "failed to parse height response") {
		t.Errorf("GetHeight() error = %v, want error containing parse error", err)
	}
}

func TestClient_GetHeight_ContextCancellation(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Delay to test context cancellation
		time.Sleep(100 * time.Millisecond)
		w.WriteHeader(http.StatusOK)
	}))
	defer server.Close()

	client := NewClient(server.URL)
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Millisecond)
	defer cancel()

	req := HeightRequest{
		Range:           true,
		EncodedPolyline: "test_polyline",
		HeightPrecision: 2,
	}

	_, err := client.GetHeight(ctx, req)
	if err == nil {
		t.Error("GetHeight() with cancelled context should return error")
		return
	}

	if !strings.Contains(err.Error(), "context deadline exceeded") &&
		!strings.Contains(err.Error(), "height API request failed") {
		t.Errorf("GetHeight() error = %v, want context cancellation error", err)
	}
}

func TestClient_GetHeight_NetworkError(t *testing.T) {
	// Use an invalid URL to simulate network error
	client := NewClient("http://127.0.0.1:1") // Port 1 should be closed/invalid
	ctx, cancel := context.WithTimeout(context.Background(), 1*time.Second)
	defer cancel()

	req := HeightRequest{
		Range:           true,
		EncodedPolyline: "test_polyline",
		HeightPrecision: 2,
	}

	_, err := client.GetHeight(ctx, req)
	if err == nil {
		t.Error("GetHeight() with invalid URL should return error")
	}
}

func TestClient_GetHeight_VariousParameterValues(t *testing.T) {
	tests := []struct {
		name string
		req  HeightRequest
	}{
		{
			name: "range_false",
			req: HeightRequest{
				Range:           false,
				EncodedPolyline: "test_polyline",
				HeightPrecision: 0,
			},
		},
		{
			name: "high_precision",
			req: HeightRequest{
				Range:           true,
				EncodedPolyline: "test_polyline_long_example",
				HeightPrecision: 5,
			},
		},
		{
			name: "negative_precision",
			req: HeightRequest{
				Range:           true,
				EncodedPolyline: "test",
				HeightPrecision: -1,
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				var req HeightRequest
				json.NewDecoder(r.Body).Decode(&req)

				response := HeightResponse{
					EncodedPolyline: req.EncodedPolyline,
					Height:          []*float64{floatPtr(100.0)},
				}
				json.NewEncoder(w).Encode(response)
			}))
			defer server.Close()

			client := NewClient(server.URL)
			ctx := context.Background()

			resp, err := client.GetHeight(ctx, tt.req)
			if err != nil {
				t.Errorf("GetHeight() error = %v, want nil", err)
				return
			}

			if resp.EncodedPolyline != tt.req.EncodedPolyline {
				t.Errorf("Response polyline mismatch")
			}
		})
	}
}

func TestHeightRequest_Marshal(t *testing.T) {
	req := HeightRequest{
		Range:           true,
		EncodedPolyline: "test_polyline",
		HeightPrecision: 3,
	}

	data, err := json.Marshal(req)
	if err != nil {
		t.Errorf("Failed to marshal HeightRequest: %v", err)
		return
	}

	var unmarshaled HeightRequest
	err = json.Unmarshal(data, &unmarshaled)
	if err != nil {
		t.Errorf("Failed to unmarshal HeightRequest: %v", err)
		return
	}

	if unmarshaled.Range != req.Range {
		t.Errorf("Unmarshaled Range = %t, want %t", unmarshaled.Range, req.Range)
	}
	if unmarshaled.EncodedPolyline != req.EncodedPolyline {
		t.Errorf("Unmarshaled EncodedPolyline = %s, want %s", unmarshaled.EncodedPolyline, req.EncodedPolyline)
	}
	if unmarshaled.HeightPrecision != req.HeightPrecision {
		t.Errorf("Unmarshaled HeightPrecision = %d, want %d", unmarshaled.HeightPrecision, req.HeightPrecision)
	}
}

func TestHeightResponse_Marshal(t *testing.T) {
	resp := HeightResponse{
		EncodedPolyline: "test_polyline",
		Height: []*float64{
			floatPtr(100.5),
			nil,
			floatPtr(-50.25),
		},
	}

	data, err := json.Marshal(resp)
	if err != nil {
		t.Errorf("Failed to marshal HeightResponse: %v", err)
		return
	}

	var unmarshaled HeightResponse
	err = json.Unmarshal(data, &unmarshaled)
	if err != nil {
		t.Errorf("Failed to unmarshal HeightResponse: %v", err)
		return
	}

	if unmarshaled.EncodedPolyline != resp.EncodedPolyline {
		t.Errorf("Unmarshaled EncodedPolyline = %s, want %s", unmarshaled.EncodedPolyline, resp.EncodedPolyline)
	}

	if len(unmarshaled.Height) != len(resp.Height) {
		t.Errorf("Unmarshaled Height length = %d, want %d", len(unmarshaled.Height), len(resp.Height))
		return
	}

	for i, h := range unmarshaled.Height {
		expected := resp.Height[i]
		if (h == nil) != (expected == nil) {
			t.Errorf("Height[%d] null status mismatch", i)
			continue
		}
		if h != nil && expected != nil && *h != *expected {
			t.Errorf("Height[%d] = %f, want %f", i, *h, *expected)
		}
	}
}

// Helper function to create float64 pointer
func floatPtr(f float64) *float64 {
	return &f
}
