import 'package:cadence/services/permissions_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// Create a mock implementation of the GeolocatorPlatform
// This allows us to fake the responses from the geolocator plugin
class MockGeolocator extends Fake
    with MockPlatformInterfaceMixin
    implements GeolocatorPlatform {
  bool isLocationServiceEnabledResult = true;
  LocationPermission checkPermissionResult = LocationPermission.denied;
  LocationPermission requestPermissionResult = LocationPermission.denied;
  bool openAppSettingsResult = true;

  @override
  Future<bool> isLocationServiceEnabled() async {
    return isLocationServiceEnabledResult;
  }

  @override
  Future<LocationPermission> checkPermission() async {
    return checkPermissionResult;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    return requestPermissionResult;
  }

  @override
  Future<bool> openAppSettings() async {
    return openAppSettingsResult;
  }
}

void main() {
  late MockGeolocator mockGeolocator;

  // setUp is called before each test, ensuring a fresh mock for each scenario
  setUp(() {
    mockGeolocator = MockGeolocator();
    // Directly setting the instance is the standard way to test platform interfaces
    GeolocatorPlatform.instance = mockGeolocator;
  });

  group('LocationPermissionService Tests', () {
    group('hasLocationPermission', () {
      test('returns true when permission is whileInUse', () async {
        mockGeolocator.checkPermissionResult = LocationPermission.whileInUse;
        expect(await LocationPermissionService.hasLocationPermission(), isTrue);
      });

      test('returns true when permission is always', () async {
        mockGeolocator.checkPermissionResult = LocationPermission.always;
        expect(await LocationPermissionService.hasLocationPermission(), isTrue);
      });

      test('returns false when location services are disabled', () async {
        mockGeolocator.isLocationServiceEnabledResult = false;
        expect(await LocationPermissionService.hasLocationPermission(), isFalse);
      });

      test('returns false when permission is denied', () async {
        mockGeolocator.checkPermissionResult = LocationPermission.denied;
        expect(await LocationPermissionService.hasLocationPermission(), isFalse);
      });
    });

    group('requestLocationPermission', () {
      test('returns true if permission is already granted', () async {
        mockGeolocator.checkPermissionResult = LocationPermission.always;
        expect(await LocationPermissionService.requestLocationPermission(), isTrue);
      });

      test('returns false if location services are disabled', () async {
        mockGeolocator.isLocationServiceEnabledResult = false;
        expect(await LocationPermissionService.requestLocationPermission(), isFalse);
      });

      test('requests permission and returns true if granted', () async {
        mockGeolocator.checkPermissionResult = LocationPermission.denied;
        mockGeolocator.requestPermissionResult = LocationPermission.whileInUse;

        final result = await LocationPermissionService.requestLocationPermission();

        expect(result, isTrue);
      });

      test('requests permission and returns false if denied', () async {
        mockGeolocator.checkPermissionResult = LocationPermission.denied;
        mockGeolocator.requestPermissionResult = LocationPermission.denied;

        final result = await LocationPermissionService.requestLocationPermission();

        expect(result, isFalse);
      });

      test('returns false if permission is permanently denied', () async {
        mockGeolocator.checkPermissionResult = LocationPermission.deniedForever;

        final result = await LocationPermissionService.requestLocationPermission();

        expect(result, isFalse);
      });
    });

    group('getPermissionStatus', () {
      test('returns the correct permission status', () async {
        mockGeolocator.checkPermissionResult = LocationPermission.deniedForever;
        final status = await LocationPermissionService.getPermissionStatus();
        expect(status, LocationPermission.deniedForever);
      });
    });

    group('openAppSettings', () {
      test('calls openAppSettings and returns the result', () async {
        mockGeolocator.openAppSettingsResult = true;
        final result = await LocationPermissionService.openAppSettings();
        expect(result, isTrue);

        mockGeolocator.openAppSettingsResult = false;
        final secondResult = await LocationPermissionService.openAppSettings();
        expect(secondResult, isFalse);
      });
    });
  });
}
