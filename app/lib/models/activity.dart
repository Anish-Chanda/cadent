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

  // Helper getters for display using derived data
  double get distanceKm => stats?.derived.distanceKm ?? 0.0;
  double get distanceMiles => stats?.derived.distanceMiles ?? 0.0;
  
  String get formattedDistance => '${distanceKm.toStringAsFixed(2)} Km';
  
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

  // helper getters for speed and pace
  String get formattedSpeed {
    if (stats?.derived.speedKmh != null) {
      return '${stats!.derived.speedKmh!.toStringAsFixed(1)} km/h';
    } else if (stats?.derived.speedMph != null) {
      return '${stats!.derived.speedMph!.toStringAsFixed(1)} mph';
    }
    return 'N/A';
  }

  String get formattedPace {
    if (stats?.derived.paceSPerKm != null) {
      final paceSec = stats!.derived.paceSPerKm!;
      final minutes = paceSec ~/ 60;
      final seconds = (paceSec % 60).round();
      return '$minutes:${seconds.toString().padLeft(2, '0')}/km';
    } else if (stats?.derived.paceSPerMile != null) {
      final paceSec = stats!.derived.paceSPerMile!;
      final minutes = paceSec ~/ 60;
      final seconds = (paceSec % 60).round();
      return '$minutes:${seconds.toString().padLeft(2, '0')}/mi';
    }
    return 'N/A';
  }
}