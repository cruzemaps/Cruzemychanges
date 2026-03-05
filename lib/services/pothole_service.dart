import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';

class PotholeService {
  static final PotholeService _instance = PotholeService._internal();
  static PotholeService get instance => _instance;
  PotholeService._internal();

  StreamSubscription<UserAccelerometerEvent>? _accelerometerSubscription;
  DateTime? _lastPotholeTime;
  final String _baseUrl = kIsWeb 
      ? "https://unmaternal-parthenia-oarless.ngrok-free.app" 
      : (defaultTargetPlatform == TargetPlatform.android ? "http://10.0.2.2:7071" : "https://unmaternal-parthenia-oarless.ngrok-free.app");

  void startMonitoring() {
    print("Pothole Monitor Log: Monitoring Started");
    _accelerometerSubscription = userAccelerometerEvents.listen((UserAccelerometerEvent event) {
      // Calculate total G-Force (Vertical shock mostly in Z, but total magnitude is robust)
      double gForce = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

      // Threshold: > 2.5g indicates a significant shock (e.g. Pothole)
      // Ignoring small bumps (< 2.0g)
      if (gForce > 2.5) {
        DateTime now = DateTime.now();
        // Debounce: Avoid multiple reports for same pothole (1 second)
        if (_lastPotholeTime == null || now.difference(_lastPotholeTime!) > const Duration(seconds: 1)) {
           _lastPotholeTime = now;
           _reportPothole(gForce);
        }
      }
    });
  }

  Future<void> _reportPothole(double severity) async {
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      
      print('🕳️ POTHOLE DETECTED: ${severity.toStringAsFixed(1)}g');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/api/telemetry/pothole'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'lat': position.latitude,
          'lon': position.longitude,
          'severity': severity,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
      
      if (response.statusCode == 200) {
        print("Pothole reported successfully");
      }
    } catch (e) {
      print("Error reporting pothole: $e");
    }
  }

  void stopMonitoring() {
    _accelerometerSubscription?.cancel();
  }
}
