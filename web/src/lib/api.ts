const API_BASE = "/api";

class ApiError extends Error {
	constructor(
		public readonly status: number,
		message: string,
	) {
		super(message);
		this.name = "ApiError";
	}
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
	const res = await fetch(`${API_BASE}${path}`, {
		headers: { "Content-Type": "application/json", ...init?.headers },
		credentials: "include",
		...init,
	});

	if (!res.ok) {
		const text = await res.text().catch(() => res.statusText);
		throw new ApiError(res.status, text);
	}

	// 204 No Content
	if (res.status === 204) {
		return undefined as T;
	}

	return res.json() as Promise<T>;
}

// ---- Auth ----

export interface LoginRequest {
	user: string;
	passwd: string;
}

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

/** token.User returned by go-pkgz/auth after a successful local login */
export interface AuthUser {
	name: string;
	id: string;
	picture: string;
	ip: string;
}

/** /v1/user response from our handler */
export interface UserProfile {
	id: string;
	email: string;
	name: string;
}

export function login(data: LoginRequest): Promise<AuthUser> {
	return request<AuthUser>("/auth/local/login", {
		method: "POST",
		body: JSON.stringify(data),
	});
}

export function signup(data: SignupRequest): Promise<SignupResponse> {
	return request<SignupResponse>("/signup", {
		method: "POST",
		body: JSON.stringify(data),
	});
}

export async function logout(): Promise<void> {
	// go-pkgz/auth logout responds with a 3xx redirect.
	// Use redirect:'manual' so fetch doesn't follow it and treats the
	// opaque response as success — the cookie is cleared server-side either way.
	await fetch(`${API_BASE}/auth/logout`, {
		method: "GET",
		credentials: "include",
		redirect: "manual",
	});
}

export function getCurrentUser(): Promise<UserProfile> {
	return request<UserProfile>("/v1/user");
}

// ---- Activities ----

export interface DerivedStats {
	speed_kmh?: number;
	speed_mph?: number;
	pace_s_per_km?: number;
	pace_s_per_mile?: number;
	distance_km: number;
	distance_miles: number;
}

export interface ActivityStats {
	elapsed_seconds: number;
	avg_speed_ms: number;
	elevation_gain_m: number;
	elevation_loss_m: number;
	max_height_m: number;
	min_height_m: number;
	distance_m: number;
	derived: DerivedStats;
}

export interface BoundingBox {
	min_lat: number;
	max_lat: number;
	min_lon: number;
	max_lon: number;
}

export interface GeoCoordinate {
	lat: number;
	lon: number;
}

export interface Activity {
	id: string;
	title: string;
	description: string;
	type: string;
	start_time: string;
	end_time: string | null;
	stats: ActivityStats;
	bbox: BoundingBox;
	start: GeoCoordinate;
	end: GeoCoordinate;
	polyline: string;
	processing_ver: number;
	created_at: string;
	updated_at: string;
}

export interface GetActivitiesResponse {
	activities: Activity[];
}

export type ActivityType = "running" | "road_biking";

export function getActivities(): Promise<GetActivitiesResponse> {
	return request<GetActivitiesResponse>("/v1/activities");
}

export { ApiError };

// ---- Training Plans ----
export interface TrainingPlan {
	id: string;
	created_by_user_id?: string;
	title: string;
	description: string | null;
	primary_activity_type: ActivityType | null;
	difficulty: string;
	duration_weeks: number;
	recommended_workouts_per_week: number;
	is_system: boolean;
	created_at: string;
	updated_at: string;
}

// "all" is a UI-only filter value and is not part of the backend activity_type enum.
export type TrainingPlanActivityTypeFilter = ActivityType | "all";

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

export function getTrainingPlans(
	q?: string,
	activityType?: TrainingPlanActivityTypeFilter,
): Promise<TrainingPlan[]> {
	const params = new URLSearchParams();
	if (q) params.set("q", q);
	if (activityType && activityType !== "all") {
		params.set("activity_type", activityType);
	}
	return request<TrainingPlan[]>(`/v1/training-plans?${params.toString()}`);
}

export function getTrainingPlanWorkouts(
	id: string,
): Promise<TrainingPlanWorkout[]> {
	return request<TrainingPlanWorkout[]>(`/v1/training-plans/${id}/workouts`);
}

export interface ImportTrainingPlanRequest {
	startDate: string;
	selectedWorkoutsPerWeek: number;
	title: string;
	description: string | null;
}

export interface ImportTrainingPlanResponse {
	userTrainingPlanId: string;
	plannedActivitiesCreated: number;
}

export interface ImportTrainingPlanDryRunRequest {
	startDate: string;
	selectedWorkoutsPerWeek: number;
	title?: string | null;
	description?: string | null;
}

export function importTrainingPlan(
	id: string,
	data: ImportTrainingPlanRequest,
): Promise<ImportTrainingPlanResponse> {
	return request<ImportTrainingPlanResponse>(`/v1/training-plans/${id}/import`, {
		method: "POST",
		body: JSON.stringify(data),
	});
}

export function importTrainingPlanDryRun(
	id: string,
	data: ImportTrainingPlanDryRunRequest,
): Promise<GetCalendarResponse> {
	return request<GetCalendarResponse>(`/v1/training-plans/${id}/import/dry-run`, {
		method: "POST",
		body: JSON.stringify(data),
	});
}

export interface PlannedActivity {
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
	// is dry run is used to visually differentiate with real planned activties (mostly used in the import panel by dry-run)
	is_dry_run?: boolean;
	matched_activity_id?: string;
	user_training_plan_id?: string;
	plan_sequence_index?: number;
	created_at: string;
	updated_at: string;
}

export interface CreatePlannedActivityRequest {
	title: string;
	description?: string;
	activityType: string;
	startTime: string;
	plannedDistanceMeter?: number;
	plannedDurationSecond?: number;
	plannedElevationGainMeter?: number;
	targetAverageSpeedMeterPerSecond?: number;
	targetPowerWatt?: number;
}

export interface CreatePlannedActivityResponse {
	id: string;
}

export interface GetCalendarResponse {
	activities: Activity[];
	planned_activities: PlannedActivity[];
}

export const getCalendar = async (startDate?: string, endDate?: string) => {
	const searchParams = new URLSearchParams();
	if (startDate) searchParams.append("startDate", startDate);
	if (endDate) searchParams.append("endDate", endDate);

	return request<GetCalendarResponse>(`/v1/calendar?${searchParams.toString()}`);
};

export const createPlannedActivity = async (data: CreatePlannedActivityRequest) => {
	return request<CreatePlannedActivityResponse>("/v1/activities/plan", {
		method: "POST",
		body: JSON.stringify(data),
	});
};
