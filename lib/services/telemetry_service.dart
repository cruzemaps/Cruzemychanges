import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'positioning_service.dart'; // To get location if available or we can use geolocator directly

// Foreground task callback
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(TelemetryTaskHandler());
}

class TelemetryTaskHandler extends TaskHandler {
  MqttServerClient? mqttClient;
  Timer? _telemetryTimer;
  double _lat = 0.0;
  double _lon = 0.0;
  double _heading = 0.0;
  double _speed = 0.0;
  String clientId = 'cruze_truck_${DateTime.now().millisecondsSinceEpoch}';

  @override
  void onStart(DateTime timestamp, SendPort? sendPort) async {
    print('🚗 Telemetry Task Started: $clientId');

    // 1. Connect MQTT
    await _connectMqtt();

    // 2. Start 5Hz Telemetry Loop (Every 200ms)
    _telemetryTimer =
        Timer.periodic(const Duration(milliseconds: 200), (timer) {
      _sendTelemetry();
    });
  }

  Future<void> _connectMqtt() async {
    // Note: In dev we use a public broker or a local mosquitto.
    // For iOS simulator to Mac localhost use 127.0.0.1, Android emulator use 10.0.2.2.
    // For now we use the public test.mosquitto.org for easy zero-setup testing.
    mqttClient = MqttServerClient('test.mosquitto.org', clientId);
    mqttClient!.port = 1883;
    mqttClient!.logging(on: false);
    mqttClient!.keepAlivePeriod = 20;

    final connMess = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .withWillTopic('cruze/trucks/disconnect')
        .withWillMessage(clientId)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    mqttClient!.connectionMessage = connMess;

    try {
      print('MQTT client connecting....');
      await mqttClient!.connect();
    } catch (e) {
      print('Exception: $e');
      mqttClient!.disconnect();
    }

    if (mqttClient!.connectionStatus!.state == MqttConnectionState.connected) {
      print('✅ MQTT client connected!');
    } else {
      print('❌ ERROR MQTT client connection failed');
    }
  }

  void _sendTelemetry() {
    if (mqttClient?.connectionStatus?.state != MqttConnectionState.connected)
      return;

    // Simulate slight movement or grab from a real Location provider
    // If we had the real positioning service instance here we would read from it.
    // For background isolation, we can request location directly or mock it for the matrix testing.

    // For the Bipartite Matching test, we'll simulate a truck driving on I-35
    // (mocking coords around the highway camera views)
    _lat += 0.00001; // Moving slightly
    _lon += 0.00001;
    _speed = 65.0; // mph mock

    final payloadStr = jsonEncode({
      'id': clientId,
      'lat': _lat,
      'lon': _lon,
      'heading': _heading,
      'speed': _speed,
      'accel': 0.0,
      'timestamp': DateTime.now().toIso8601String(),
    });

    final builder = MqttClientPayloadBuilder();
    builder.addString(payloadStr);

    mqttClient!.publishMessage(
        'cruze/telemetry/trucks', MqttQos.atMostOnce, builder.payload!);

    // Update Notification
    FlutterForegroundTask.updateService(
      notificationTitle: 'Cruze V-OBU Active',
      notificationText: 'Streaming at 5Hz - Speed: ${_speed.toInt()} mph',
    );
  }

  @override
  void onRepeatEvent(DateTime timestamp, SendPort? sendPort) {
    // Background task tick (ForegroundService runs this every interval configured)
  }

  @override
  void onDestroy(DateTime timestamp, SendPort? sendPort) {
    print('Telemetry Task Destroyed');
    _telemetryTimer?.cancel();
    mqttClient?.disconnect();
  }
}

class TelemetryService {
  static final TelemetryService _instance = TelemetryService._internal();
  factory TelemetryService() => _instance;
  TelemetryService._internal();

  bool _isInitialized = false;

  Future<void> initForegroundTask() async {
    if (_isInitialized) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'cruze_foreground_service',
        channelName: 'Cruze Telemetry',
        channelDescription: 'Maintains Virtual OBU connection',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 1000,
        isOnceEvent: false,
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    _isInitialized = true;
  }

  Future<void> requestPermissions() async {
    NotificationPermission notificationPermissionStatus =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermissionStatus != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (Platform.isAndroid) {
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    }
  }

  Future<void> startService() async {
    if (await FlutterForegroundTask.isRunningService) return;

    await FlutterForegroundTask.startService(
      notificationTitle: 'Cruze Background Sync',
      notificationText: 'Initializing V-OBU...',
      callback: startCallback,
    );
  }

  Future<void> stopService() async {
    await FlutterForegroundTask.stopService();
  }
}
