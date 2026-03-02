import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../utils/app_theme.dart';

/// Map view widget for the recorder screen.
/// Displays a MapLibre map with user location tracking.
/// Automatically uses dark map style when in dark mode.
class RecordingMapView extends StatelessWidget {
  final Function(MapLibreMapController) onMapCreated;
  final List<Position>? positions;

  const RecordingMapView({
    super.key,
    required this.onMapCreated,
    this.positions,
  });

  @override
  Widget build(BuildContext context) {
    return MapLibreMap(
      styleString: AppTheme.getMapStyle(context),
      initialCameraPosition: const CameraPosition(
        target: LatLng(37.7749, -122.4194), // Default to San Francisco
        zoom: 14.0,
      ),
      myLocationEnabled: true,
      myLocationTrackingMode: MyLocationTrackingMode.tracking,
      myLocationRenderMode: MyLocationRenderMode.normal,
      onMapCreated: (MapLibreMapController controller) async {
        log('Map controller created');

        // Try to get current location first
        try {
          final currentLocation = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 10),
            ),
          );

          // Move camera to current location
          await controller.moveCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(currentLocation.latitude, currentLocation.longitude),
              16.0,
            ),
          );
        } catch (e) {
          log('Failed to get current location: $e');

          // Fallback to recorded positions if available
          if (positions != null && positions!.isNotEmpty) {
            final lastLocation = positions!.last;
            log('Using last recorded position: ${lastLocation.latitude}, ${lastLocation.longitude}');
            await controller.moveCamera(
              CameraUpdate.newLatLngZoom(
                LatLng(lastLocation.latitude, lastLocation.longitude),
                16.0,
              ),
            );
          } else {
            log('No recorded positions available, staying at default location');
          }
        }

        onMapCreated(controller);
      },
    );
  }
}
