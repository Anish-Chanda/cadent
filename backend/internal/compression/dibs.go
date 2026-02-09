package compression

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"hash/crc32"
	"math"
)

// DIBS (Delta Integer Bit Streaming) is a domain-specific compression algorithm optimized for time-series float data,
// particularly GPS tracking and activity data. The algorithm quantizes floating point values to fixed-point integers
// at a configurable precision (0-6 decimal places), then applies adaptive delta prediction (Delta-1 for volatile data,
// Delta-2 for smooth gradients). Residuals are ZigZag encoded and packed with variable bit-widths, with fast paths for
// common 8/16/32-bit alignments. The result is excellent compression ratios (typically 1-20% of original size depending
// on data smoothness) at high speed (1.7-1.9 GB/s). This is not completely lossless compression, as we quantize float
// values to fixed-point integers based on the specified decimal places we ACTUALLY ever use/need. The algorithm works best for
// GPS coordinates (poly6 precision at 6 decimals gives ~11cm accuracy), elevation profiles where smooth gradients
// compress to 1-5%, and speed/pace data. Performance degrades with sudden spikes or volatility in the data.

// DIBS compression constants
const (
	Magic            = "DIBS" // File format identifier
	Version          = 1
	DefaultBlockLog2 = 8  // 256 samples per block
	MaxBlockLog2     = 16 // 65536 samples max per block

	// MaxDecimalPlaces is the maximum supported decimal precision.
	// Limited to 6 to match poly6 GPS encoding standard (~11cm precision).
	// Higher precision provides no meaningful information for GPS/elevation data
	// and risks int32 overflow during quantization.
	MaxDecimalPlaces = 6

	// Flags
	FlagFromFixedPoint = 1 << 0
)

// Predictor types
type Predictor int

const (
	PredictorDelta1 Predictor = 1 // Δ¹: difference to previous sample
	PredictorDelta2 Predictor = 2 // Δ²: difference to linear extrapolation
)

// SegmentHeader represents the main segment header
type SegmentHeader struct {
	Magic     [4]byte // "DSEG"
	Version   uint32  // Format version
	Flags     uint32  // Bit flags
	BlockLog2 uint32  // log2 of block size
	NSamples  uint32  // Total number of samples
	ScaleNum  int32   // Scale numerator for float conversion
	ScaleDen  int32   // Scale denominator for float conversion
	CRC32C    uint32  // CRC-32C of following bytes (optional)
}

// BlockHeader represents a block header
type BlockHeader struct {
	Tag       uint32  // Block type tag
	Predictor uint32  // Which predictor was used (1=Delta1, 2=Delta2)
	BitWidth  uint32  // Bit width for residuals
	NSamples  uint32  // Number of samples in this block
	Seeds     []int32 // Seed values (1 for Delta1, 2 for Delta2)
}

// CompressOptions holds compression parameters
type CompressOptions struct {
	DecimalPlaces int  // Number of decimal places to preserve
	BlockLog2     int  // log2 of block size (e.g., 8 = 256 samples)
	EnableCRC     bool // Whether to include CRC-32C
}

// DefaultCompressOptions returns sensible defaults
func DefaultCompressOptions() CompressOptions {
	return CompressOptions{
		DecimalPlaces: 2,
		BlockLog2:     DefaultBlockLog2,
		EnableCRC:     true,
	}
}

// validateOptions validates compression options
func validateOptions(options *CompressOptions) error {
	if options.DecimalPlaces < 0 || options.DecimalPlaces > MaxDecimalPlaces {
		return fmt.Errorf("DecimalPlaces must be 0-%d, got %d", MaxDecimalPlaces, options.DecimalPlaces)
	}

	if options.BlockLog2 < 2 || options.BlockLog2 > MaxBlockLog2 {
		return fmt.Errorf("BlockLog2 must be 2-%d, got %d", MaxBlockLog2, options.BlockLog2)
	}

	return nil
}

// Compress compresses a float64 array using DIBS algorithm
func Compress(data []float64, options CompressOptions) ([]byte, error) {
	if len(data) == 0 {
		return nil, fmt.Errorf("input data is empty")
	}

	// Validate options
	if err := validateOptions(&options); err != nil {
		return nil, err
	}

	// Step 1: Quantize floats to fixed-precision integers
	scale := int32(math.Pow10(options.DecimalPlaces))
	quantized := make([]int32, len(data))
	for i, val := range data {
		scaled := val * float64(scale)

		// Check for overflow - this indicates invalid input data
		if scaled > math.MaxInt32 {
			return nil, fmt.Errorf("value %.6f at index %d overflows int32 max with %d decimal places (scaled: %.0f)",
				val, i, options.DecimalPlaces, scaled)
		} else if scaled < math.MinInt32 {
			return nil, fmt.Errorf("value %.6f at index %d underflows int32 min with %d decimal places (scaled: %.0f)",
				val, i, options.DecimalPlaces, scaled)
		} else {
			quantized[i] = int32(math.Round(scaled))
		}
	}

	// Step 2: Create segment header
	header := SegmentHeader{
		Version:   Version,
		Flags:     FlagFromFixedPoint,
		BlockLog2: uint32(options.BlockLog2),
		NSamples:  uint32(len(data)),
		ScaleNum:  1,
		ScaleDen:  scale,
	}
	copy(header.Magic[:], Magic)

	// Step 3: Build output buffer
	var buf bytes.Buffer

	// Write segment header (will update CRC later if enabled)
	if err := binary.Write(&buf, binary.LittleEndian, header); err != nil {
		return nil, fmt.Errorf("failed to write header: %w", err)
	}

	// Mark where body starts (for CRC calculation)
	bodyStart := buf.Len()

	// Step 4: Compress blocks directly into buffer
	blockSize := 1 << options.BlockLog2
	for offset := 0; offset < len(quantized); offset += blockSize {
		end := offset + blockSize
		if end > len(quantized) {
			end = len(quantized)
		}

		block := quantized[offset:end]
		if err := compressBlock(block, &buf); err != nil {
			return nil, fmt.Errorf("failed to compress block at offset %d: %w", offset, err)
		}
	}

	// Step 5: Update CRC if enabled
	if options.EnableCRC {
		result := buf.Bytes()
		body := result[bodyStart:]
		crc := crc32.Checksum(body, crc32.MakeTable(crc32.Castagnoli))

		// Update CRC field in header at its known position
		// CRC32C is the last field in SegmentHeader (uint32 = 4 bytes)
		headerSize := binary.Size(SegmentHeader{})
		crcOffset := headerSize - 4
		binary.LittleEndian.PutUint32(result[crcOffset:crcOffset+4], crc)
	}

	return buf.Bytes(), nil
}

// Decompress decompresses DIBS-compressed data back to float64 array
func Decompress(compressed []byte) ([]float64, error) {
	if len(compressed) < int(binary.Size(SegmentHeader{})) {
		return nil, fmt.Errorf("compressed data too short")
	}

	// Read segment header
	var header SegmentHeader
	buf := bytes.NewReader(compressed)
	if err := binary.Read(buf, binary.LittleEndian, &header); err != nil {
		return nil, fmt.Errorf("failed to read header: %w", err)
	}

	// Validate header
	if string(header.Magic[:]) != Magic {
		return nil, fmt.Errorf("invalid magic: %s", string(header.Magic[:]))
	}
	if header.Version != Version {
		return nil, fmt.Errorf("unsupported version: %d", header.Version)
	}

	// Verify CRC if present
	headerSize := binary.Size(header)
	if header.CRC32C != 0 {
		body := compressed[headerSize:]
		expectedCRC := crc32.Checksum(body, crc32.MakeTable(crc32.Castagnoli))
		if header.CRC32C != expectedCRC {
			return nil, fmt.Errorf("CRC mismatch: expected %d, got %d", expectedCRC, header.CRC32C)
		}
	}

	// Decompress blocks
	blockSize := 1 << header.BlockLog2
	quantized := make([]int32, header.NSamples)

	remaining := compressed[headerSize:]
	offset := 0

	for offset < int(header.NSamples) {
		end := offset + blockSize
		if end > int(header.NSamples) {
			end = int(header.NSamples)
		}

		blockData, consumed, err := decompressBlock(remaining, end-offset)
		if err != nil {
			return nil, fmt.Errorf("failed to decompress block at offset %d: %w", offset, err)
		}

		copy(quantized[offset:end], blockData)
		remaining = remaining[consumed:]
		offset = end
	}

	// Convert back to floats
	result := make([]float64, len(quantized))
	scale := float64(header.ScaleDen) / float64(header.ScaleNum)
	for i, val := range quantized {
		result[i] = float64(val) / scale
	}

	return result, nil
}
