export interface SignupRequest {
  user: string;
  passwd: string;
  name: string;
}

export interface SignupResponse {
  success: boolean;
  user_id: string;
  message: string;
}

export interface UserResponse {
  id: string;
  email: string;
  name: string;
}

export type ActivityType = 'running' | 'road_biking';

export interface Sample {
  t: number;
  lat: number;
  lon: number;
  ele?: number;
}

export interface CreateActivityRequest {
  client_activity_id: string;
  activity_type: ActivityType;
  title: string;
  description?: string | null;
  perceived_effort?: number | null;
  samples: Sample[];
}

export interface ActivityStats {
  elapsed_seconds: number;
  avg_speed_ms: number;
  elevation_gain_m: number;
  elevation_loss_m: number;
  max_height_m: number;
  min_height_m: number;
  distance_m: number;
  derived: {
    speed_kmh?: number;
    speed_mph?: number;
    pace_s_per_km?: number;
    pace_s_per_mile?: number;
    distance_km: number;
    distance_miles: number;
  };
}

export interface Coordinate {
  lat: number;
  lon: number;
}

export interface BoundingBox {
  min_lat: number;
  max_lat: number;
  min_lon: number;
  max_lon: number;
}

export interface ActivityResult {
  id: string;
  title: string;
  description: string;
  type: ActivityType;
  perceived_effort: number | null;
  start_time: string;
  end_time: string | null;
  stats: ActivityStats;
  bbox: BoundingBox;
  start: Coordinate;
  end: Coordinate;
  polyline: string;
  processing_ver: number;
  created_at: string;
  updated_at: string;
}

export interface UploadResponse {
  id: string;
}

export interface GetActivitiesResponse {
  activities: ActivityResult[];
}

export interface StreamData {
  type: string;
  values: number[];
}

export interface StreamsResponse {
  activity_id: string;
  lod: string;
  index_by: string;
  num_points: number;
  original_num_points: number;
  streams: StreamData[];
}

export interface CreatePlannedActivityRequest {
  title: string;
  description?: string | null;
  activityType: string;
  startTime: string;
  plannedDistanceMeter?: number | null;
  plannedDurationSecond?: number | null;
  plannedElevationGainMeter?: number | null;
  targetAverageSpeedMeterPerSecond?: number | null;
  targetPowerWatt?: number | null;
}

export interface PlannedActivityResult {
  id: string;
  title: string;
  description: string;
  type: string;
  start_time: string;
  planned_distance_m: number | null;
  planned_duration_s: number | null;
  planned_elevation_gain_m: number | null;
  target_avg_speed_mps: number | null;
  target_power_watt: number | null;
  is_dry_run?: boolean;
  matched_activity_id?: string | null;
  user_training_plan_id?: string | null;
  plan_sequence_index?: number | null;
  created_at: string;
  updated_at: string;
}

export interface CalendarResponse {
  activities: ActivityResult[];
  planned_activities: PlannedActivityResult[];
}

export interface TrainingPlan {
  id: string;
  title: string;
  description: string | null;
  primary_activity_type: string | null;
  difficulty: string;
  duration_weeks: number;
  recommended_workouts_per_week: number;
  is_system: boolean;
  created_at: string;
  updated_at: string;
}

export interface TrainingPlanWorkout {
  id: string;
  training_plan_id: string;
  sequence_index: number;
  template_day_offset: number;
  type: string;
  title: string;
  description: string | null;
  planned_distance_m: number | null;
  planned_duration_s: number | null;
  planned_elevation_gain_m: number | null;
  target_avg_speed_mps: number | null;
  target_power_watt: number | null;
  created_at: string;
  updated_at: string;
}

export interface ImportDryRunRequest {
  startDate: string;
  selectedWorkoutsPerWeek: number;
  title?: string;
  description?: string | null;
}
