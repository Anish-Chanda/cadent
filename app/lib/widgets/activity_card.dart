import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/activity.dart';
import '../utils/polyline_decoder.dart';

class ActivityCard extends StatelessWidget {
  final Activity activity;

  const ActivityCard({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Map section
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            child: SizedBox(
              height: 200,
              child: _buildMap(),
            ),
          ),
          // Content section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStat(
                      icon: Icons.straighten,
                      label: 'Distance',
                      value: activity.formattedDistance,
                    ),
                    const SizedBox(width: 24),
                    _buildStat(
                      icon: Icons.terrain,
                      label: 'Elevation',
                      value: activity.formattedElevation,
                    ),
                    const SizedBox(width: 24),
                    _buildStat(
                      icon: Icons.access_time,
                      label: 'Time',
                      value: activity.formattedDuration,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    // Default center if no coordinates available
    LatLng center = const LatLng(43.65107, 7.22560); // Nice, France default
    List<LatLng> polylinePoints = [];
    
    // If we have a polyline, decode it
    if (activity.polyline != null && activity.polyline!.isNotEmpty) {
      try {
        final decoded = PolylineDecoder.decode(activity.polyline!);
        polylinePoints = decoded.map((point) => LatLng(point.latitude, point.longitude)).toList();
        
        if (polylinePoints.isNotEmpty) {
          center = polylinePoints[polylinePoints.length ~/ 2]; // Use middle point as center
        }
      } catch (e) {
        // If polyline decoding fails, try to use start coordinates
        if (activity.start != null) {
          center = LatLng(activity.start!.lat, activity.start!.lon);
        }
      }
    } else if (activity.start != null) {
      // No polyline but we have start coordinates
      center = LatLng(activity.start!.lat, activity.start!.lon);
    }

    // Note: Could use bounding box for map fit bounds in future

    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: polylinePoints.isNotEmpty ? 13.0 : 10.0,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.none, // Disable interaction for card view
        ),
      ),
      children: [
        TileLayer(
          // TODO: for development us OSM, replace with custom tiles later
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'dev.cadence.app',
        ),
        if (polylinePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: polylinePoints,
                color: const Color(0xFF3B82F6), // Blue color
                strokeWidth: 4.0,
              ),
            ],
          ),
        if (activity.start != null)
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(activity.start!.lat, activity.start!.lon),
                child: const Icon(
                  Icons.play_circle_filled,
                  color: Colors.green,
                  size: 20,
                ),
              ),
              if (activity.end != null)
                Marker(
                  point: LatLng(activity.end!.lat, activity.end!.lon),
                  child: const Icon(
                    Icons.stop_circle,
                    color: Colors.red,
                    size: 20,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildStat({required IconData icon, required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}