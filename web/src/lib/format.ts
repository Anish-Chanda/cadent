// TODO: handle unit conversions (metric/imperial) throughout once a settings screen is added.
// All formatters currently assume metric output.

/**
 * Formats a distance in kilometres for display.
 * e.g. 10.057 -> "10.06 km"
 */
export function formatDistance(km: number): string {
	return `${km.toFixed(2)} km`;
}

/**
 * Formats a running pace given in seconds-per-km.
 * e.g. 298 -> "4:58 /km"
 * Returns "—" when pace is unavailable.
 */
export function formatPace(secPerKm: number | undefined): string {
	if (secPerKm == null) return "—";
	const mins = Math.floor(secPerKm / 60);
	const secs = Math.round(secPerKm % 60);
	return `${mins}:${String(secs).padStart(2, "0")} /km`;
}

/**
 * Formats a cycling average speed given in kph.
 * e.g. 28.5 -> "28.5 kph"
 * Returns "—" when speed is unavailable.
 */
export function formatSpeed(kmh: number | undefined): string {
	if (kmh == null) return "—";
	return `${kmh.toFixed(1)} kph`;
}

/**
 * Formats an elapsed duration in seconds into a human-readable string.
 * e.g. 3000 → "50m 0s", 3661 → "1h 1m", 45 → "45s"
 */
export function formatElapsed(seconds: number): string {
	const h = Math.floor(seconds / 3600);
	const m = Math.floor((seconds % 3600) / 60);
	const s = Math.floor(seconds % 60); // floor, not round — rounding can produce "60s"
	if (h > 0) return `${h}h ${m}m`;
	if (m > 0) return `${m}m ${s}s`;
	return `${s}s`;
}

/**
 * Formats an elevation gain in metres.
 * e.g. 142.6 → "+143 m"
 */
export function formatElevation(meters: number): string {
	return `+${Math.round(meters)} m`;
}

/**
 * Formats an ISO date string into a display-friendly relative label.
 * - Same day   → "Today at 7:12 AM"
 * - Yesterday  → "Yesterday at 5:30 PM"
 * - Same year  → "Jan 5 at 9:00 AM"
 * - Older      → "Jan 5, 2024 at 9:00 AM"
 */
export function formatActivityDate(isoString: string): string {
	const date = new Date(isoString);
	const now = new Date();

	const isToday =
		date.getDate() === now.getDate() &&
		date.getMonth() === now.getMonth() &&
		date.getFullYear() === now.getFullYear();

	const yesterday = new Date(now);
	yesterday.setDate(now.getDate() - 1);
	const isYesterday =
		date.getDate() === yesterday.getDate() &&
		date.getMonth() === yesterday.getMonth() &&
		date.getFullYear() === yesterday.getFullYear();

	const timeStr = date.toLocaleTimeString(undefined, {
		hour: "numeric",
		minute: "2-digit",
		hour12: true,
	});

	if (isToday) return `Today at ${timeStr}`;
	if (isYesterday) return `Yesterday at ${timeStr}`;

	return `${date.toLocaleDateString(undefined, {
		month: "short",
		day: "numeric",
		year: date.getFullYear() !== now.getFullYear() ? "numeric" : undefined,
	})} at ${timeStr}`;
}
