import 'dart:developer';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

class LocationPermissionService {
  static const String _temporaryFullAccuracyPurposeKey =
      'ActivityRecordingPreciseLocation';
  static const MethodChannel _trackingPermissionsChannel = MethodChannel(
    'cadent/tracking_permissions',
  );

  /// Checks if location services are enabled and permissions are granted
  /// Returns true if everything is ready for location access
  static Future<bool> hasLocationPermission() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await GeolocatorPlatform.instance
          .isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }

      // Check current permission status
      LocationPermission permission = await GeolocatorPlatform.instance
          .checkPermission();

      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (e) {
      log('Error checking location permissions: $e');
      return false;
    }
  }

  /// Requests location permissions and handles the full flow
  /// Returns true if permissions are granted, false otherwise
  /// Shows user-friendly error messages via context
  static Future<bool> requestLocationPermission({
    BuildContext? context,
    bool requirePrecise = false,
  }) async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await GeolocatorPlatform.instance
          .isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (context != null && context.mounted) {
          //TODO: create a centralized way to show these messages
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location services are disabled. Please enable them in settings.',
              ),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return false;
      }

      // Check current permission status
      LocationPermission permission = await GeolocatorPlatform.instance
          .checkPermission();

      // If already granted, return true
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        return true;
      }

      // If denied, request permission
      if (permission == LocationPermission.denied) {
        permission = await GeolocatorPlatform.instance.requestPermission();

        if (permission == LocationPermission.denied) {
          if (context != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Location permission is required to track your activity.',
                ),
                duration: Duration(seconds: 3),
              ),
            );
          }
          return false;
        }
      }

      // If denied forever, show settings message
      if (permission == LocationPermission.deniedForever) {
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission permanently denied. Please enable in app settings.',
              ),
              duration: Duration(seconds: 4),
            ),
          );
        }
        return false;
      }

      // Check final permission status
      final hasForegroundLocation =
          permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;

      if (!hasForegroundLocation) return false;

      if (requirePrecise) {
        if (context != null && !context.mounted) return false;
        return await requestPreciseLocation(context: context);
      }

      return true;
    } catch (e) {
      log('Error requesting location permission: $e');
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error checking location permissions.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return false;
    }
  }

  /// Ensures the app has precise location when the OS exposes an approximate
  /// location option. Returns true if precise access is available.
  static Future<bool> requestPreciseLocation({BuildContext? context}) async {
    try {
      var accuracy = await GeolocatorPlatform.instance.getLocationAccuracy();
      if (accuracy == LocationAccuracyStatus.precise) return true;

      if (Platform.isIOS) {
        accuracy = await GeolocatorPlatform.instance
            .requestTemporaryFullAccuracy(
              purposeKey: _temporaryFullAccuracyPurposeKey,
            );
        if (accuracy == LocationAccuracyStatus.precise) return true;
      }

      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Precise location is needed for accurate activity tracking.',
            ),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () {
                GeolocatorPlatform.instance.openAppSettings();
              },
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return false;
    } catch (e) {
      log('Error checking precise location permission: $e');
      return false;
    }
  }

  /// Requests Android 13+ notification permission so the foreground tracking
  /// service can show a visible ongoing notification.
  static Future<bool> requestTrackingNotificationPermission({
    BuildContext? context,
  }) async {
    if (!Platform.isAndroid) return true;

    try {
      final granted =
          await _trackingPermissionsChannel.invokeMethod<bool>(
            'requestPostNotificationsPermission',
          ) ??
          true;

      if (!granted && context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Notifications are needed to show that tracking is active in the background.',
            ),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () {
                _trackingPermissionsChannel.invokeMethod<bool>(
                  'openNotificationSettings',
                );
              },
            ),
            duration: const Duration(seconds: 6),
          ),
        );
      }

      return granted;
    } catch (e) {
      log('Error requesting tracking notification permission: $e');
      return true;
    }
  }

  /// Requests an Android battery optimization exemption for reliable long
  /// activity tracking while the screen is off.
  static Future<bool> requestTrackingBatteryOptimizationExemption({
    BuildContext? context,
  }) async {
    if (!Platform.isAndroid) return true;

    try {
      final isAlreadyExempt =
          await _trackingPermissionsChannel.invokeMethod<bool>(
            'isIgnoringBatteryOptimizations',
          ) ??
          true;
      if (isAlreadyExempt) return true;

      if (context != null && context.mounted) {
        final shouldRequest = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Allow Background Tracking'),
            content: const Text(
              'To keep recording longer activities after the screen is off, allow Cadent to run without battery optimization.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Not now'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Allow'),
              ),
            ],
          ),
        );

        if (shouldRequest != true) return false;
      }

      await _trackingPermissionsChannel.invokeMethod<bool>(
        'requestIgnoreBatteryOptimizations',
      );

      return await _trackingPermissionsChannel.invokeMethod<bool>(
            'isIgnoringBatteryOptimizations',
          ) ??
          true;
    } catch (e) {
      log('Error requesting battery optimization exemption: $e');
      return false;
    }
  }

  /// Gets the current location permission status without requesting
  static Future<LocationPermission> getPermissionStatus() async {
    return await GeolocatorPlatform.instance.checkPermission();
  }

  /// Opens app settings for the user to manually grant permissions
  static Future<bool> openAppSettings() async {
    return await GeolocatorPlatform.instance.openAppSettings();
  }
}
