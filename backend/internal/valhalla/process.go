package valhalla

import (
	"math"
)

// ElevationChange holds detailed elevation metrics from a route
type ElevationChange struct {
	GainMeters float64 `json:"gain_meters"` // Total elevation gain in meters
	LossMeters float64 `json:"loss_meters"` // Total elevation loss in meters
	MaxHeight  float64 `json:"max_height"`  // Maximum elevation in meters
	MinHeight  float64 `json:"min_height"`  // Minimum elevation in meters
}

// CalculateElevationChange calculates detailed elevation metrics from height response data
// Uses a threshold-based approach for gain/loss calculation by accumulating
// continuous uphill/downhill segments and only adding them if they meet the threshold
func CalculateElevationChange(heightResp *HeightResponse, segmentThreshold float64) ElevationChange {
	result := ElevationChange{
		GainMeters: 0.0,
		LossMeters: 0.0,
		MaxHeight:  math.Inf(-1), // Start with negative infinity
		MinHeight:  math.Inf(1),  // Start with positive infinity
	}

	if heightResp == nil || len(heightResp.Height) == 0 {
		// Handle completely empty case
		result.MaxHeight = 0
		result.MinHeight = 0
		return result
	}

	// Special handling for single point case
	if len(heightResp.Height) == 1 {
		if heightResp.Height[0] != nil {
			height := *heightResp.Height[0]
			result.MaxHeight = height
			result.MinHeight = height
		} else {
			result.MaxHeight = 0
			result.MinHeight = 0
		}
		return result
	}

	// Filter valid heights and handle null values (but keep negative elevations for below sea level)
	validHeights := make([]float64, 0, len(heightResp.Height))
	for _, h := range heightResp.Height {
		if h == nil {
			// Skip null/invalid heights - these represent invalid GPS points or data gaps
			continue
		}
		height := *h
		validHeights = append(validHeights, height)

		// Track min/max heights (properly handle negative elevations for places below sea level)
		if height > result.MaxHeight {
			result.MaxHeight = height
		}
		if height < result.MinHeight {
			result.MinHeight = height
		}
	}

	if len(validHeights) < 2 {
		if len(validHeights) == 0 {
			// No valid heights at all - set to 0
			result.MaxHeight = 0
			result.MinHeight = 0
		}
		return result
	}

	// Threshold-based segment calculation for accurate elevation gain/loss
	var currentUphill float64   // Accumulator for current continuous uphill segment
	var currentDownhill float64 // Accumulator for current continuous downhill segment
	inUphillSegment := false    // Track if currently accumulating uphill
	inDownhillSegment := false  // Track if currently accumulating downhill

	for i := 1; i < len(validHeights); i++ {
		heightChange := validHeights[i] - validHeights[i-1]

		if heightChange > 0 {
			// Moving uphill
			if !inUphillSegment {
				// Starting new uphill segment - finalize any previous downhill segment
				if inDownhillSegment && currentDownhill >= segmentThreshold {
					result.LossMeters += currentDownhill
				}
				// Reset for new uphill segment
				inUphillSegment = true
				inDownhillSegment = false
				currentUphill = 0
				currentDownhill = 0
			}
			currentUphill += heightChange

		} else if heightChange < 0 {
			// Moving downhill
			if !inDownhillSegment {
				// Starting new downhill segment - finalize any previous uphill segment
				if inUphillSegment && currentUphill >= segmentThreshold {
					result.GainMeters += currentUphill
				}
				// Reset for new downhill segment
				inDownhillSegment = true
				inUphillSegment = false
				currentUphill = 0
				currentDownhill = 0
			}
			currentDownhill += math.Abs(heightChange) // Store as positive value
		}
		// If heightChange == 0, continue current segment without changes
	}

	// Finalize the last segment
	if inUphillSegment && currentUphill >= segmentThreshold {
		result.GainMeters += currentUphill
	} else if inDownhillSegment && currentDownhill >= segmentThreshold {
		result.LossMeters += currentDownhill
	}

	// Handle edge case where no valid heights were found
	if math.IsInf(result.MaxHeight, -1) {
		result.MaxHeight = 0
	}
	if math.IsInf(result.MinHeight, 1) {
		result.MinHeight = 0
	}

	return result
}
