class PolylinePoint {
  final double latitude;
  final double longitude;

  PolylinePoint(this.latitude, this.longitude);
}

class PolylineDecoder {
  static const int precision = 6;
  static const double factor = 1000000.0; // 10^6

  /// Decodes a Google encoded polyline (precision 6) into a list of coordinates.
  /// This matches the Go backend implementation in polyline.go
  static List<PolylinePoint> decode(String encoded) {
    if (encoded.isEmpty) return [];

    List<PolylinePoint> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      // Decode latitude
      int result = 0;
      int shift = 0;
      while (true) {
        if (index >= encoded.length) break;
        
        int b = encoded.codeUnitAt(index) - 63;
        index++;
        result |= (b & 0x1f) << shift;
        shift += 5;
        if (b < 0x20) break;
      }
      int dlat = _decodeSigned(result);
      lat += dlat;

      // Decode longitude
      result = 0;
      shift = 0;
      while (true) {
        if (index >= encoded.length) break;
        
        int b = encoded.codeUnitAt(index) - 63;
        index++;
        result |= (b & 0x1f) << shift;
        shift += 5;
        if (b < 0x20) break;
      }
      int dlng = _decodeSigned(result);
      lng += dlng;

      points.add(PolylinePoint(
        lat / factor,
        lng / factor,
      ));
    }

    return points;
  }

  static int _decodeSigned(int value) {
    if ((value & 1) != 0) {
      return ~(value >> 1);
    }
    return value >> 1;
  }
}