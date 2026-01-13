import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';

class LaneService {
  static final LaneService _instance = LaneService._internal();
  static LaneService get instance => _instance;
  LaneService._internal();

  Timer? _pollingTimer;
  final String _baseUrl = kIsWeb 
      ? "http://localhost:7071" 
      : (defaultTargetPlatform == TargetPlatform.android ? "http://10.0.2.2:7071" : "http://127.0.0.1:7071");

  final StreamController<Map<String, dynamic>> _laneController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get laneStream => _laneController.stream;

  void startPolling(LatLng pos) {
    stopPolling();
    // Poll every 5s
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchLaneAdvice(pos);
    });
    // Fetch immediately
    _fetchLaneAdvice(pos);
  }

  void stopPolling() {
    _pollingTimer?.cancel();
  }

  Future<void> _fetchLaneAdvice(LatLng pos) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/lanes?lat=${pos.latitude}&lon=${pos.longitude}'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _laneController.add(data);
      }
    } catch (e) {
      print("Lane Service Error: $e");
    }
  }
}
