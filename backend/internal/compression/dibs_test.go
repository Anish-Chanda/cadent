package compression

import (
	"fmt"
	"math"
	"testing"
)

// Test data generators
func generateLinearData(start, step float64, count int) []float64 {
	data := make([]float64, count)
	for i := 0; i < count; i++ {
		data[i] = start + step*float64(i)
	}
	return data
}

func generateSineWave(amplitude, frequency float64, samples int) []float64 {
	data := make([]float64, samples)
	for i := 0; i < samples; i++ {
		t := float64(i) / float64(samples) * 2 * math.Pi
		data[i] = amplitude * math.Sin(frequency*t)
	}
	return data
}

func generateRandomWalk(start, maxStep float64, samples int) []float64 {
	data := make([]float64, samples)
	data[0] = start
	for i := 1; i < samples; i++ {
		step := (math.Sin(float64(i)*0.1) + math.Cos(float64(i)*0.3)) * maxStep * 0.5
		data[i] = data[i-1] + step
	}
	return data
}

func generateConstantData(value float64, count int) []float64 {
	data := make([]float64, count)
	for i := 0; i < count; i++ {
		data[i] = value
	}
	return data
}

func generateElevationProfile() []float64 {
	// Simulate realistic elevation data with various patterns
	return []float64{
		100.5, 100.7, 101.2, 102.1, 103.5, 105.2, 106.8, 108.1, 109.5, 110.2,
		112.1, 114.5, 116.8, 118.2, 119.1, 120.5, 121.8, 122.2, 122.1, 121.8,
		121.2, 120.1, 118.5, 116.2, 114.1, 112.5, 111.8, 110.2, 108.5, 107.1,
		105.8, 104.2, 103.1, 102.5, 101.8, 101.2, 100.9, 100.5, 100.2, 100.1,
		100.5, 101.2, 102.8, 104.5, 106.2, 108.1, 110.5, 112.8, 114.2, 115.1,
	}
}

// Helper function to check if two float arrays are equal within precision
func floatsEqualWithPrecision(a, b []float64, precision int) bool {
	if len(a) != len(b) {
		return false
	}

	tolerance := math.Pow10(-precision)
	for i := 0; i < len(a); i++ {
		if math.Abs(a[i]-b[i]) > tolerance {
			return false
		}
	}
	return true
}

// Test basic compression and decompression
func TestBasicCompressionDecompression(t *testing.T) {
	testCases := []struct {
		name string
		data []float64
		opts CompressOptions
	}{
		{
			name: "small linear sequence",
			data: generateLinearData(0, 1, 10),
			opts: DefaultCompressOptions(),
		},
		{
			name: "constant values",
			data: generateConstantData(42.5, 20),
			opts: DefaultCompressOptions(),
		},
		{
			name: "elevation profile",
			data: generateElevationProfile(),
			opts: CompressOptions{DecimalPlaces: 1, BlockLog2: 4, EnableCRC: true},
		},
		{
			name: "sine wave",
			data: generateSineWave(10.0, 2.0, 100),
			opts: CompressOptions{DecimalPlaces: 3, BlockLog2: 5, EnableCRC: true},
		},
		{
			name: "random walk",
			data: generateRandomWalk(1000.0, 5.0, 200),
			opts: CompressOptions{DecimalPlaces: 2, BlockLog2: 6, EnableCRC: false},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			// Compress
			compressed, err := Compress(tc.data, tc.opts)
			if err != nil {
				t.Fatalf("Compression failed: %v", err)
			}

			if len(compressed) == 0 {
				t.Fatal("Compressed data is empty")
			}

			// Decompress
			decompressed, err := Decompress(compressed)
			if err != nil {
				t.Fatalf("Decompression failed: %v", err)
			}

			// Verify lossless compression (within precision)
			if !floatsEqualWithPrecision(tc.data, decompressed, tc.opts.DecimalPlaces) {
				t.Errorf("Data mismatch after compression/decompression")
				t.Logf("Original length: %d, Decompressed length: %d", len(tc.data), len(decompressed))
				for i := 0; i < len(tc.data) && i < 10; i++ {
					t.Logf("  [%d] %.6f -> %.6f (diff: %.6f)", i, tc.data[i], decompressed[i], tc.data[i]-decompressed[i])
				}
			}

			// Check compression ratio
			originalSize := len(tc.data) * 8 // 8 bytes per float64
			compressionRatio := float64(len(compressed)) / float64(originalSize)
			t.Logf("Compression ratio: %.2f%% (original: %d bytes, compressed: %d bytes)",
				compressionRatio*100, originalSize, len(compressed))
		})
	}
}

// Test edge cases
func TestEdgeCases(t *testing.T) {
	t.Run("empty data", func(t *testing.T) {
		_, err := Compress([]float64{}, DefaultCompressOptions())
		if err == nil {
			t.Error("Expected error for empty data")
		}
	})

	t.Run("single value", func(t *testing.T) {
		data := []float64{42.5}
		compressed, err := Compress(data, DefaultCompressOptions())
		if err != nil {
			t.Fatalf("Failed to compress single value: %v", err)
		}

		decompressed, err := Decompress(compressed)
		if err != nil {
			t.Fatalf("Failed to decompress single value: %v", err)
		}

		if !floatsEqualWithPrecision(data, decompressed, 2) {
			t.Errorf("Single value mismatch: %.6f -> %.6f", data[0], decompressed[0])
		}
	})

	t.Run("two values", func(t *testing.T) {
		data := []float64{10.5, 20.7}
		compressed, err := Compress(data, DefaultCompressOptions())
		if err != nil {
			t.Fatalf("Failed to compress two values: %v", err)
		}

		decompressed, err := Decompress(compressed)
		if err != nil {
			t.Fatalf("Failed to decompress two values: %v", err)
		}

		if !floatsEqualWithPrecision(data, decompressed, 2) {
			t.Errorf("Two values mismatch")
		}
	})
}

// Test different precision levels
func TestPrecisionLevels(t *testing.T) {
	data := []float64{1.23456789, 2.34567890, 3.45678901, 4.56789012}

	for precision := 0; precision <= 4; precision++ {
		t.Run(fmt.Sprintf("precision_%d", precision), func(t *testing.T) {
			opts := CompressOptions{
				DecimalPlaces: precision,
				BlockLog2:     4,
				EnableCRC:     true,
			}

			compressed, err := Compress(data, opts)
			if err != nil {
				t.Fatalf("Compression failed: %v", err)
			}

			decompressed, err := Decompress(compressed)
			if err != nil {
				t.Fatalf("Decompression failed: %v", err)
			}

			if !floatsEqualWithPrecision(data, decompressed, precision) {
				t.Errorf("Precision %d test failed", precision)
				for i := 0; i < len(data); i++ {
					t.Logf("  [%d] %.8f -> %.8f", i, data[i], decompressed[i])
				}
			}
		})
	}
}

// Test different block sizes
func TestBlockSizes(t *testing.T) {
	data := generateLinearData(0, 0.1, 1000) // 1000 samples

	for blockLog2 := 3; blockLog2 <= 8; blockLog2++ {
		t.Run(fmt.Sprintf("block_size_%d", 1<<blockLog2), func(t *testing.T) {
			opts := CompressOptions{
				DecimalPlaces: 2,
				BlockLog2:     blockLog2,
				EnableCRC:     true,
			}

			compressed, err := Compress(data, opts)
			if err != nil {
				t.Fatalf("Compression failed: %v", err)
			}

			decompressed, err := Decompress(compressed)
			if err != nil {
				t.Fatalf("Decompression failed: %v", err)
			}

			if !floatsEqualWithPrecision(data, decompressed, opts.DecimalPlaces) {
				t.Errorf("Block size %d test failed", 1<<blockLog2)
			}
		})
	}
}

// Test compression efficiency on different data patterns
func TestCompressionEfficiency(t *testing.T) {
	testCases := []struct {
		name string
		data []float64
	}{
		{"constant", generateConstantData(100.0, 1000)},
		{"linear", generateLinearData(0, 1, 1000)},
		{"sine_smooth", generateSineWave(100, 1, 1000)},
		{"sine_complex", generateSineWave(100, 10, 1000)},
		{"random_walk", generateRandomWalk(1000, 2, 1000)},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			opts := DefaultCompressOptions()
			compressed, err := Compress(tc.data, opts)
			if err != nil {
				t.Fatalf("Compression failed: %v", err)
			}

			originalSize := len(tc.data) * 8
			ratio := float64(len(compressed)) / float64(originalSize)

			t.Logf("Pattern %s: %.1f%% compression ratio (%d -> %d bytes)",
				tc.name, ratio*100, originalSize, len(compressed))

			// Verify correctness
			decompressed, err := Decompress(compressed)
			if err != nil {
				t.Fatalf("Decompression failed: %v", err)
			}

			if !floatsEqualWithPrecision(tc.data, decompressed, opts.DecimalPlaces) {
				t.Errorf("Data corruption in %s pattern", tc.name)
			}
		})
	}
}

// Test CRC validation
func TestCRCValidation(t *testing.T) {
	data := generateLinearData(0, 1, 100)
	opts := CompressOptions{DecimalPlaces: 2, BlockLog2: 5, EnableCRC: true}

	compressed, err := Compress(data, opts)
	if err != nil {
		t.Fatalf("Compression failed: %v", err)
	}

	// Corrupt the data and verify CRC catches it
	if len(compressed) > 50 {
		compressed[50] ^= 0xFF // Flip all bits in byte 50

		_, err = Decompress(compressed)
		if err == nil {
			t.Error("Expected CRC error for corrupted data")
		}
	}
}

// Benchmark basic compression
func BenchmarkCompression(b *testing.B) {
	data := generateSineWave(100, 5, 1000)
	opts := DefaultCompressOptions()

	b.ResetTimer()
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			_, err := Compress(data, opts)
			if err != nil {
				b.Fatalf("Compression failed: %v", err)
			}
		}
	})

	// Calculate and report throughput
	dataSize := len(data) * 8 // 8 bytes per float64
	totalMB := float64(b.N*dataSize) / (1024 * 1024)
	mbPerSec := totalMB / b.Elapsed().Seconds()
	b.ReportMetric(mbPerSec, "MB/s")
}

// Benchmark decompression
func BenchmarkDecompression(b *testing.B) {
	data := generateSineWave(100, 5, 1000)
	opts := DefaultCompressOptions()

	compressed, err := Compress(data, opts)
	if err != nil {
		b.Fatalf("Setup compression failed: %v", err)
	}

	b.ResetTimer()
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			_, err := Decompress(compressed)
			if err != nil {
				b.Fatalf("Decompression failed: %v", err)
			}
		}
	})

	// Calculate and report throughput
	dataSize := len(data) * 8 // 8 bytes per float64
	totalMB := float64(b.N*dataSize) / (1024 * 1024)
	mbPerSec := totalMB / b.Elapsed().Seconds()
	b.ReportMetric(mbPerSec, "MB/s")
}

// Benchmark compression with different data sizes
func BenchmarkCompressionSizes(b *testing.B) {
	sizes := []int{100, 1000, 10000}

	for _, size := range sizes {
		b.Run(fmt.Sprintf("size_%d", size), func(b *testing.B) {
			data := generateSineWave(100, 5, size)
			opts := DefaultCompressOptions()

			b.ResetTimer()
			for i := 0; i < b.N; i++ {
				_, err := Compress(data, opts)
				if err != nil {
					b.Fatalf("Compression failed: %v", err)
				}
			}

			// Calculate and report throughput
			dataSize := len(data) * 8 // 8 bytes per float64
			totalMB := float64(b.N*dataSize) / (1024 * 1024)
			mbPerSec := totalMB / b.Elapsed().Seconds()
			b.ReportMetric(mbPerSec, "MB/s")
		})
	}
}
