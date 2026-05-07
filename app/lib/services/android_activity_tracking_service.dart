import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

class AndroidActivityTrackingService {
  AndroidActivityTrackingService._();

  static const MethodChannel _methodChannel = MethodChannel(
    'cadent/activity_tracking_service',
  );
  static const EventChannel _eventChannel = EventChannel(
    'cadent/activity_tracking_events',
  );

  static Stream<Map<String, dynamic>>? _events;

  static bool get isSupported => Platform.isAndroid;

  static Stream<Map<String, dynamic>> get events {
    _events ??= _eventChannel.receiveBroadcastStream().map((event) {
      return Map<String, dynamic>.from(event as Map);
    });
    return _events!;
  }

  static Future<bool> start({
    required String activityType,
    required String activityName,
    required bool useMetricUnits,
  }) async {
    if (!isSupported) return false;

    return await _methodChannel.invokeMethod<bool>('start', {
          'activityType': activityType,
          'activityName': activityName,
          'useMetricUnits': useMetricUnits,
        }) ??
        false;
  }

  static Future<bool> pause() async {
    if (!isSupported) return false;
    return await _methodChannel.invokeMethod<bool>('pause') ?? false;
  }

  static Future<bool> resume() async {
    if (!isSupported) return false;
    return await _methodChannel.invokeMethod<bool>('resume') ?? false;
  }

  static Future<bool> stop() async {
    if (!isSupported) return false;
    return await _methodChannel.invokeMethod<bool>('stop') ?? false;
  }

  static Future<Map<String, dynamic>?> getSnapshot() async {
    if (!isSupported) return null;

    final snapshot = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      'getSnapshot',
    );
    if (snapshot == null) return null;
    return Map<String, dynamic>.from(snapshot);
  }
}
