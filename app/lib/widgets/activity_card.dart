import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/activity.dart';
import '../utils/polyline_decoder.dart';
import '../utils/app_spacing.dart';
import '../utils/app_text_size.dart';
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
        margin: AppSpacing.paddingHorizontalMD.add(AppSpacing.paddingVerticalXS),
        elevation: AppSpacing.elevationXS,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusMD,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Map section
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppSpacing.radiusMD),
                topRight: Radius.circular(AppSpacing.radiusMD),
              ),
              child: SizedBox(
                height: 200,
                child: _buildMap(context),
              ),
            ),
            // Content section
            Padding(
              padding: AppSpacing.paddingMD,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    style: AppTextStyles.titleLarge(
                      context,
                      fontWeight: AppTextSize.bold,
                    ),
                  ),
                  AppSpacing.gapMD,
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
                strokeWidth: AppSpacing.xxs,
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
                  size: AppSpacing.iconSM,
                ),
              ),
              if (activity.end != null)
                Marker(
                  point: LatLng(activity.end!.lat, activity.end!.lon),
                  child: Icon(
                    Icons.stop_circle,
                    color: Theme.of(context).colorScheme.error,
                    size: AppSpacing.iconSM,
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
            Icon(icon, size: AppSpacing.iconXS, color: Theme.of(context).colorScheme.outline),
            AppSpacing.gapHorizontalXXS,
            Text(
              label,
              style: AppTextStyles.labelSmall(
                context,
                fontWeight: AppTextSize.medium,
              ),
            ),
          ],
        ),
        AppSpacing.gapXXS,
        Text(
          value,
          style: AppTextStyles.titleMedium(
            context,
            fontWeight: AppTextSize.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}