import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/activity.dart';
import '../utils/polyline_decoder.dart';
import '../screens/activity_detail_screen.dart';

class ActivityCard extends StatelessWidget {
  final Activity activity;

  const ActivityCard({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ActivityDetailScreen(activity: activity),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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
                child: _buildMap(context),
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
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ) ?? const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Distance - left aligned with title
                      _buildStat(
                        context: context,
                        icon: Icons.straighten,
                        label: 'Distance',
                        value: activity.formattedDistance,
                      ),
                      // Flexible space for center alignment
                      Expanded(
                        child: Center(
                          child: _buildStat(
                            context: context,
                            icon: Icons.terrain,
                            label: 'Elevation',
                            value: activity.formattedElevation,
                          ),
                        ),
                      ),
                      // Time - right aligned with padding
                      _buildStat(
                        context: context,
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
      ),
    );
  }

  Widget _buildMap(BuildContext context) {
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
                color: Theme.of(context).colorScheme.primary,
                strokeWidth: 4.0,
              ),
            ],
          ),
        if (activity.start != null)
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(activity.start!.lat, activity.start!.lon),
                child: Icon(
                  Icons.play_circle_filled,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              if (activity.end != null)
                Marker(
                  point: LatLng(activity.end!.lat, activity.end!.lon),
                  child: Icon(
                    Icons.stop_circle,
                    color: Theme.of(context).colorScheme.error,
                    size: 20,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildStat({required BuildContext context, required IconData icon, required String label, required String value}) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: Theme.of(context).colorScheme.outline),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ) ?? TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ) ?? const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}