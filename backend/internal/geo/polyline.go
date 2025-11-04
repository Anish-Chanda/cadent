package geo

import (
	"math"
)

type Point struct {
	Lat float64
	Lon float64
}

const precision = 6

var factor = math.Pow(10, precision)

// Decode6 decodes a Google encoded polyline (precision 6) into points.
func Decode6(s string) ([]Point, error) {
	var (
		index int
		lat   int64
		lng   int64
		out   = make([]Point, 0, len(s)/4)
	)

	for index < len(s) {
		// latitude
		var result int64
		var shift uint
		for {
			if index >= len(s) {
				return out, nil // graceful end on malformed tail
			}
			b := int64(s[index]) - 63
			index++
			result |= (b & 0x1f) << shift
			shift += 5
			if b < 0x20 {
				break
			}
		}
		dlat := decodeSigned(result)
		lat += dlat

		// longitude
		result = 0
		shift = 0
		for {
			if index >= len(s) {
				return out, nil
			}
			b := int64(s[index]) - 63
			index++
			result |= (b & 0x1f) << shift
			shift += 5
			if b < 0x20 {
				break
			}
		}
		dlng := decodeSigned(result)
		lng += dlng

		out = append(out, Point{
			Lat: float64(lat) / factor,
			Lon: float64(lng) / factor,
		})
	}
	return out, nil
}

func decodeSigned(v int64) int64 {
	if (v & 1) != 0 {
		return ^(v >> 1)
	}
	return v >> 1
}

// Encode6 encodes points into a Google polyline (precision 6).
func Encode6(pts []Point) string {
	var (
		prevLat int64
		prevLng int64
		out     []byte
	)
	for i, p := range pts {
		lat := int64(round(p.Lat * factor))
		lng := int64(round(p.Lon * factor))
		if i == 0 {
			out = append(out, encodeSigned(lat)...)
			out = append(out, encodeSigned(lng)...)
		} else {
			out = append(out, encodeSigned(lat-prevLat)...)
			out = append(out, encodeSigned(lng-prevLng)...)
		}
		prevLat = lat
		prevLng = lng
	}
	return string(out)
}

func encodeSigned(v int64) []byte {
	uv := uint64(v << 1)
	if v < 0 {
		uv = ^uv
	}
	var out []byte
	for uv >= 0x20 {
		out = append(out, byte((0x20|(uv&0x1f))+63))
		uv >>= 5
	}
	out = append(out, byte(uv+63))
	return out
}

func round(v float64) float64 {
	if v >= 0 {
		return math.Floor(v + 0.5)
	}
	return math.Ceil(v - 0.5)
}

// SamePoint returns true if two points are equal within ~1e-7 degrees.
func SamePoint(a, b Point) bool {
	const eps = 1e-7
	return math.Abs(a.Lat-b.Lat) < eps && math.Abs(a.Lon-b.Lon) < eps
}
