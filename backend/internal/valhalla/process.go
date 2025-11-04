package valhalla

import (
	"math"

	"github.com/anish-chanda/cadence/backend/internal/geo"
)

type Result struct {
	Polyline           string             `json:"polyline"`
	DistanceMeters     float64            `json:"distance_meters"`
	DurationSeconds    float64            `json:"duration_seconds"`
	NumLegs            int                `json:"num_legs"`
	NumAlternates      int                `json:"num_alternates"`
	NumPointsPoly      int                `json:"num_points_poly"`
	BBox               map[string]float64 `json:"bbox"`
	Start              map[string]float64 `json:"start"`
	End                map[string]float64 `json:"end"`
	ElevationGainM     *float64           `json:"elevation_gain_m,omitempty"`
	ValDurationSeconds float64            `json:"val_duration_seconds"`
}

func ProcessTraceResponse(resp *TraceRouteResponse) Result {
	// Totals from primary trip (Valhalla returns in km, convert to meters)
	totalKm := resp.Trip.Summary.Length
	totalSec := resp.Trip.Summary.Time

	// Decode + stitch polylines (primary + alternates)
	var allPts []geo.Point

	appendPolyline := func(encoded string) {
		pts, _ := geo.Decode6(encoded)
		if len(pts) == 0 {
			return
		}
		if n := len(allPts); n > 0 && geo.SamePoint(allPts[n-1], pts[0]) {
			pts = pts[1:]
		}
		allPts = append(allPts, pts...)
	}

	for _, leg := range resp.Trip.Legs {
		appendPolyline(leg.Shape)
	}
	for _, alt := range resp.Alternates {
		totalKm += alt.Trip.Summary.Length
		totalSec += alt.Trip.Summary.Time
		for _, leg := range alt.Trip.Legs {
			appendPolyline(leg.Shape)
		}
	}

	combined := geo.Encode6(allPts)

	// Aggregate BBox over all legs
	minLat, minLon := +90.0, +180.0
	maxLat, maxLon := -90.0, -180.0
	updateBBox := func(s Summary) {
		if s.MinLat < minLat {
			minLat = s.MinLat
		}
		if s.MinLon < minLon {
			minLon = s.MinLon
		}
		if s.MaxLat > maxLat {
			maxLat = s.MaxLat
		}
		if s.MaxLon > maxLon {
			maxLon = s.MaxLon
		}
	}
	for _, leg := range resp.Trip.Legs {
		updateBBox(leg.Summary)
	}
	for _, alt := range resp.Alternates {
		for _, leg := range alt.Trip.Legs {
			updateBBox(leg.Summary)
		}
	}

	var start, end map[string]float64
	if len(allPts) > 0 {
		start = map[string]float64{"lat": allPts[0].Lat, "lon": allPts[0].Lon}
		end = map[string]float64{"lat": allPts[len(allPts)-1].Lat, "lon": allPts[len(allPts)-1].Lon}
	} else {
		start = map[string]float64{"lat": minLat, "lon": minLon}
		end = map[string]float64{"lat": maxLat, "lon": maxLon}
	}

	return Result{
		Polyline:           combined,
		DistanceMeters:     round3(totalKm * 1000), // Convert km to meters
		DurationSeconds:    round3(totalSec),
		NumLegs:            len(resp.Trip.Legs),
		NumAlternates:      len(resp.Alternates),
		NumPointsPoly:      len(allPts),
		ValDurationSeconds: round3(totalSec),
		BBox: map[string]float64{
			"min_lat": minLat, "min_lon": minLon,
			"max_lat": maxLat, "max_lon": maxLon,
		},
		Start: start,
		End:   end,
	}
}

func round3(v float64) float64 { return math.Round(v*1000) / 1000 }

// CalculateElevationGain calculates the total elevation gain from height response data
func CalculateElevationGain(heightResp *HeightResponse) float64 {
	if heightResp == nil || len(heightResp.RangeHeight) < 2 {
		return 0.0
	}

	var totalGain float64
	for i := 1; i < len(heightResp.RangeHeight); i++ {
		if len(heightResp.RangeHeight[i]) < 2 || len(heightResp.RangeHeight[i-1]) < 2 {
			continue
		}

		currentHeight := float64(heightResp.RangeHeight[i][1])
		previousHeight := float64(heightResp.RangeHeight[i-1][1])

		// Only add positive elevation changes (uphill)
		if currentHeight > previousHeight {
			totalGain += currentHeight - previousHeight
		}
	}

	return totalGain
}
