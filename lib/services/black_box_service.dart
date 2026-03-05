import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class BlackBoxService {
  static final BlackBoxService _instance = BlackBoxService._internal();
  static BlackBoxService get instance => _instance;
  BlackBoxService._internal();

  final String _baseUrl = kIsWeb 
      ? "https://unmaternal-parthenia-oarless.ngrok-free.app" 
      : (defaultTargetPlatform == TargetPlatform.android ? "http://10.0.2.2:7071" : "https://unmaternal-parthenia-oarless.ngrok-free.app");

  // Circular Buffer: Store last 300 points (assuming 10Hz = 30 seconds)
  final Queue<Map<String, dynamic>> _logBuffer = Queue<Map<String, dynamic>>();
  final int _bufferSize = 300;
  Timer? _recordingTimer;

  void startRecording() {
    print("Black Box Recording Started");
    _recordingTimer?.cancel();
    // Record telemetry every 100ms (10Hz)
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
       try {
         // Using cached location for speed or last known
         // In a real app we'd listen to streams, but polling Position for "last known" is cheaper for this mock
         // Note: requestPermission not handled here, assuming MapScreen did it
         if (await Geolocator.isLocationServiceEnabled()) {
            Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.bestForNavigation);
            _addLogEntry(pos);
         }
       } catch (e) {
         // Silent fail
       }
    });
  }

  void _addLogEntry(Position pos) {
    if (_logBuffer.length >= _bufferSize) {
      _logBuffer.removeFirst();
    }
    _logBuffer.add({
      'lat': pos.latitude,
      'lon': pos.longitude,
      'speed': pos.speed,
      'heading': pos.heading,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<void> triggerUpload() async {
    print("🚨 BLACK BOX TRIGGERED: Uploading Forensic Log...");
    try {
      final List<Map<String, dynamic>> logDump = _logBuffer.toList();
      
      final response = await http.post(
        Uri.parse('$_baseUrl/api/blackbox/upload'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'timestamp': DateTime.now().toIso8601String(),
          'log': logDump,
          'device_id': 'demo_device_001'
        }),
      );
      
      if (response.statusCode == 200) {
        print("📦 Black Box Log Secured in Cloud.");
      } else {
        print("Failed to upload black box: ${response.statusCode}");
      }
    } catch (e) {
      print("Error uploading black box: $e");
    }
  }

  void stopRecording() {
    _recordingTimer?.cancel();
  }
}
