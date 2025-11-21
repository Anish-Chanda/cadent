package compression

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"math/bits"
)

// ZigZag encoding/decoding functions
// Maps signed integers to unsigned: ..., -2, -1, 0, 1, 2, ... → ..., 3, 1, 0, 2, 4, ...

// zigZagEncode encodes a signed integer as an unsigned integer using ZigZag encoding
func zigZagEncode(n int32) uint32 {
	return uint32((n << 1) ^ (n >> 31))
}

// zigZagDecode decodes an unsigned integer back to a signed integer
func zigZagDecode(n uint32) int32 {
	return int32((n >> 1) ^ (-(n & 1)))
}

// Predictor functions

// predictDelta1 applies Delta-1 predictor (difference to previous sample)
func predictDelta1(data []int32) []int32 {
	if len(data) <= 1 {
		return []int32{}
	}

	residuals := make([]int32, len(data)-1)
	for i := 1; i < len(data); i++ {
		residuals[i-1] = data[i] - data[i-1]
	}
	return residuals
}

// predictDelta2 applies Delta-2 predictor (difference to linear extrapolation)
func predictDelta2(data []int32) []int32 {
	if len(data) <= 2 {
		return []int32{}
	}

	residuals := make([]int32, len(data)-2)
	for i := 2; i < len(data); i++ {
		predicted := 2*data[i-1] - data[i-2]
		residuals[i-2] = data[i] - predicted
	}
	return residuals
}

// reconstructDelta1 reconstructs data from Delta-1 residuals
func reconstructDelta1(seed int32, residuals []int32) []int32 {
	result := make([]int32, len(residuals)+1)
	result[0] = seed

	for i, residual := range residuals {
		result[i+1] = result[i] + residual
	}
	return result
}

// reconstructDelta2 reconstructs data from Delta-2 residuals
func reconstructDelta2(seed1, seed2 int32, residuals []int32) []int32 {
	result := make([]int32, len(residuals)+2)
	result[0] = seed1
	result[1] = seed2

	for i, residual := range residuals {
		predicted := 2*result[i+1] - result[i]
		result[i+2] = predicted + residual
	}
	return result
}

// Bit manipulation functions

// bitLength returns the number of bits needed to represent the unsigned integer
func bitLength(n uint32) int {
	if n == 0 {
		return 0
	}
	return bits.Len32(n)
}

// maxAbsValue finds the maximum absolute value in a slice of signed integers
func maxAbsValue(data []int32) uint32 {
	var maxAbs uint32 = 0
	for _, val := range data {
		abs := uint32(val)
		if val < 0 {
			abs = uint32(-val)
		}
		if abs > maxAbs {
			maxAbs = abs
		}
	}
	return maxAbs
}

// Bit packing functions

// packBits packs unsigned integers into a byte array with specified bit width
func packBits(values []uint32, bitWidth int) []byte {
	if bitWidth == 0 || len(values) == 0 {
		return []byte{}
	}

	totalBits := len(values) * bitWidth
	totalBytes := (totalBits + 7) / 8 // Round up to nearest byte
	packed := make([]byte, totalBytes)

	bitPos := 0
	for _, val := range values {
		// Pack LSB-first, back-to-back
		for bit := 0; bit < bitWidth; bit++ {
			if (val & (1 << bit)) != 0 {
				byteIdx := bitPos / 8
				bitIdx := bitPos % 8
				packed[byteIdx] |= 1 << bitIdx
			}
			bitPos++
		}
	}

	return packed
}

// unpackBits unpacks unsigned integers from a byte array with specified bit width
func unpackBits(packed []byte, count int, bitWidth int) []uint32 {
	if bitWidth == 0 || count == 0 {
		return make([]uint32, count) // Return zeros
	}

	values := make([]uint32, count)
	bitPos := 0

	for i := 0; i < count; i++ {
		var val uint32 = 0
		for bit := 0; bit < bitWidth; bit++ {
			byteIdx := bitPos / 8
			bitIdx := bitPos % 8

			if byteIdx < len(packed) && (packed[byteIdx]&(1<<bitIdx)) != 0 {
				val |= 1 << bit
			}
			bitPos++
		}
		values[i] = val
	}

	return values
}

// Block compression/decompression

// compressBlock compresses a single block of integers
func compressBlock(data []int32) ([]byte, error) {
	if len(data) == 0 {
		return nil, fmt.Errorf("empty block")
	}

	// Try both predictors and pick the best one
	delta1Residuals := predictDelta1(data)
	delta2Residuals := predictDelta2(data)

	var predictor Predictor
	var residuals []int32
	var seeds []int32

	// Evaluate which predictor gives smaller bit width
	if len(delta1Residuals) == 0 {
		predictor = PredictorDelta1
		residuals = []int32{}
		seeds = []int32{data[0]}
	} else if len(delta2Residuals) == 0 {
		predictor = PredictorDelta1
		residuals = delta1Residuals
		seeds = []int32{data[0]}
	} else {
		// Compare maximum absolute values
		max1 := maxAbsValue(delta1Residuals)
		max2 := maxAbsValue(delta2Residuals)

		if bitLength(max1) <= bitLength(max2) {
			predictor = PredictorDelta1
			residuals = delta1Residuals
			seeds = []int32{data[0]}
		} else {
			predictor = PredictorDelta2
			residuals = delta2Residuals
			seeds = []int32{data[0], data[1]}
		}
	}

	// Apply ZigZag encoding to residuals
	zigzagResiduals := make([]uint32, len(residuals))
	for i, r := range residuals {
		zigzagResiduals[i] = zigZagEncode(r)
	}

	// Find bit width
	maxZigzag := uint32(0)
	for _, val := range zigzagResiduals {
		if val > maxZigzag {
			maxZigzag = val
		}
	}
	bitWidth := bitLength(maxZigzag)

	// Create block header
	header := BlockHeader{
		Tag:       0x42424242, // "BBBB" as block tag
		Predictor: uint32(predictor),
		BitWidth:  uint32(bitWidth),
		NSamples:  uint32(len(data)),
		Seeds:     seeds,
	}

	// Pack data
	var buf bytes.Buffer

	// Write header
	if err := binary.Write(&buf, binary.LittleEndian, header.Tag); err != nil {
		return nil, err
	}
	if err := binary.Write(&buf, binary.LittleEndian, header.Predictor); err != nil {
		return nil, err
	}
	if err := binary.Write(&buf, binary.LittleEndian, header.BitWidth); err != nil {
		return nil, err
	}
	if err := binary.Write(&buf, binary.LittleEndian, header.NSamples); err != nil {
		return nil, err
	}

	// Write seeds
	for _, seed := range seeds {
		if err := binary.Write(&buf, binary.LittleEndian, seed); err != nil {
			return nil, err
		}
	}

	// Pack and write residuals
	if bitWidth > 0 {
		packedResiduals := packBits(zigzagResiduals, bitWidth)
		buf.Write(packedResiduals)
	}

	return buf.Bytes(), nil
}

// decompressBlock decompresses a single block, returns data and bytes consumed
func decompressBlock(compressed []byte, expectedSamples int) ([]int32, int, error) {
	if len(compressed) < 16 { // Minimum header size
		return nil, 0, fmt.Errorf("compressed block too short")
	}

	buf := bytes.NewReader(compressed)
	var header BlockHeader

	// Read basic header fields
	if err := binary.Read(buf, binary.LittleEndian, &header.Tag); err != nil {
		return nil, 0, err
	}
	if err := binary.Read(buf, binary.LittleEndian, &header.Predictor); err != nil {
		return nil, 0, err
	}
	if err := binary.Read(buf, binary.LittleEndian, &header.BitWidth); err != nil {
		return nil, 0, err
	}
	if err := binary.Read(buf, binary.LittleEndian, &header.NSamples); err != nil {
		return nil, 0, err
	}

	// Validate
	if header.NSamples != uint32(expectedSamples) {
		return nil, 0, fmt.Errorf("sample count mismatch: expected %d, got %d", expectedSamples, header.NSamples)
	}

	predictor := Predictor(header.Predictor)

	// Read seeds
	var seeds []int32
	seedCount := 1
	if predictor == PredictorDelta2 {
		seedCount = 2
	}

	for i := 0; i < seedCount; i++ {
		var seed int32
		if err := binary.Read(buf, binary.LittleEndian, &seed); err != nil {
			return nil, 0, err
		}
		seeds = append(seeds, seed)
	}

	headerSize := 16 + seedCount*4 // Basic header + seeds

	// Read and unpack residuals
	var residuals []int32
	if predictor == PredictorDelta1 && len(seeds) >= 1 {
		if int(header.NSamples) > 1 {
			residualCount := int(header.NSamples) - 1
			if header.BitWidth > 0 {
				payloadSize := (residualCount*int(header.BitWidth) + 7) / 8
				if len(compressed) < headerSize+payloadSize {
					return nil, 0, fmt.Errorf("insufficient data for residuals")
				}

				packedResiduals := compressed[headerSize : headerSize+payloadSize]
				zigzagResiduals := unpackBits(packedResiduals, residualCount, int(header.BitWidth))

				residuals = make([]int32, residualCount)
				for i, zz := range zigzagResiduals {
					residuals[i] = zigZagDecode(zz)
				}
			} else {
				// BitWidth = 0, all residuals are zero
				residuals = make([]int32, residualCount)
			}
		}

		// Reconstruct using Delta1
		result := reconstructDelta1(seeds[0], residuals)
		consumedBytes := headerSize
		if header.BitWidth > 0 && len(residuals) > 0 {
			consumedBytes += (len(residuals)*int(header.BitWidth) + 7) / 8
		}
		return result, consumedBytes, nil

	} else if predictor == PredictorDelta2 && len(seeds) >= 2 {
		if int(header.NSamples) > 2 {
			residualCount := int(header.NSamples) - 2
			if header.BitWidth > 0 {
				payloadSize := (residualCount*int(header.BitWidth) + 7) / 8
				if len(compressed) < headerSize+payloadSize {
					return nil, 0, fmt.Errorf("insufficient data for residuals")
				}

				packedResiduals := compressed[headerSize : headerSize+payloadSize]
				zigzagResiduals := unpackBits(packedResiduals, residualCount, int(header.BitWidth))

				residuals = make([]int32, residualCount)
				for i, zz := range zigzagResiduals {
					residuals[i] = zigZagDecode(zz)
				}
			} else {
				// BitWidth = 0, all residuals are zero
				residuals = make([]int32, residualCount)
			}
		}

		// Reconstruct using Delta2
		result := reconstructDelta2(seeds[0], seeds[1], residuals)
		consumedBytes := headerSize
		if header.BitWidth > 0 && len(residuals) > 0 {
			consumedBytes += (len(residuals)*int(header.BitWidth) + 7) / 8
		}
		return result, consumedBytes, nil
	}

	return nil, 0, fmt.Errorf("invalid predictor or insufficient seeds")
}
