enum TrainingPlanActivityTypeFilter { all, running, roadBiking }

extension TrainingPlanActivityTypeFilterX on TrainingPlanActivityTypeFilter {
  String get apiValue {
    switch (this) {
      case TrainingPlanActivityTypeFilter.all:
        return 'all';
      case TrainingPlanActivityTypeFilter.running:
        return 'running';
      case TrainingPlanActivityTypeFilter.roadBiking:
        return 'road_biking';
    }
  }

  String get label {
    switch (this) {
      case TrainingPlanActivityTypeFilter.all:
        return 'All';
      case TrainingPlanActivityTypeFilter.running:
        return 'Running';
      case TrainingPlanActivityTypeFilter.roadBiking:
        return 'Road Biking';
    }
  }
}

class TrainingPlan {
  final String id;
  final String title;
  final String? description;
  final String? primaryActivityType;
  final String difficulty;
  final int durationWeeks;
  final int recommendedWorkoutsPerWeek;
  final bool isSystem;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TrainingPlan({
    required this.id,
    required this.title,
    this.description,
    this.primaryActivityType,
    required this.difficulty,
    required this.durationWeeks,
    required this.recommendedWorkoutsPerWeek,
    required this.isSystem,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TrainingPlan.fromJson(Map<String, dynamic> json) {
    return TrainingPlan(
      id: json['id'] as String,
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? json['title'] as String
          : 'Untitled Plan',
      description: json['description'] as String?,
      primaryActivityType: json['primary_activity_type'] as String?,
      difficulty: (json['difficulty'] as String?) ?? 'beginner',
      durationWeeks: (json['duration_weeks'] as num?)?.toInt() ?? 0,
      recommendedWorkoutsPerWeek:
          (json['recommended_workouts_per_week'] as num?)?.toInt() ?? 1,
      isSystem: json['is_system'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class TrainingPlanWorkout {
  final String id;
  final String trainingPlanId;
  final int sequenceIndex;
  final int templateDayOffset;
  final String type;
  final String title;
  final String? description;
  final double? plannedDistanceM;
  final int? plannedDurationS;
  final double? plannedElevationGainM;
  final double? targetAvgSpeedMps;
  final int? targetPowerWatt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TrainingPlanWorkout({
    required this.id,
    required this.trainingPlanId,
    required this.sequenceIndex,
    required this.templateDayOffset,
    required this.type,
    required this.title,
    this.description,
    this.plannedDistanceM,
    this.plannedDurationS,
    this.plannedElevationGainM,
    this.targetAvgSpeedMps,
    this.targetPowerWatt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TrainingPlanWorkout.fromJson(Map<String, dynamic> json) {
    return TrainingPlanWorkout(
      id: json['id'] as String,
      trainingPlanId: json['training_plan_id'] as String,
      sequenceIndex: (json['sequence_index'] as num?)?.toInt() ?? 0,
      templateDayOffset: (json['template_day_offset'] as num?)?.toInt() ?? 0,
      type: (json['type'] as String?) ?? 'running',
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? json['title'] as String
          : 'Workout',
      description: json['description'] as String?,
      plannedDistanceM: (json['planned_distance_m'] as num?)?.toDouble(),
      plannedDurationS: (json['planned_duration_s'] as num?)?.toInt(),
      plannedElevationGainM: (json['planned_elevation_gain_m'] as num?)
          ?.toDouble(),
      targetAvgSpeedMps: (json['target_avg_speed_mps'] as num?)?.toDouble(),
      targetPowerWatt: (json['target_power_watt'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class ImportTrainingPlanRequest {
  final DateTime startDate;
  final int selectedWorkoutsPerWeek;
  final String title;
  final String? description;

  const ImportTrainingPlanRequest({
    required this.startDate,
    required this.selectedWorkoutsPerWeek,
    required this.title,
    this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'startDate': startDate.toUtc().toIso8601String(),
      'selectedWorkoutsPerWeek': selectedWorkoutsPerWeek,
      'title': title,
      'description': description,
    };
  }
}

class ImportTrainingPlanDryRunRequest {
  final DateTime startDate;
  final int selectedWorkoutsPerWeek;
  final String? title;
  final String? description;

  const ImportTrainingPlanDryRunRequest({
    required this.startDate,
    required this.selectedWorkoutsPerWeek,
    this.title,
    this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'startDate': startDate.toUtc().toIso8601String(),
      'selectedWorkoutsPerWeek': selectedWorkoutsPerWeek,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
    };
  }
}

class ImportTrainingPlanResponse {
  final String userTrainingPlanId;
  final int plannedActivitiesCreated;

  const ImportTrainingPlanResponse({
    required this.userTrainingPlanId,
    required this.plannedActivitiesCreated,
  });

  factory ImportTrainingPlanResponse.fromJson(Map<String, dynamic> json) {
    return ImportTrainingPlanResponse(
      userTrainingPlanId: json['userTrainingPlanId'] as String,
      plannedActivitiesCreated:
          (json['plannedActivitiesCreated'] as num?)?.toInt() ?? 0,
    );
  }
}

class TrainingPlanPreviewActivity {
  final String id;
  final String title;
  final String type;
  final DateTime startTime;

  const TrainingPlanPreviewActivity({
    required this.id,
    required this.title,
    required this.type,
    required this.startTime,
  });

  factory TrainingPlanPreviewActivity.fromJson(Map<String, dynamic> json) {
    return TrainingPlanPreviewActivity(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? 'Activity',
      type: (json['type'] as String?) ?? 'running',
      startTime: DateTime.parse(json['start_time'] as String),
    );
  }
}

class TrainingPlanPreviewPlannedActivity {
  final String id;
  final String title;
  final String type;
  final DateTime startTime;
  final bool isDryRun;
  final String? matchedActivityId;

  const TrainingPlanPreviewPlannedActivity({
    required this.id,
    required this.title,
    required this.type,
    required this.startTime,
    required this.isDryRun,
    this.matchedActivityId,
  });

  factory TrainingPlanPreviewPlannedActivity.fromJson(
    Map<String, dynamic> json,
  ) {
    return TrainingPlanPreviewPlannedActivity(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? 'Planned Activity',
      type: (json['type'] as String?) ?? 'running',
      startTime: DateTime.parse(json['start_time'] as String),
      isDryRun: json['is_dry_run'] as bool? ?? false,
      matchedActivityId: json['matched_activity_id'] as String?,
    );
  }
}

class TrainingPlanPreviewResponse {
  final List<TrainingPlanPreviewActivity> activities;
  final List<TrainingPlanPreviewPlannedActivity> plannedActivities;

  const TrainingPlanPreviewResponse({
    required this.activities,
    required this.plannedActivities,
  });

  factory TrainingPlanPreviewResponse.fromJson(Map<String, dynamic> json) {
    final activitiesRaw = (json['activities'] as List<dynamic>? ?? []);
    final plannedActivitiesRaw =
        (json['planned_activities'] as List<dynamic>? ?? []);

    return TrainingPlanPreviewResponse(
      activities: activitiesRaw
          .whereType<Map<String, dynamic>>()
          .map(TrainingPlanPreviewActivity.fromJson)
          .toList(),
      plannedActivities: plannedActivitiesRaw
          .whereType<Map<String, dynamic>>()
          .map(TrainingPlanPreviewPlannedActivity.fromJson)
          .toList(),
    );
  }
}
