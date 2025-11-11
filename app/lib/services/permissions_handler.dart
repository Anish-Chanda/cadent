import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationPermissionService {
  static final GeolocatorPlatform _geolocatorPlatform = GeolocatorPlatform.instance;

  /// Checks if location services are enabled and permissions are granted
  /// Returns true if everything is ready for location access
  static Future<bool> hasLocationPermission() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await _geolocatorPlatform.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }

      // Check current permission status
      LocationPermission permission = await _geolocatorPlatform.checkPermission();
      
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
  static Future<bool> requestLocationPermission({BuildContext? context}) async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await _geolocatorPlatform.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (context != null && context.mounted) {
          //TODO: create a centralized way to show these messages
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location services are disabled. Please enable them in settings.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return false;
      }

      // Check current permission status
      LocationPermission permission = await _geolocatorPlatform.checkPermission();
      
      // If already granted, return true
      if (permission == LocationPermission.whileInUse || 
          permission == LocationPermission.always) {
        return true;
      }

      // If denied, request permission
      if (permission == LocationPermission.denied) {
        permission = await _geolocatorPlatform.requestPermission();
        
        if (permission == LocationPermission.denied) {
          if (context != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission is required to track your activity.'),
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
              content: Text('Location permission permanently denied. Please enable in app settings.'),
              duration: Duration(seconds: 4),
            ),
          );
        }
        return false;
      }

      // Check final permission status
      return permission == LocationPermission.whileInUse || 
             permission == LocationPermission.always;
    } catch (e) {
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

  /// Gets the current location permission status without requesting
  static Future<LocationPermission> getPermissionStatus() async {
    return await _geolocatorPlatform.checkPermission();
  }

  /// Opens app settings for the user to manually grant permissions
  static Future<bool> openAppSettings() async {
    return await _geolocatorPlatform.openAppSettings();
  }
}