import polyline from "@mapbox/polyline";
import maplibregl from "maplibre-gl";
import { useEffect, useRef } from "react";
import "maplibre-gl/dist/maplibre-gl.css";
import type { Activity } from "@/lib/api";

interface ActivityMapPreviewProps {
	activity: Activity;
	className?: string;
}

export function ActivityMapPreview({
	activity,
	className,
}: ActivityMapPreviewProps) {
	const mapContainerRef = useRef<HTMLDivElement>(null);
	const mapRef = useRef<maplibregl.Map | null>(null);

	useEffect(() => {
		if (!mapContainerRef.current || !activity.polyline) return;

		// Decode encoded polyline (precision 6 / poly6) → [[lat, lon], ...] → [[lon, lat], ...] for GeoJSON
		const decoded = polyline.decode(activity.polyline, 6);
		const geoCoords: [number, number][] = decoded.map(([lat, lon]) => [
			lon,
			lat,
		]);

		const map = new maplibregl.Map({
			container: mapContainerRef.current,
			style: "https://tiles.openfreemap.org/styles/liberty",
			interactive: false,
			attributionControl: false,
		});

		mapRef.current = map;

		map.on("load", () => {
			// Disable 3D building extrusion layers — keep the map flat/2D
			for (const layer of map.getStyle().layers) {
				if (layer.type === "fill-extrusion") {
					map.setLayoutProperty(layer.id, "visibility", "none");
				}
			}

			map.addSource("route", {
				type: "geojson",
				data: {
					type: "Feature",
					properties: {},
					geometry: {
						type: "LineString",
						coordinates: geoCoords,
					},
				},
			});

			map.addLayer({
				id: "route-outline",
				type: "line",
				source: "route",
				layout: { "line-join": "round", "line-cap": "round" },
				paint: {
					"line-color": "#ffffff",
					"line-width": 5,
					"line-opacity": 0.6,
				},
			});

			map.addLayer({
				id: "route",
				type: "line",
				source: "route",
				layout: { "line-join": "round", "line-cap": "round" },
				paint: {
					// Cadent brand blue
					"line-color": "#59c4f7",
					"line-width": 3,
				},
			});

			const bounds = new maplibregl.LngLatBounds();
			for (const coord of geoCoords) {
				bounds.extend(coord);
			}
			map.fitBounds(bounds, { padding: 40, duration: 0, maxZoom: 16 });
		});

		return () => {
			map.remove();
			mapRef.current = null;
		};
	}, [activity.polyline]);

	if (!activity.polyline) {
		return (
			<div
				className={`mx-4 mb-4 flex items-center justify-center bg-muted rounded-xl ${className ?? ""}`}
			>
				<span className="text-xs text-muted-foreground">No route data</span>
			</div>
		);
	}

	return (
		<div
			ref={mapContainerRef}
			className={`mx-4 mb-4 rounded-xl overflow-hidden ${className ?? ""}`}
		/>
	);
}
