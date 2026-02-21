import 'dart:async';
import 'dart:ui';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../services/storage_service.dart';

void startBackgroundService() {
  final service = FlutterBackgroundService();
  service.startService();
}

void stopBackgroundService() {
  final service = FlutterBackgroundService();
  service.invoke("stop");
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
    androidConfiguration: AndroidConfiguration(
      autoStart: true,
      onStart: onStart,
      isForegroundMode: true,
      autoStartOnBoot: true,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {

  final serverUrl = await StorageService.getServerUrl() ?? "http://cadence.local";

  final socket = io.io(serverUrl, {
    'transports': ['websocket'],
    'autoConnect': true,
  });

  socket.onConnect((_) {
    print('Connected: ${socket.id}');
  });

  service.on('location_update').listen((data) {
    if (data == null) return;

    socket.emit('gps_point', {
      'lat': data['lat'],
      'lng': data['lng'],
      'time': data['time'],
    });
  });

  service.on("stop").listen((_) {
    socket.dispose();
    service.stopSelf();
  });
}
