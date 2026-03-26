class DerivedStats {
  final double? speedKmh;
  final double? speedMph;
  final double? paceSPerKm;
  final double? paceSPerMile;
  final double distanceKm;
  final double distanceMiles;

  DerivedStats({
    this.speedKmh,
    this.speedMph,
    this.paceSPerKm,
    this.paceSPerMile,
    required this.distanceKm,
    required this.distanceMiles,
  });

  factory DerivedStats.fromJson(Map<String, dynamic> json) {
    return DerivedStats(
      speedKmh: json['speed_kmh']?.toDouble(),
      speedMph: json['speed_mph']?.toDouble(),
      paceSPerKm: json['pace_s_per_km']?.toDouble(),
      paceSPerMile: json['pace_s_per_mile']?.toDouble(),
      distanceKm: (json['distance_km'] as num).toDouble(),
      distanceMiles: (json['distance_miles'] as num).toDouble(),
    );
  }
}

class ActivityStats {
  final double elapsedSeconds;
  final double avgSpeedMs;
  final double elevationGainM;
  final double distanceM;
  final DerivedStats derived;

  ActivityStats({
    required this.elapsedSeconds,
    required this.avgSpeedMs,
    required this.elevationGainM,
    required this.distanceM,
    required this.derived,
  });

  factory ActivityStats.fromJson(Map<String, dynamic> json) {
    return ActivityStats(
      elapsedSeconds: (json['elapsed_seconds'] as num).toDouble(),
      avgSpeedMs: (json['avg_speed_ms'] as num).toDouble(),
      elevationGainM: (json['elevation_gain_m'] as num).toDouble(),
      distanceM: (json['distance_m'] as num).toDouble(),
      derived: DerivedStats.fromJson(json['derived'] as Map<String, dynamic>),
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
  final int? perceivedEffort;
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
  final bool isMetric;

  Activity({
    required this.id,
    required this.title,
    required this.description,
    required this.activityType,
    this.perceivedEffort,
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
    this.isMetric = false,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'] as String,
      title: (json['title'] as String).isNotEmpty ? json['title'] as String : 'Untitled Activity',
      description: (json['description'] as String? ?? ''),
      activityType: json['type'] as String,
      perceivedEffort: json['perceived_effort'] as int?,
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

  /// Returns a copy of this activity with [isMetric] applied.
  /// Call this once in the widget and use the plain getters below.
  Activity withIsMetric(bool isMetric) => Activity(
    id: id,
    title: title,
    description: description,
    activityType: activityType,
    perceivedEffort: perceivedEffort,
    startTime: startTime,
    endTime: endTime,
    stats: stats,
    polyline: polyline,
    bbox: bbox,
    start: start,
    end: end,
    processingVer: processingVer,
    createdAt: createdAt,
    updatedAt: updatedAt,
    isMetric: isMetric,
  );

  // Helper getters for display — unit preference is taken from [isMetric]
  double get distanceKm => stats?.derived.distanceKm ?? 0.0;
  double get distanceMiles => stats?.derived.distanceMiles ?? 0.0;

  String get formattedDistance =>
      isMetric ? distanceKm.toStringAsFixed(2) : distanceMiles.toStringAsFixed(2);
  String get distanceUnit => isMetric ? 'km' : 'mi';

  String get formattedElevation {
    if (stats?.elevationGainM == null) return '0';
    return isMetric
        ? '${stats!.elevationGainM}'
        : (stats!.elevationGainM * 3.28).toStringAsFixed(2);
  }
  String get elevationUnit => isMetric ? 'm' : 'ft';

  String get formattedDuration {
    final elapsedTime = stats?.elapsedSeconds.round() ?? 0;
    final hours = elapsedTime ~/ 3600;
    final minutes = (elapsedTime % 3600) ~/ 60;
    if (hours > 0) {
      return '$hours hr $minutes min';
    }
    return '$minutes min';
  }

  String get formattedSpeed => isMetric
      ? (stats?.derived.speedKmh?.toStringAsFixed(1) ?? '0.0')
      : (stats?.derived.speedMph?.toStringAsFixed(1) ?? '0.0');
  String get speedUnit => isMetric ? 'kph' : 'mph';

  String get formattedPace {
    final paceSec = isMetric
        ? stats?.derived.paceSPerKm
        : stats?.derived.paceSPerMile;
    if (paceSec == null) return 'N/A';
    final minutes = paceSec ~/ 60;
    final seconds = (paceSec % 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
  String get paceUnit => isMetric ? '/km' : '/mi';

}