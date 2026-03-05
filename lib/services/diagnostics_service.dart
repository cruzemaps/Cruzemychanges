import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class DiagnosticsService {
  static final DiagnosticsService _instance = DiagnosticsService._internal();
  static DiagnosticsService get instance => _instance;
  DiagnosticsService._internal();

  StreamSubscription<UserAccelerometerEvent>? _accelerometerSubscription;
  final String _baseUrl = kIsWeb 
      ? "http://100.66.61.24:7071" 
      : (defaultTargetPlatform == TargetPlatform.android ? "http://10.0.2.2:7071" : "http://100.66.61.24:7071");

  List<double> _jerkHistory = [];
  UserAccelerometerEvent? _lastEvent;
  DateTime? _lastLogTime;

  void startMonitoring() {
    print("Diagnostics (Sonic) Monitor Started");
    _accelerometerSubscription = userAccelerometerEvents.listen((UserAccelerometerEvent event) {
      if (_lastEvent != null) {
        // Calculate Jerk: Change in Acceleration over time (assuming roughly constant sample rate)
        // Simple Euclidean distance between accel vectors
        double deltaAccel = sqrt(
          pow(event.x - _lastEvent!.x, 2) +
          pow(event.y - _lastEvent!.y, 2) +
          pow(event.z - _lastEvent!.z, 2)
        );
        
        // Add to rolling history (keep last 100 samples ~ 1-2 seconds)
        _jerkHistory.add(deltaAccel);
        if (_jerkHistory.length > 100) {
          _jerkHistory.removeAt(0);
        }

        // Analyze Vibration Health (High constant jerk = mechanical issue)
        _analyzeVibration();
      }
      _lastEvent = event;
    });
  }

  void _analyzeVibration() {
    if (_jerkHistory.length < 50) return;

    // Average Jerk score
    double avgJerk = _jerkHistory.reduce((a, b) => a + b) / _jerkHistory.length;
    
    // Threshold: purely experimental. 
    // Normal driving is smooth (< 0.5 mostly). 
    // Bad suspension or flat tire might cause constant > 1.0 jitter.
    double threshold = 1.5;

    DateTime now = DateTime.now();
    if (avgJerk > threshold) {
       if (_lastLogTime == null || now.difference(_lastLogTime!) > const Duration(minutes: 1)) {
         _lastLogTime = now;
         _reportAnomaly(avgJerk, threshold);
       }
    }
  }

  Future<void> _reportAnomaly(double score, double threshold) async {
    try {
      print('🔊 SONIC DIAGNOSTICS: Vibration Anomaly Detected! Score: ${score.toStringAsFixed(2)}');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/api/diagnostics/log'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'score': score.toStringAsFixed(2),
          'threshold': threshold,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
      
      if (response.statusCode == 200) {
        print("Vibration anomaly logged.");
      }
    } catch (e) {
      print("Error reporting diagnostics: $e");
    }
  }

  void stopMonitoring() {
    _accelerometerSubscription?.cancel();
  }
}
