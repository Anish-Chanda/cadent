import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

class NavigationIntentService {
  NavigationIntentService._();

  static const EventChannel _eventChannel = EventChannel(
    'cadent/navigation_events',
  );

  static Stream<String>? _targets;

  static Stream<String> get targets {
    if (!Platform.isAndroid) return const Stream.empty();

    _targets ??= _eventChannel.receiveBroadcastStream().map((event) {
      final data = Map<String, dynamic>.from(event as Map);
      return data['target'] as String;
    });
    return _targets!;
  }
}
