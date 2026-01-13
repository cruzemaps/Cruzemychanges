import 'dart:async';
import 'dart:math';
import 'package:latlong2/latlong.dart';
import 'package:sensors_plus/sensors_plus.dart';

class GhostLockService {
  static final GhostLockService _instance = GhostLockService._internal();
  static GhostLockService get instance => _instance;
  GhostLockService._internal();

  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  StreamSubscription<MagnetometerEvent>? _magSub;

  // State
  LatLng? _lastKnownPosition;
  double _headingRadians = 0.0;
  
  // Physics State (Simplified 2D)
  // Velocity in meters/sec (North, East)
  double _vNorth = 0.0;
  double _vEast = 0.0;
  
  DateTime? _lastUpdate;

  final StreamController<LatLng> _positionController = StreamController<LatLng>.broadcast();
  Stream<LatLng> get positionStream => _positionController.stream;

  bool _isTracking = false;

  void startTracking(LatLng startPos) {
    if (_isTracking) return;
    _isTracking = true;
    _lastKnownPosition = startPos;
    _lastUpdate = DateTime.now();
    _vNorth = 0.0;
    _vEast = 0.0;

    print("Ghost Lock Initiated. Dead Reckoning Active.");

    // Listen to Magnetometer for heading
    _magSub = magnetometerEvents.listen((event) {
       // Simple heading calculation: atan2(y, x)
       // Note: Device orientation matters. Assuming held upright/flat.
       // This is a rough estimation for hackathon purposes.
       _headingRadians = atan2(event.y, event.x);
    });

    // Listen to Accelerometer for movement
    _accelSub = userAccelerometerEvents.listen((event) {
      final now = DateTime.now();
      final dt = now.difference(_lastUpdate!).inMilliseconds / 1000.0; // seconds
      _lastUpdate = now;

      // Rotate acceleration to Earth frame using heading
      // Accel Forward/Right (Device Frame) -> North/East (Earth Frame)
      // Ignoring Z (gravity handled by UserAccelerometer)
      
      // Simple rotation matrix
      // vN += (ax * cos(h) - ay * sin(h)) * dt
      // vE += (ax * sin(h) + ay * cos(h)) * dt
      
      // Note: UserAccelerometer x is right, y is up (forward in flat mode?)
      // Let's assume Y is forward direction of car.
      
      final ax = event.x;
      final ay = event.y;

      // Integrate Acceleration -> Velocity
      // Apply friction/decay to prevent runaway drift (Mocking drag)
      _vNorth = (_vNorth + (ay * cos(_headingRadians) * dt)) * 0.95; 
      _vEast = (_vEast + (ay * sin(_headingRadians) * dt)) * 0.95;

      // Integrate Velocity -> Position
      if (_lastKnownPosition != null) {
        // Meters to Lat/Lon degrees
        // 1 deg Lat ~= 111111 meters
        // 1 deg Lon ~= 111111 * cos(lat) meters
        
        final double dLat = _vNorth * dt / 111111.0;
        final double dLon = _vEast * dt / (111111.0 * cos(_lastKnownPosition!.latitude * pi / 180.0));

        final newPos = LatLng(
          _lastKnownPosition!.latitude + dLat,
          _lastKnownPosition!.longitude + dLon,
        );

        _lastKnownPosition = newPos;
        _positionController.add(newPos);
      }
    });
  }

  void stopTracking() {
    _isTracking = false;
    _accelSub?.cancel();
    _magSub?.cancel();
    print("Ghost Lock Disengaged.");
  }
}
