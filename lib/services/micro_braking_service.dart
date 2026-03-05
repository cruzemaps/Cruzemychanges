import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MicroBrakingService {
  static final MicroBrakingService _instance = MicroBrakingService._internal();
  static MicroBrakingService get instance => _instance;
  MicroBrakingService._internal();

  StreamSubscription<UserAccelerometerEvent>? _subscription;
  final double _brakingThreshold = 0.3; // g-force
  final int _minDurationMs = 500;
  
  DateTime? _brakingStartTime;
  bool _isBraking = false;
  double _maxForce = 0.0;

  void startMonitoring() {
    _subscription = userAccelerometerEvents.listen((UserAccelerometerEvent event) {
      // Y-axis is typically longitudinal for phone in car mount (portrait)
      // Negative Y is often braking (deceleration) depending on orientation.
      // We will check absolute magnitude of Y or just Y < -threshold.
      // Assuming phone back facing forward (screen to driver):
      // Deceleration (braking) throws 'force' forward, so phone feels force backwards?
      // Actually, accelerometer measures proper acceleration.
      // Stationary: 0 (gravity removed by UserAccelerometer).
      // Braking: Car slows down. Passenger moves forward relative to car. 
      // Phone (attached to car) accelerates *backwards* relative to inertial frame?
      // Let's stick to the prompt's condition: z < -0.3g (implied screen up/down?)
      // We will use Z as requested, but also monitor Y for robustness if needed later.
      // Prompt says: if (z_force < -0.3g && duration > 500ms)

      if (event.z < -_brakingThreshold) {
        if (!_isBraking) {
          _isBraking = true;
          _brakingStartTime = DateTime.now();
          _maxForce = event.z;
        } else {
          if (event.z < _maxForce) _maxForce = event.z; // Track peak (more negative)
        }
      } else {
        if (_isBraking) {
          _isBraking = false;
          final duration = DateTime.now().difference(_brakingStartTime!).inMilliseconds;
          if (duration > _minDurationMs) {
            _sendAlert(_maxForce, duration);
          }
        }
      }
    });
  }

  void stopMonitoring() {
    _subscription?.cancel();
  }

  Future<void> _sendAlert(double force, int duration) async {
    print("🛑 Micro-Braking Detected! Force: ${force.toStringAsFixed(2)}g, Duration: ${duration}ms");
    
    try {
      final String baseUrl = "https://unmaternal-parthenia-oarless.ngrok-free.app"; // For Simulator
      // final String baseUrl = "http://10.0.2.2:7071"; // For Android Emulator
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/telemetry/braking'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "force": force,
          "duration": duration,
          "timestamp": DateTime.now().toIso8601String(),
        }),
      );
      
      if (response.statusCode == 200) {
        print("✅ Alert sent to cloud.");
      } else {
        print("⚠️ Failed to send alert: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Error sending alert: $e");
    }
  }
}
