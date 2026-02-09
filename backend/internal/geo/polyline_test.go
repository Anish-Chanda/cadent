package geo

import (
	"math"
	"testing"
)

// Test data constants
const (
	tolerance = 1e-7 // Tolerance for floating point comparisons
)

// Known test vectors for Google's Polyline Algorithm with precision 6
// These are verified test cases with exact coordinate/polyline pairs
var precision6TestCases = []struct {
	name    string
	points  []Point
	encoded string
}{
	{
		name: "google_docs_precision6_single",
		points: []Point{
			{Lat: 38.500000, Lon: -120.200000},
		},
		encoded: "_izlhA~rlgdF",
	},
	{
		name: "google_docs_precision6_multi",
		points: []Point{
			{Lat: 38.500000, Lon: -120.200000},
			{Lat: 40.700000, Lon: -120.950000},
			{Lat: 43.252000, Lon: -126.453000},
		},
		encoded: "_izlhA~rlgdF_{geC~ywl@_kwzCn`{nI",
	},
	{
		name: "san_francisco_downtown",
		points: []Point{
			{Lat: 37.774900, Lon: -122.419400},
		},
		encoded: "gbr`gAnk{nhF",
	},
	{
		name: "san_francisco_two_blocks",
		points: []Point{
			{Lat: 37.774900, Lon: -122.419400},
			{Lat: 37.784900, Lon: -122.409400},
		},
		encoded: "gbr`gAnk{nhF_pR_pR",
	},
	{
		name: "high_precision_coords",
		points: []Point{
			{Lat: 37.123456, Lon: -122.987654},
		},
		encoded: "_wyxeAjgqqiF",
	},
	{
		name: "negative_coordinates",
		points: []Point{
			{Lat: -33.867487, Lon: 151.207990},
		},
		encoded: "|lbr_Akb_l_H",
	},
	{
		name: "zero_coordinates",
		points: []Point{
			{Lat: 0.0, Lon: 0.0},
		},
		encoded: "??",
	},
	{
		name:    "empty_points",
		points:  []Point{},
		encoded: "",
	},
}

func TestDecode6_ValidPolylines(t *testing.T) {
	// Use all precision 6 test cases for comprehensive testing
	for _, tc := range precision6TestCases {
		t.Run(tc.name, func(t *testing.T) {
			result, err := Decode6(tc.encoded)
			if err != nil {
				t.Errorf("Decode6() error = %v, want nil", err)
				return
			}

			if len(result) != len(tc.points) {
				t.Errorf("Decode6() length = %d, want %d", len(result), len(tc.points))
				return
			}

			for i, point := range result {
				expected := tc.points[i]
				if math.Abs(point.Lat-expected.Lat) > tolerance ||
					math.Abs(point.Lon-expected.Lon) > tolerance {
					t.Errorf("Decode6() point %d = {%f, %f}, want {%f, %f}",
						i, point.Lat, point.Lon, expected.Lat, expected.Lon)
				}
			}
		})
	}

	// Additional edge cases
	tests := []struct {
		name     string
		encoded  string
		expected []Point
	}{
		{
			name:     "empty_string",
			encoded:  "",
			expected: []Point{},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := Decode6(tt.encoded)
			if err != nil {
				t.Errorf("Decode6() error = %v, want nil", err)
				return
			}

			if len(result) != len(tt.expected) {
				t.Errorf("Decode6() length = %d, want %d", len(result), len(tt.expected))
				return
			}

			for i, point := range result {
				expected := tt.expected[i]
				if math.Abs(point.Lat-expected.Lat) > tolerance ||
					math.Abs(point.Lon-expected.Lon) > tolerance {
					t.Errorf("Decode6() point %d = {%f, %f}, want {%f, %f}",
						i, point.Lat, point.Lon, expected.Lat, expected.Lon)
				}
			}
		})
	}
}

func TestDecode6_MalformedInput(t *testing.T) {
	tests := []struct {
		name    string
		encoded string
	}{
		{
			name:    "incomplete_latitude",
			encoded: "o`~oD",
		},
		{
			name:    "incomplete_longitude",
			encoded: "o`~oDrB",
		},
		{
			name:    "truncated_middle",
			encoded: "o`~oDrBw",
		},
		{
			name:    "single_character",
			encoded: "a",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := Decode6(tt.encoded)
			if err != nil {
				t.Errorf("Decode6() should handle malformed input gracefully, got error: %v", err)
			}
			// Should return partial results gracefully
			t.Logf("Partial decode result length: %d", len(result))
		})
	}
}

func TestEncode6_ValidPoints(t *testing.T) {
	// Test encoding using our precision 6 test cases
	for _, tc := range precision6TestCases {
		t.Run(tc.name, func(t *testing.T) {
			encoded := Encode6(tc.points)
			if encoded != tc.encoded {
				t.Errorf("Encode6() = %s, want %s", encoded, tc.encoded)
			}
		})
	}

	// Additional validation tests
	tests := []struct {
		name     string
		points   []Point
		validate func(encoded string) bool
	}{
		{
			name: "very_small_coords",
			points: []Point{
				{Lat: 0.000001, Lon: 0.000001},
			},
			validate: func(encoded string) bool {
				return len(encoded) > 0
			},
		},
		{
			name: "large_coordinates",
			points: []Point{
				{Lat: 89.999999, Lon: 179.999999},
			},
			validate: func(encoded string) bool {
				return len(encoded) > 0
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			encoded := Encode6(tt.points)
			if !tt.validate(encoded) {
				t.Errorf("Encode6() validation failed for encoded string: %s", encoded)
			}
		})
	}
}

func TestEncode6Decode6_RoundTrip(t *testing.T) {
	// Test round-trip encoding/decoding with our precision 6 test cases
	for _, tc := range precision6TestCases {
		t.Run(tc.name+"_roundtrip", func(t *testing.T) {
			// Encode the points
			encoded := Encode6(tc.points)
			if encoded != tc.encoded {
				t.Errorf("Encode6() = %s, want %s", encoded, tc.encoded)
			}

			// Decode back to points
			decoded, err := Decode6(encoded)
			if err != nil {
				t.Errorf("Decode6() error = %v", err)
				return
			}

			// Compare original points with round-trip result
			if len(decoded) != len(tc.points) {
				t.Errorf("Round-trip length = %d, want %d", len(decoded), len(tc.points))
				return
			}

			for i, point := range decoded {
				original := tc.points[i]
				if math.Abs(point.Lat-original.Lat) > tolerance ||
					math.Abs(point.Lon-original.Lon) > tolerance {
					t.Errorf("Round-trip point %d = {%f, %f}, want {%f, %f}",
						i, point.Lat, point.Lon, original.Lat, original.Lon)
				}
			}
		})
	}

	// Additional round-trip tests with generated coordinates
	tests := []struct {
		name   string
		points []Point
	}{
		{
			name: "single_point",
			points: []Point{
				{Lat: 37.77493, Lon: -122.41942},
			},
		},
		{
			name: "multiple_points",
			points: []Point{
				{Lat: 37.77493, Lon: -122.41942},
				{Lat: 37.77503, Lon: -122.41941},
				{Lat: 37.77513, Lon: -122.41940},
			},
		},
		{
			name: "high_precision_points",
			points: []Point{
				{Lat: 37.774929456789, Lon: -122.419421234567},
				{Lat: 37.785029456789, Lon: -122.409421234567},
			},
		},
		{
			name: "negative_coordinates",
			points: []Point{
				{Lat: -37.77493, Lon: 122.41942},
				{Lat: -35.77493, Lon: 120.41942},
			},
		},
		{
			name: "mixed_coordinates",
			points: []Point{
				{Lat: 37.77493, Lon: -122.41942},
				{Lat: -35.77493, Lon: 120.41942},
				{Lat: 0.0, Lon: 0.0},
			},
		},
		{
			name:   "empty_points",
			points: []Point{},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			encoded := Encode6(tt.points)
			decoded, err := Decode6(encoded)
			if err != nil {
				t.Errorf("Round trip failed on decode: %v", err)
				return
			}

			if len(decoded) != len(tt.points) {
				t.Errorf("Round trip length mismatch: got %d, want %d", len(decoded), len(tt.points))
				return
			}

			for i, point := range decoded {
				original := tt.points[i]
				// Due to precision 6, we expect some rounding
				latDiff := math.Abs(point.Lat - original.Lat)
				lonDiff := math.Abs(point.Lon - original.Lon)

				// Precision 6 means we can have up to 1e-6 error
				maxError := 1e-5 // Being a bit more lenient due to rounding

				if latDiff > maxError || lonDiff > maxError {
					t.Errorf("Round trip precision loss at point %d: "+
						"original {%f, %f}, decoded {%f, %f}, "+
						"lat_diff=%e, lon_diff=%e",
						i, original.Lat, original.Lon, point.Lat, point.Lon,
						latDiff, lonDiff)
				}
			}
		})
	}
}

func TestDecodeSigned(t *testing.T) {
	tests := []struct {
		name     string
		input    int64
		expected int64
	}{
		{name: "positive_even", input: 4, expected: 2},
		{name: "positive_odd", input: 5, expected: -3},
		{name: "zero", input: 0, expected: 0},
		{name: "one", input: 1, expected: -1},
		{name: "large_positive_even", input: 1000, expected: 500},
		{name: "large_positive_odd", input: 1001, expected: -501},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := decodeSigned(tt.input)
			if result != tt.expected {
				t.Errorf("decodeSigned(%d) = %d, want %d", tt.input, result, tt.expected)
			}
		})
	}
}

func TestEncodeSigned(t *testing.T) {
	tests := []struct {
		name     string
		input    int64
		validate func([]byte) bool
	}{
		{
			name:  "zero",
			input: 0,
			validate: func(b []byte) bool {
				return len(b) == 1 && b[0] == 63
			},
		},
		{
			name:  "positive_small",
			input: 1,
			validate: func(b []byte) bool {
				return len(b) > 0 && b[len(b)-1] >= 63
			},
		},
		{
			name:  "negative_small",
			input: -1,
			validate: func(b []byte) bool {
				return len(b) > 0 && b[len(b)-1] >= 63
			},
		},
		{
			name:  "large_positive",
			input: 1000000,
			validate: func(b []byte) bool {
				return len(b) > 0
			},
		},
		{
			name:  "large_negative",
			input: -1000000,
			validate: func(b []byte) bool {
				return len(b) > 0
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := encodeSigned(tt.input)
			if !tt.validate(result) {
				t.Errorf("encodeSigned(%d) validation failed, got: %v", tt.input, result)
			}
		})
	}
}

func TestRound(t *testing.T) {
	tests := []struct {
		name     string
		input    float64
		expected float64
	}{
		{name: "positive_round_up", input: 2.6, expected: 3.0},
		{name: "positive_round_down", input: 2.4, expected: 2.0},
		{name: "positive_half", input: 2.5, expected: 3.0},
		{name: "negative_round_up", input: -2.4, expected: -2.0},
		{name: "negative_round_down", input: -2.6, expected: -3.0},
		{name: "negative_half", input: -2.5, expected: -3.0},
		{name: "zero", input: 0.0, expected: 0.0},
		{name: "positive_zero_point_five", input: 0.5, expected: 1.0},
		{name: "negative_zero_point_five", input: -0.5, expected: -1.0},
		{name: "already_integer", input: 5.0, expected: 5.0},
		{name: "very_small_positive", input: 1e-10, expected: 0.0},
		{name: "very_small_negative", input: -1e-10, expected: 0.0},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := round(tt.input)
			if result != tt.expected {
				t.Errorf("round(%f) = %f, want %f", tt.input, result, tt.expected)
			}
		})
	}
}

func TestSamePoint(t *testing.T) {
	tests := []struct {
		name     string
		a        Point
		b        Point
		expected bool
	}{
		{
			name:     "identical_points",
			a:        Point{Lat: 37.77493, Lon: -122.41942},
			b:        Point{Lat: 37.77493, Lon: -122.41942},
			expected: true,
		},
		{
			name:     "very_close_points",
			a:        Point{Lat: 37.77493, Lon: -122.41942},
			b:        Point{Lat: 37.774930001, Lon: -122.419420001},
			expected: true,
		},
		{
			name:     "different_points",
			a:        Point{Lat: 37.77493, Lon: -122.41942},
			b:        Point{Lat: 37.77494, Lon: -122.41943},
			expected: false,
		},
		{
			name:     "threshold_lat_difference",
			a:        Point{Lat: 37.77493, Lon: -122.41942},
			b:        Point{Lat: 37.77493 + 1e-6, Lon: -122.41942},
			expected: false, // Should be just outside tolerance
		},
		{
			name:     "threshold_lon_difference",
			a:        Point{Lat: 37.77493, Lon: -122.41942},
			b:        Point{Lat: 37.77493, Lon: -122.41942 + 1e-6},
			expected: false, // Should be just outside tolerance
		},
		{
			name:     "zero_coordinates",
			a:        Point{Lat: 0.0, Lon: 0.0},
			b:        Point{Lat: 0.0, Lon: 0.0},
			expected: true,
		},
		{
			name:     "negative_coordinates",
			a:        Point{Lat: -37.77493, Lon: 122.41942},
			b:        Point{Lat: -37.77493, Lon: 122.41942},
			expected: true,
		},
		{
			name:     "mixed_sign_coordinates",
			a:        Point{Lat: 37.77493, Lon: -122.41942},
			b:        Point{Lat: -37.77493, Lon: 122.41942},
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := SamePoint(tt.a, tt.b)
			if result != tt.expected {
				t.Errorf("SamePoint(%v, %v) = %t, want %t", tt.a, tt.b, result, tt.expected)
			}
		})
	}
}

func TestEncodeSigned_RoundTrip(t *testing.T) {
	tests := []int64{
		0, 1, -1, 2, -2, 100, -100, 1000000, -1000000,
	}

	for _, v := range tests {
		t.Run("", func(t *testing.T) {
			encoded := encodeSigned(v)
			// Manually reverse the encoding to test
			var result int64 = 0
			var shift uint = 0

			for _, b := range encoded {
				val := int64(b) - 63
				result |= (val & 0x1f) << shift
				shift += 5
				if val < 0x20 {
					break
				}
			}

			decoded := decodeSigned(result)
			if decoded != v {
				t.Errorf("Round trip failed: original=%d, decoded=%d", v, decoded)
			}
		})
	}
}

// Benchmarks
func BenchmarkEncode6(b *testing.B) {
	points := make([]Point, 1000)
	for i := range points {
		points[i] = Point{
			Lat: 37.77493 + float64(i)*0.0001,
			Lon: -122.41942 + float64(i)*0.0001,
		}
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = Encode6(points)
	}
}

func BenchmarkDecode6(b *testing.B) {
	points := make([]Point, 1000)
	for i := range points {
		points[i] = Point{
			Lat: 37.77493 + float64(i)*0.0001,
			Lon: -122.41942 + float64(i)*0.0001,
		}
	}
	encoded := Encode6(points)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, _ = Decode6(encoded)
	}
}

// TestPrecision6_SpecificValidation tests precision 6 specific behaviors
func TestPrecision6_SpecificValidation(t *testing.T) {
	t.Run("precision_6_vs_5_difference", func(t *testing.T) {
		// Test coordinates that would differ between precision 5 and 6
		testCoords := []struct {
			name  string
			point Point
			// Expected precision 6 encoded result
			expectedP6 string
		}{
			{
				name:       "micro_degree_precision",
				point:      Point{Lat: 37.123456, Lon: -122.987654},
				expectedP6: "_wyxeAjgqqiF",
			},
			{
				name:       "sixth_decimal_place",
				point:      Point{Lat: 40.123456, Lon: -74.123456},
				expectedP6: "_c}okA~jcklC",
			},
		}

		for _, tc := range testCoords {
			t.Run(tc.name, func(t *testing.T) {
				// Test encoding
				encoded := Encode6([]Point{tc.point})
				if encoded != tc.expectedP6 {
					t.Errorf("Encode6() = %s, want %s", encoded, tc.expectedP6)
				}

				// Test decoding
				decoded, err := Decode6(encoded)
				if err != nil {
					t.Errorf("Decode6() error = %v", err)
					return
				}

				if len(decoded) != 1 {
					t.Errorf("Decode6() length = %d, want 1", len(decoded))
					return
				}

				// With precision 6, we should get very close to original coordinates
				const precision6Tolerance = 1e-6
				if math.Abs(decoded[0].Lat-tc.point.Lat) > precision6Tolerance ||
					math.Abs(decoded[0].Lon-tc.point.Lon) > precision6Tolerance {
					t.Errorf("Precision 6 round-trip failed: got {%f, %f}, want {%f, %f}",
						decoded[0].Lat, decoded[0].Lon, tc.point.Lat, tc.point.Lon)
				}
			})
		}
	})

	t.Run("high_precision_coordinates", func(t *testing.T) {
		// Test coordinates with maximum precision
		highPrecisionPoints := []Point{
			{Lat: 37.123456, Lon: -122.987654},
			{Lat: 37.123457, Lon: -122.987653}, // 1 micro-degree difference
			{Lat: 37.123458, Lon: -122.987652}, // 2 micro-degree difference
		}

		encoded := Encode6(highPrecisionPoints)
		decoded, err := Decode6(encoded)

		if err != nil {
			t.Errorf("Decode6() error = %v", err)
			return
		}

		if len(decoded) != len(highPrecisionPoints) {
			t.Errorf("Decode6() length = %d, want %d", len(decoded), len(highPrecisionPoints))
			return
		}

		// Verify each point maintains precision 6 accuracy
		for i, point := range decoded {
			original := highPrecisionPoints[i]
			const microDegreeTolerance = 1e-6 // 1 micro-degree
			if math.Abs(point.Lat-original.Lat) > microDegreeTolerance ||
				math.Abs(point.Lon-original.Lon) > microDegreeTolerance {
				t.Errorf("High precision point %d: got {%f, %f}, want {%f, %f}",
					i, point.Lat, point.Lon, original.Lat, original.Lon)
			}
		}
	})

	t.Run("edge_precision_boundaries", func(t *testing.T) {
		// Test coordinates at the boundaries of precision 6 representation
		boundaryTests := []struct {
			name  string
			point Point
		}{
			{
				name:  "minimum_representable_difference",
				point: Point{Lat: 0.000001, Lon: 0.000001}, // 1 micro-degree
			},
			{
				name:  "maximum_latitude",
				point: Point{Lat: 90.0, Lon: 0.0},
			},
			{
				name:  "minimum_latitude",
				point: Point{Lat: -90.0, Lon: 0.0},
			},
			{
				name:  "maximum_longitude",
				point: Point{Lat: 0.0, Lon: 180.0},
			},
			{
				name:  "minimum_longitude",
				point: Point{Lat: 0.0, Lon: -180.0},
			},
		}

		for _, tc := range boundaryTests {
			t.Run(tc.name, func(t *testing.T) {
				encoded := Encode6([]Point{tc.point})
				decoded, err := Decode6(encoded)

				if err != nil {
					t.Errorf("Decode6() error = %v", err)
					return
				}

				if len(decoded) != 1 {
					t.Errorf("Decode6() length = %d, want 1", len(decoded))
					return
				}

				// For boundary values, allow slightly larger tolerance due to rounding
				const boundaryTolerance = 1e-5
				if math.Abs(decoded[0].Lat-tc.point.Lat) > boundaryTolerance ||
					math.Abs(decoded[0].Lon-tc.point.Lon) > boundaryTolerance {
					t.Errorf("Boundary test failed: got {%f, %f}, want {%f, %f}",
						decoded[0].Lat, decoded[0].Lon, tc.point.Lat, tc.point.Lon)
				}
			})
		}
	})
}
