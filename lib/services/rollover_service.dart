import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class RolloverService {
  static final RolloverService _instance = RolloverService._internal();
  static RolloverService get instance => _instance;
  RolloverService._internal();

  final String _baseUrl = kIsWeb 
      ? "http://192.168.1.107:7071" 
      : (defaultTargetPlatform == TargetPlatform.android ? "http://10.0.2.2:7071" : "http://192.168.1.107:7071");

  Timer? _pollingTimer;
  Map<String, dynamic>? _currentRoadData;
  final StreamController<bool> _alertController = StreamController<bool>.broadcast();
  Stream<bool> get alertStream => _alertController.stream;

  void startMonitoring() {
    print("G-Force Guardian (Rollover) Started");
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
       _fetchCurvature();
    });
    // Check risk frequently
    Timer.periodic(const Duration(seconds: 1), (timer) async {
       if (_currentRoadData != null) {
          await _checkRisk();
       }
    });
  }

  Future<void> _fetchCurvature() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/roads/curvature'));
      if (response.statusCode == 200) {
        _currentRoadData = json.decode(response.body);
      }
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> _checkRisk() async {
     try {
       if (await Geolocator.isLocationServiceEnabled()) {
          Position pos = await Geolocator.getCurrentPosition();
          double speedMps = pos.speed; // m/s
          double speedMph = speedMps * 2.23694;
          
          double radius = _currentRoadData!['radius']; // meters
          // Centripetal Acceleration: a = v^2 / r
          double accel = (speedMps * speedMps) / radius;
          double gForce = accel / 9.81;

          // Threshold: 0.3g is risky for top-heavy trucks
          if (gForce > 0.3) {
             print("⚠️ ROLLOVER RISK! ${gForce.toStringAsFixed(2)}g (Speed: ${speedMph.toStringAsFixed(1)} mph)");
             _alertController.add(true);
          } else {
             _alertController.add(false);
          }
       }
     } catch (e) {
       // Silent fail
     }
  }

  void stopMonitoring() {
    _pollingTimer?.cancel();
  }
}
