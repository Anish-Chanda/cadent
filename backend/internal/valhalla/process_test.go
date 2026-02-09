package valhalla

import (
	"math"
	"testing"
)

func TestCalculateElevationChange_BasicFunctionality(t *testing.T) {
	tests := []struct {
		name              string
		heightResp        *HeightResponse
		segmentThreshold  float64
		expectedGain      float64
		expectedLoss      float64
		expectedMaxHeight float64
		expectedMinHeight float64
	}{
		{
			name: "simple_uphill",
			heightResp: &HeightResponse{
				Height: []*float64{
					floatPtr(100.0),
					floatPtr(105.0),
					floatPtr(110.0),
					floatPtr(115.0),
				},
			},
			segmentThreshold:  2.0,
			expectedGain:      15.0,
			expectedLoss:      0.0,
			expectedMaxHeight: 115.0,
			expectedMinHeight: 100.0,
		},
		{
			name: "simple_downhill",
			heightResp: &HeightResponse{
				Height: []*float64{
					floatPtr(115.0),
					floatPtr(110.0),
					floatPtr(105.0),
					floatPtr(100.0),
				},
			},
			segmentThreshold:  2.0,
			expectedGain:      0.0,
			expectedLoss:      15.0,
			expectedMaxHeight: 115.0,
			expectedMinHeight: 100.0,
		},
		{
			name: "mixed_terrain",
			heightResp: &HeightResponse{
				Height: []*float64{
					floatPtr(100.0), // start
					floatPtr(105.0), // +5
					floatPtr(110.0), // +5 (total uphill +10)
					floatPtr(108.0), // -2
					floatPtr(105.0), // -3 (total downhill -5, but below threshold)
					floatPtr(112.0), // +7 (new uphill segment)
				},
			},
			segmentThreshold:  5.0,        // Only segments >= 5m count
			expectedGain:      10.0 + 7.0, // First uphill segment (10m) + second uphill segment (7m)
			expectedLoss:      5.0,        // Downhill segment was exactly 5m, equal to threshold, so it is counted
			expectedMaxHeight: 112.0,
			expectedMinHeight: 100.0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := CalculateElevationChange(tt.heightResp, tt.segmentThreshold)

			if math.Abs(result.GainMeters-tt.expectedGain) > 0.01 {
				t.Errorf("GainMeters = %f, want %f", result.GainMeters, tt.expectedGain)
			}
			if math.Abs(result.LossMeters-tt.expectedLoss) > 0.01 {
				t.Errorf("LossMeters = %f, want %f", result.LossMeters, tt.expectedLoss)
			}
			if math.Abs(result.MaxHeight-tt.expectedMaxHeight) > 0.01 {
				t.Errorf("MaxHeight = %f, want %f", result.MaxHeight, tt.expectedMaxHeight)
			}
			if math.Abs(result.MinHeight-tt.expectedMinHeight) > 0.01 {
				t.Errorf("MinHeight = %f, want %f", result.MinHeight, tt.expectedMinHeight)
			}
		})
	}
}

func TestCalculateElevationChange_EdgeCases(t *testing.T) {
	tests := []struct {
		name       string
		heightResp *HeightResponse
		threshold  float64
		validate   func(ElevationChange) bool
	}{
		{
			name:       "nil_response",
			heightResp: nil,
			threshold:  1.0,
			validate: func(result ElevationChange) bool {
				return result.GainMeters == 0.0 && result.LossMeters == 0.0 &&
					result.MaxHeight == 0.0 && result.MinHeight == 0.0
			},
		},
		{
			name: "empty_height_array",
			heightResp: &HeightResponse{
				Height: []*float64{},
			},
			threshold: 1.0,
			validate: func(result ElevationChange) bool {
				return result.GainMeters == 0.0 && result.LossMeters == 0.0 &&
					result.MaxHeight == 0.0 && result.MinHeight == 0.0
			},
		},
		{
			name: "single_point",
			heightResp: &HeightResponse{
				Height: []*float64{floatPtr(100.0)},
			},
			threshold: 1.0,
			validate: func(result ElevationChange) bool {
				return result.GainMeters == 0.0 && result.LossMeters == 0.0 &&
					result.MaxHeight == 100.0 && result.MinHeight == 100.0
			},
		},
		{
			name: "all_null_heights",
			heightResp: &HeightResponse{
				Height: []*float64{nil, nil, nil},
			},
			threshold: 1.0,
			validate: func(result ElevationChange) bool {
				return result.GainMeters == 0.0 && result.LossMeters == 0.0 &&
					result.MaxHeight == 0.0 && result.MinHeight == 0.0
			},
		},
		{
			name: "mixed_null_heights",
			heightResp: &HeightResponse{
				Height: []*float64{
					nil,
					floatPtr(100.0),
					nil,
					floatPtr(105.0),
					nil,
				},
			},
			threshold: 2.0,
			validate: func(result ElevationChange) bool {
				return result.GainMeters == 5.0 && result.LossMeters == 0.0 &&
					result.MaxHeight == 105.0 && result.MinHeight == 100.0
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := CalculateElevationChange(tt.heightResp, tt.threshold)
			if !tt.validate(result) {
				t.Errorf("Validation failed for result: %+v", result)
			}
		})
	}
}

func TestCalculateElevationChange_NegativeElevations(t *testing.T) {
	// Test below sea level scenarios
	heightResp := &HeightResponse{
		Height: []*float64{
			floatPtr(-50.0), // Below sea level
			floatPtr(-45.0), // +5m
			floatPtr(-40.0), // +5m
			floatPtr(-45.0), // -5m
			floatPtr(-55.0), // -10m
		},
	}

	result := CalculateElevationChange(heightResp, 5.0)

	expectedGain := 10.0 // From -50 to -40 (10m gain)
	expectedLoss := 15.0 // From -40 to -55 (15m loss)
	expectedMax := -40.0
	expectedMin := -55.0

	if math.Abs(result.GainMeters-expectedGain) > 0.01 {
		t.Errorf("GainMeters = %f, want %f", result.GainMeters, expectedGain)
	}
	if math.Abs(result.LossMeters-expectedLoss) > 0.01 {
		t.Errorf("LossMeters = %f, want %f", result.LossMeters, expectedLoss)
	}
	if math.Abs(result.MaxHeight-expectedMax) > 0.01 {
		t.Errorf("MaxHeight = %f, want %f", result.MaxHeight, expectedMax)
	}
	if math.Abs(result.MinHeight-expectedMin) > 0.01 {
		t.Errorf("MinHeight = %f, want %f", result.MinHeight, expectedMin)
	}
}

func TestCalculateElevationChange_ThresholdBehavior(t *testing.T) {
	// Test that segments below threshold are ignored
	heightResp := &HeightResponse{
		Height: []*float64{
			floatPtr(100.0),
			floatPtr(102.0), // +2m uphill
			floatPtr(101.0), // -1m downhill
			floatPtr(104.0), // +3m uphill (total segment is only 2m from previous low)
		},
	}

	tests := []struct {
		threshold    float64
		expectedGain float64
		expectedLoss float64
	}{
		{threshold: 1.0, expectedGain: 5.0, expectedLoss: 1.0}, // All segments count: 2m + 3m uphill, 1m downhill
		{threshold: 2.0, expectedGain: 5.0, expectedLoss: 0.0}, // Both uphill segments (2m, 3m) count, 1m downhill doesn't
		{threshold: 3.0, expectedGain: 3.0, expectedLoss: 0.0}, // Only 3m uphill segment counts
	}

	for _, tt := range tests {
		t.Run("", func(t *testing.T) {
			result := CalculateElevationChange(heightResp, tt.threshold)
			if math.Abs(result.GainMeters-tt.expectedGain) > 0.01 {
				t.Errorf("Threshold %f: GainMeters = %f, want %f",
					tt.threshold, result.GainMeters, tt.expectedGain)
			}
			if math.Abs(result.LossMeters-tt.expectedLoss) > 0.01 {
				t.Errorf("Threshold %f: LossMeters = %f, want %f",
					tt.threshold, result.LossMeters, tt.expectedLoss)
			}
		})
	}
}

func TestCalculateElevationChange_LongProfile(t *testing.T) {
	// Test with a longer elevation profile simulating real world data
	heights := []*float64{
		floatPtr(1000.0), // start
		floatPtr(1005.0), // +5
		floatPtr(1010.0), // +5
		floatPtr(1015.0), // +5 (15m uphill)
		floatPtr(1012.0), // -3
		floatPtr(1008.0), // -4
		floatPtr(1005.0), // -3 (10m downhill)
		floatPtr(1020.0), // +15 (major uphill)
		floatPtr(1018.0), // -2
		floatPtr(1025.0), // +7
		floatPtr(1020.0), // -5 (final)
	}

	heightResp := &HeightResponse{Height: heights}
	result := CalculateElevationChange(heightResp, 5.0)

	// Expected: 15m + 15m + 7m = 37m gain, 10m + 5m = 15m loss
	expectedGain := 37.0
	expectedLoss := 15.0
	expectedMax := 1025.0
	expectedMin := 1000.0

	if math.Abs(result.GainMeters-expectedGain) > 0.01 {
		t.Errorf("GainMeters = %f, want %f", result.GainMeters, expectedGain)
	}
	if math.Abs(result.LossMeters-expectedLoss) > 0.01 {
		t.Errorf("LossMeters = %f, want %f", result.LossMeters, expectedLoss)
	}
	if math.Abs(result.MaxHeight-expectedMax) > 0.01 {
		t.Errorf("MaxHeight = %f, want %f", result.MaxHeight, expectedMax)
	}
	if math.Abs(result.MinHeight-expectedMin) > 0.01 {
		t.Errorf("MinHeight = %f, want %f", result.MinHeight, expectedMin)
	}
}

func TestCalculateElevationChange_ZeroThreshold(t *testing.T) {
	heightResp := &HeightResponse{
		Height: []*float64{
			floatPtr(100.0),
			floatPtr(100.1), // +0.1m
			floatPtr(100.0), // -0.1m
		},
	}

	result := CalculateElevationChange(heightResp, 0.0)

	// With zero threshold, all changes should count
	if math.Abs(result.GainMeters-0.1) > 0.01 {
		t.Errorf("GainMeters = %f, want 0.1", result.GainMeters)
	}
	if math.Abs(result.LossMeters-0.1) > 0.01 {
		t.Errorf("LossMeters = %f, want 0.1", result.LossMeters)
	}
}

func TestCalculateElevationChange_FlatTerrain(t *testing.T) {
	heightResp := &HeightResponse{
		Height: []*float64{
			floatPtr(100.0),
			floatPtr(100.0),
			floatPtr(100.0),
			floatPtr(100.0),
		},
	}

	result := CalculateElevationChange(heightResp, 1.0)

	if result.GainMeters != 0.0 {
		t.Errorf("GainMeters = %f, want 0.0", result.GainMeters)
	}
	if result.LossMeters != 0.0 {
		t.Errorf("LossMeters = %f, want 0.0", result.LossMeters)
	}
	if result.MaxHeight != 100.0 {
		t.Errorf("MaxHeight = %f, want 100.0", result.MaxHeight)
	}
	if result.MinHeight != 100.0 {
		t.Errorf("MinHeight = %f, want 100.0", result.MinHeight)
	}
}

func TestCalculateElevationChange_LastSegmentFinalization(t *testing.T) {
	// Test that the last segment is properly finalized
	heightResp := &HeightResponse{
		Height: []*float64{
			floatPtr(100.0),
			floatPtr(110.0), // +10m uphill segment that ends the array
		},
	}

	result := CalculateElevationChange(heightResp, 5.0)

	// The 10m uphill should be counted even though it's the last segment
	if math.Abs(result.GainMeters-10.0) > 0.01 {
		t.Errorf("GainMeters = %f, want 10.0", result.GainMeters)
	}

	// Test downhill ending
	heightResp2 := &HeightResponse{
		Height: []*float64{
			floatPtr(100.0),
			floatPtr(90.0), // -10m downhill segment that ends the array
		},
	}

	result2 := CalculateElevationChange(heightResp2, 5.0)

	// The 10m downhill should be counted even though it's the last segment
	if math.Abs(result2.LossMeters-10.0) > 0.01 {
		t.Errorf("LossMeters = %f, want 10.0", result2.LossMeters)
	}
}

func TestCalculateElevationChange_PrecisionHandling(t *testing.T) {
	heightResp := &HeightResponse{
		Height: []*float64{
			floatPtr(100.123456),
			floatPtr(105.987654), // +5.864198m
			floatPtr(103.456789), // -2.530865m
		},
	}

	result := CalculateElevationChange(heightResp, 2.0)

	// Both segments should count as they exceed 2m threshold
	expectedGain := 5.864198
	expectedLoss := 2.530865

	if math.Abs(result.GainMeters-expectedGain) > 0.01 {
		t.Errorf("GainMeters = %f, want %f", result.GainMeters, expectedGain)
	}
	if math.Abs(result.LossMeters-expectedLoss) > 0.01 {
		t.Errorf("LossMeters = %f, want %f", result.LossMeters, expectedLoss)
	}
}

// Benchmark tests
func BenchmarkCalculateElevationChange(b *testing.B) {
	// Create a realistic elevation profile with 1000 points
	heights := make([]*float64, 1000)
	for i := range heights {
		// Simulate a hilly profile
		elevation := 1000.0 + 100.0*math.Sin(float64(i)/50.0) + 10.0*math.Sin(float64(i)/10.0)
		heights[i] = &elevation
	}

	heightResp := &HeightResponse{Height: heights}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		CalculateElevationChange(heightResp, 5.0)
	}
}
