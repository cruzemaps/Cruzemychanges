import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cruze_mobile/models/crash_classification.dart';
import 'package:cruze_mobile/config/app_config.dart';
import 'package:cruze_mobile/services/black_box_service.dart';
import 'package:cruze_mobile/services/acoustic_service.dart';

/// Accelerometer sample with timestamp
class AccelSample {
  final double x;
  final double y;
  final double z;
  final DateTime timestamp;
  
  AccelSample(this.x, this.y, this.z, this.timestamp);
  
  double get magnitude => sqrt(x * x + y * y + z * z);
  
  Vector3 toVector() => Vector3(x, y, z);
  
  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'z': z,
    'timestamp': timestamp.millisecondsSinceEpoch,
  };
}

/// Delta-V calculator using double integration
class DeltaVCalculator {
  static const Duration windowDuration = Duration(milliseconds: 250);
  final Queue<AccelSample> _buffer = Queue<AccelSample>();
  
  /// Add sample to sliding window
  void addSample(AccelSample sample) {
    _buffer.add(sample);
    
    // Remove samples older than window duration
    final cutoffTime = sample.timestamp.subtract(windowDuration);
    while (_buffer.isNotEmpty && _buffer.first.timestamp.isBefore(cutoffTime)) {
      _buffer.removeFirst();
    }
  }
  
  /// Calculate Delta-V using double integration
  /// This filters out "rattle noise" from loose phones
  double calculateDeltaV() {
    if (_buffer.length < 2) return 0.0;
    
    double totalVelocityChange = 0.0;
    
    // Integrate acceleration over time to get velocity change
    for (int i = 1; i < _buffer.length; i++) {
      final prev = _buffer.elementAt(i - 1);
      final curr = _buffer.elementAt(i);
      
      // Time delta in seconds
      final dt = curr.timestamp.difference(prev.timestamp).inMicroseconds / 1000000.0;
      
      // Average acceleration between samples (trapezoidal integration)
      final avgAccel = (prev.magnitude + curr.magnitude) / 2.0;
      
      // Velocity change = acceleration * time
      totalVelocityChange += avgAccel * dt;
    }
    
    return totalVelocityChange;
  }
  
  /// Get samples from first 50ms of window
  List<AccelSample> getFirst50ms() {
    if (_buffer.isEmpty) return [];
    
    final startTime = _buffer.first.timestamp;
    final cutoffTime = startTime.add(const Duration(milliseconds: 50));
    
    return _buffer.where((sample) => sample.timestamp.isBefore(cutoffTime)).toList();
  }
  
  void clear() {
    _buffer.clear();
  }
}

/// Orientation lock - captures impact vector in first 50ms
class OrientationLock {
  /// Extract impact vector from first 50ms of data
  /// During this window, phone hasn't started tumbling yet
  static Vector3 captureImpactVector(List<AccelSample> first50ms) {
    if (first50ms.isEmpty) return const Vector3(0, 0, 0);
    
    // Average the acceleration vectors in the first 50ms
    double sumX = 0, sumY = 0, sumZ = 0;
    
    for (var sample in first50ms) {
      sumX += sample.x;
      sumY += sample.y;
      sumZ += sample.z;
    }
    
    final count = first50ms.length;
    return Vector3(sumX / count, sumY / count, sumZ / count);
  }
}

/// Main tri-sensor crash detection service
class CrashDetectionService {
  static final CrashDetectionService _instance = CrashDetectionService._internal();
  static CrashDetectionService get instance => _instance;
  CrashDetectionService._internal();
  
  StreamSubscription<UserAccelerometerEvent>? _accelerometerSubscription;
  final DeltaVCalculator _deltaVCalculator = DeltaVCalculator();
  
  bool _isMonitoring = false;
  Position? _lastPosition;
  double _lastSpeed = 0.0;
  double _lastHeading = 0.0;
  
  // Crash detection threshold (m/s)
  static const double crashThreshold = 5.0;
  
  // Cooldown to prevent multiple detections
  DateTime? _lastCrashTime;
  static const Duration crashCooldown = Duration(seconds: 10);
  
  void startMonitoring() {
    if (_isMonitoring) return;
    
    print('🔬 Tri-Sensor Crash Detection Started');
    print('   Layer 1: Delta-V Analysis (250ms window)');
    print('   Layer 2: Acoustic Fingerprinting (2-4kHz metal, 5-15kHz glass)');
    print('   Layer 3: Orientation Lock (First 50ms)');
    
    _isMonitoring = true;
    
    // Start acoustic fingerprinting
    AcousticService.instance.startListening();
    
    // Start location tracking
    _trackLocation();
    
    // Listen to accelerometer at high frequency
    _accelerometerSubscription = userAccelerometerEventStream().listen((event) {
      _processSample(event);
    });
  }
  
  void _trackLocation() async {
    // Update location periodically
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        if (await Geolocator.isLocationServiceEnabled()) {
          _lastPosition = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.bestForNavigation,
          );
          _lastSpeed = _lastPosition!.speed;
          _lastHeading = _lastPosition!.heading;
        }
      } catch (e) {
        // Ignore location errors
      }
    });
  }
  
  void _processSample(UserAccelerometerEvent event) {
    final sample = AccelSample(event.x, event.y, event.z, DateTime.now());
    
    // Add to Delta-V calculator
    _deltaVCalculator.addSample(sample);
    
    // Calculate current Delta-V
    final deltaV = _deltaVCalculator.calculateDeltaV();
    
    // Check for crash
    if (deltaV.abs() > crashThreshold) {
      _detectCrash(deltaV);
    }
  }
  
  void _detectCrash(double deltaV) async {
    // Check cooldown
    if (_lastCrashTime != null) {
      if (DateTime.now().difference(_lastCrashTime!) < crashCooldown) {
        return; // Still in cooldown
      }
    }
    
    _lastCrashTime = DateTime.now();
    
    print('🚨 CRASH DETECTED! Delta-V: ${deltaV.toStringAsFixed(2)} m/s');
    
    // Layer 3: Capture first 50ms orientation lock
    final first50ms = _deltaVCalculator.getFirst50ms();
    final impactVector = OrientationLock.captureImpactVector(first50ms);
    
    print('   Impact Vector: $impactVector');
    
    // Layer 2: Acoustic signature
    // Trigger acoustic analysis on crash detection
    final acoustic = await AcousticService.instance.detectCrashSound();
    
    if (acoustic != null) {
      print('   🎤 Acoustic Signature Detected:');
      print('      Metal Screech (2-4kHz): ${acoustic.metalScreech}');
      print('      Glass Shatter (5-15kHz): ${acoustic.glassShatter}');
      print('      Structural Crunch: ${acoustic.structuralCrunch}');
    }
    
    // Classify crash
    final classification = CrashClassifier.classify(
      deltaV: deltaV,
      impactVector: impactVector,
      acoustic: acoustic,
      velocityBefore: _lastSpeed,
    );
    
    print('   Classification: ${classification.name}');
    
    // Create crash data
    final crashData = CrashData(
      deltaV: deltaV,
      impactVector: impactVector,
      acoustic: acoustic,
      classification: classification,
      timestamp: DateTime.now(),
      latitude: _lastPosition?.latitude ?? 0.0,
      longitude: _lastPosition?.longitude ?? 0.0,
      speedBefore: _lastSpeed,
      headingBefore: _lastHeading,
      first50msData: first50ms.map((s) => s.toJson()).toList(),
    );
    
    // Trigger black box upload
    await BlackBoxService.instance.triggerUpload();
    
    // Report to backend
    await _reportCrash(crashData);
    
    // Clear buffer
    _deltaVCalculator.clear();
  }
  
  Future<void> _reportCrash(CrashData crashData) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/crash_report'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(crashData.toJson()),
      );
      
      if (response.statusCode == 200) {
        print('✅ Crash forensic data uploaded to cloud');
        final data = jsonDecode(response.body);
        print('   Incident ID: ${data['incident_id']}');
      } else {
        print('❌ Failed to upload crash data: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error reporting crash: $e');
    }
  }
  
  void stopMonitoring() {
    _accelerometerSubscription?.cancel();
    AcousticService.instance.stopListening();
    _isMonitoring = false;
    print('🔬 Tri-Sensor Crash Detection Stopped');
  }
}
