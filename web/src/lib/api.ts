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

export function getActivities(): Promise<GetActivitiesResponse> {
	return request<GetActivitiesResponse>("/v1/activities");
}

export { ApiError };
