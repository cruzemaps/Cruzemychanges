import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';

class SignalGlideService {
  // Singleton
  static final SignalGlideService _instance = SignalGlideService._internal();
  static SignalGlideService get instance => _instance;
  SignalGlideService._internal();

  Timer? _pollingTimer;
  Map<String, dynamic>? _currentSignalData;
  final String _baseUrl = kIsWeb 
      ? "http://192.168.1.107:7071" 
      : (defaultTargetPlatform == TargetPlatform.android ? "http://10.0.2.2:7071" : "http://192.168.1.107:7071");

  final StreamController<Map<String, dynamic>> _signalStreamController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get signalStream => _signalStreamController.stream;
  String? _laneId;
  double? _laneConfidence;

  void startPolling(LatLng currentPos) {
    stopPolling();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _fetchSignalData(currentPos);
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
  }

  void updateLaneContext({String? laneId, double? confidence}) {
    _laneId = laneId;
    _laneConfidence = confidence;
  }

  Future<void> _fetchSignalData(LatLng pos) async {
    try {
      final laneParam = (_laneId != null && (_laneConfidence ?? 0) >= 0.6)
          ? "&lane_id=$_laneId"
          : "";
      final response = await http.get(Uri.parse('$_baseUrl/api/signals?lat=${pos.latitude}&lon=${pos.longitude}$laneParam'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _currentSignalData = data;
        _signalStreamController.add(data);
      }
    } catch (e) {
      print("SignalGlide Error: $e");
    }
  }
}
