package compression

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"hash/crc32"
	"math"
)

// NOTE: This is highly experimental, not production-ready code for DIBS compression/decompression. This may or maynot even be
// more effecient than other compression algorithms, but innitial benchmarks look promising for our specific use case
// often achieving 80-90% compression ratios, and 1.2GB/s decompression speeds, but I have seen that the hex strings
// still have some redundancy that could be further compressed with a general-purpose algorithm like zstd/blosc.
// Also note this is not a completly lossless compression, as we quantize float values to fixed-point integers based on
// specified decimal places we actually ever use.

// DIBS compression constants
const (
	Magic            = "DSEG"
	Version          = 1
	DefaultBlockLog2 = 8 // 256 samples per block
	MaxBlockSize     = 512

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

// Compress compresses a float64 array using DIBS algorithm
func Compress(data []float64, options CompressOptions) ([]byte, error) {
	if len(data) == 0 {
		return nil, fmt.Errorf("input data is empty")
	}

	// Step 1: Quantize floats to fixed-precision integers
	scale := int32(math.Pow10(options.DecimalPlaces))
	quantized := make([]int32, len(data))
	for i, val := range data {
		quantized[i] = int32(math.Round(val * float64(scale)))
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

	// Step 3: Compress data into blocks
	blockSize := 1 << options.BlockLog2
	var compressedBlocks [][]byte

	for offset := 0; offset < len(quantized); offset += blockSize {
		end := offset + blockSize
		if end > len(quantized) {
			end = len(quantized)
		}

		block := quantized[offset:end]
		compressedBlock, err := compressBlock(block)
		if err != nil {
			return nil, fmt.Errorf("failed to compress block at offset %d: %w", offset, err)
		}
		compressedBlocks = append(compressedBlocks, compressedBlock)
	}

	// Step 4: Build final output
	var buf bytes.Buffer

	// Write segment header (will update CRC later if enabled)
	if err := binary.Write(&buf, binary.LittleEndian, header); err != nil {
		return nil, fmt.Errorf("failed to write header: %w", err)
	}

	// Write compressed blocks
	bodyStart := buf.Len()
	for _, block := range compressedBlocks {
		buf.Write(block)
	}

	// Update CRC if enabled
	if options.EnableCRC {
		result := buf.Bytes()
		body := result[bodyStart:]
		crc := crc32.Checksum(body, crc32.MakeTable(crc32.Castagnoli))

		// Update CRC field in header
		binary.LittleEndian.PutUint32(result[28:32], crc) // CRC32C field offset
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
