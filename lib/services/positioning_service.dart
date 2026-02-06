import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class PositioningService {
  static final PositioningService _instance = PositioningService._internal();
  static PositioningService get instance => _instance;
  PositioningService._internal();

  final String _baseUrl = kIsWeb
      ? "http://localhost:7071"
      : (defaultTargetPlatform == TargetPlatform.android
          ? "http://10.0.2.2:7071"
          : "http://127.0.0.1:7071");

  final StreamController<Map<String, dynamic>> _laneStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get laneStream => _laneStreamController.stream;

  DateTime _lastRequest = DateTime.fromMillisecondsSinceEpoch(0);
  Map<String, dynamic>? _lastLaneMatch;

  void updatePosition(Position position) {
    final now = DateTime.now();
    if (now.difference(_lastRequest).inSeconds < 2) {
      return;
    }
    _lastRequest = now;
    _fetchLaneMatch(position);
  }

  Future<void> _fetchLaneMatch(Position position) async {
    try {
      final payload = {
        "lat": position.latitude,
        "lon": position.longitude,
        "heading": position.heading,
        "speed_mps": position.speed
      };
      final response = await http.post(
        Uri.parse("$_baseUrl/api/lane_match"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(payload),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _lastLaneMatch = data;
        _laneStreamController.add(data);
      }
    } catch (e) {
      debugPrint("PositioningService error: $e");
    }
  }

  Map<String, dynamic>? get lastLaneMatch => _lastLaneMatch;
}
