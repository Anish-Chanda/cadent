class PlannedActivity {
  final String? id;
  final String title;
  final String? description;
  final String activityType;
  final DateTime startTime;
  final double? plannedDistanceMeter;
  final int? plannedDurationSecond;
  final double? plannedElevationGainMeter;
  final double? targetAverageSpeedMeterPerSecond;
  final int? targetPowerWatt;

  const PlannedActivity({
    this.id,
    required this.title,
    this.description,
    required this.activityType,
    required this.startTime,
    this.plannedDistanceMeter,
    this.plannedDurationSecond,
    this.plannedElevationGainMeter,
    this.targetAverageSpeedMeterPerSecond,
    this.targetPowerWatt,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    if (description != null) 'description': description,
    'activityType': activityType,
    'startTime': startTime.toUtc().toIso8601String(),
    if (plannedDistanceMeter != null)
      'plannedDistanceMeter': plannedDistanceMeter,
    if (plannedDurationSecond != null)
      'plannedDurationSecond': plannedDurationSecond,
    if (plannedElevationGainMeter != null)
      'plannedElevationGainMeter': plannedElevationGainMeter,
    if (targetAverageSpeedMeterPerSecond != null)
      'targetAverageSpeedMeterPerSecond': targetAverageSpeedMeterPerSecond,
    if (targetPowerWatt != null) 'targetPowerWatt': targetPowerWatt,
  };

  factory PlannedActivity.fromJson(Map<String, dynamic> json) =>
      PlannedActivity(
        title: json['title'] as String,
        description: json['description'] as String?,
        activityType: json['activityType'] as String,
        startTime: DateTime.parse(json['startTime'] as String),
        plannedDistanceMeter: (json['plannedDistanceMeter'] as num?)
            ?.toDouble(),
        plannedDurationSecond: json['plannedDurationSecond'] as int?,
        plannedElevationGainMeter: (json['plannedElevationGainMeter'] as num?)
            ?.toDouble(),
        targetAverageSpeedMeterPerSecond:
            (json['targetAverageSpeedMeterPerSecond'] as num?)?.toDouble(),
        targetPowerWatt: json['targetPowerWatt'] as int?,
      );

  /// Parses the snake_case response from the calendar API endpoint.
  factory PlannedActivity.fromCalendarJson(Map<String, dynamic> json) =>
      PlannedActivity(
        id: json['id'] as String?,
        title: json['title'] as String,
        description: (json['description'] as String?)?.isEmpty == true
            ? null
            : json['description'] as String?,
        activityType: json['type'] as String,
        startTime: DateTime.parse(json['start_time'] as String),
        plannedDistanceMeter: (json['planned_distance'] as num?)?.toDouble(),
        plannedDurationSecond: json['planned_duration'] as int?,
        plannedElevationGainMeter:
            (json['planned_elevation_gain'] as num?)?.toDouble(),
        targetAverageSpeedMeterPerSecond:
            (json['target_avg_speed'] as num?)?.toDouble(),
        targetPowerWatt: json['target_power'] as int?,
      );
}
