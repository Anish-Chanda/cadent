class ActivityStats {
  final double elapsedSeconds;
  final double avgSpeedMs;
  final double elevationGainM;
  final double distanceM;

  ActivityStats({
    required this.elapsedSeconds,
    required this.avgSpeedMs,
    required this.elevationGainM,
    required this.distanceM,
  });

  factory ActivityStats.fromJson(Map<String, dynamic> json) {
    return ActivityStats(
      elapsedSeconds: (json['elapsed_seconds'] as num).toDouble(),
      avgSpeedMs: (json['avg_speed_ms'] as num).toDouble(),
      elevationGainM: (json['elevation_gain_m'] as num).toDouble(),
      distanceM: (json['distance_m'] as num).toDouble(),
    );
  }
}

class BoundingBox {
  final double minLat;
  final double maxLat;
  final double minLon;
  final double maxLon;

  BoundingBox({
    required this.minLat,
    required this.maxLat,
    required this.minLon,
    required this.maxLon,
  });

  factory BoundingBox.fromJson(Map<String, dynamic> json) {
    return BoundingBox(
      minLat: (json['min_lat'] as num).toDouble(),
      maxLat: (json['max_lat'] as num).toDouble(),
      minLon: (json['min_lon'] as num).toDouble(),
      maxLon: (json['max_lon'] as num).toDouble(),
    );
  }
}

class Coordinate {
  final double lat;
  final double lon;

  Coordinate({
    required this.lat,
    required this.lon,
  });

  factory Coordinate.fromJson(Map<String, dynamic> json) {
    return Coordinate(
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
    );
  }
}

class Activity {
  final String id;
  final String title;
  final String description;
  final String activityType;
  final DateTime startTime;
  final DateTime? endTime;
  final ActivityStats? stats;
  final String? polyline;
  final BoundingBox? bbox;
  final Coordinate? start;
  final Coordinate? end;
  final int processingVer;
  final DateTime createdAt;
  final DateTime updatedAt;

  Activity({
    required this.id,
    required this.title,
    required this.description,
    required this.activityType,
    required this.startTime,
    this.endTime,
    this.stats,
    this.polyline,
    this.bbox,
    this.start,
    this.end,
    required this.processingVer,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'] as String,
      title: (json['title'] as String).isNotEmpty ? json['title'] as String : 'Untitled Activity',
      description: (json['description'] as String? ?? ''),
      activityType: json['type'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time'] as String) : null,
      stats: json['stats'] != null ? ActivityStats.fromJson(json['stats'] as Map<String, dynamic>) : null,
      polyline: json['polyline'] as String?,
      bbox: json['bbox'] != null ? BoundingBox.fromJson(json['bbox'] as Map<String, dynamic>) : null,
      start: json['start'] != null ? Coordinate.fromJson(json['start'] as Map<String, dynamic>) : null,
      end: json['end'] != null ? Coordinate.fromJson(json['end'] as Map<String, dynamic>) : null,
      processingVer: json['processing_ver'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  // Helper getters for display
  double get distanceKm => stats?.distanceM != null ? stats!.distanceM / 1000 : 0.0;
  
  String get formattedDistance => '${distanceKm.toStringAsFixed(1)} Km';
  
  String get formattedElevation => stats?.elevationGainM != null ? '${stats!.elevationGainM.round()} m' : '0 m';
  
  String get formattedDuration {
    final elapsedTime = stats?.elapsedSeconds.round() ?? 0;
    final hours = elapsedTime ~/ 3600;
    final minutes = (elapsedTime % 3600) ~/ 60;
    if (hours > 0) {
      return '$hours hr $minutes min';
    }
    return '$minutes min';
  }
}