import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'dart:io' show Platform;
import 'package:geolocator/geolocator.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // San Antonio coordinates
  static const LatLng _initialCenter = LatLng(29.4241, -98.4936);
  
  static const String azureKey = String.fromEnvironment('AZURE_MAPS_KEY', defaultValue: 'YOUR_KEY_HERE');
  
  // State
  final MapController _mapController = MapController();
  LatLng _currentPosition = _initialCenter;
  StreamSubscription<Position>? _positionStreamSubscription;

  bool _crashDetected = false;
  StreamSubscription? _accelerometerSubscription;
  DateTime? _lastShakeTime;
  List<LatLng> _routePoints = [];

  @override
  void initState() {
    super.initState();

    _startListening();
    _startLocationUpdates();
    _fetchRoute();
  }

  Future<void> _startLocationUpdates() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the 
      // App to enable the location services.
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return;
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
    
    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        final newLatLng = LatLng(position.latitude, position.longitude);
        setState(() {
          _currentPosition = newLatLng;
        });
        
        // Move the map to follow the driver
        _mapController.move(newLatLng, 15.0);
      },
    );
  }

  Future<void> _fetchRoute() async {
    // Simulate API call to GET /api/route
    // Ideally: http.get(Uri.parse('http://localhost:7071/api/route?start=...&end=...'))
    
    // For demo stability, we'll implement the fallback/mock directly here 
    // to ensure the Blue Polyline appears as requested.
    
    await Future.delayed(const Duration(seconds: 1)); // Sim network
    
    if (mounted) {
      setState(() {
        _routePoints = [
          _initialCenter,
          const LatLng(29.4200, -98.4900),
          const LatLng(29.4150, -98.4850),
          const LatLng(29.4100, -98.4800),
        ]; 
      });
    }
  }

  void _startListening() {
    // UserAccelerometerEvent describes the acceleration of the device, 
    // adjusting for gravity.
    _accelerometerSubscription = userAccelerometerEventStream().listen((UserAccelerometerEvent event) {
      double gForce = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      
      // Threshold > 15 as per requirements
      if (gForce > 15) {
        DateTime now = DateTime.now();
        // Debounce to prevent multiple API calls
        if (_lastShakeTime == null || now.difference(_lastShakeTime!) > const Duration(seconds: 5)) {
          _lastShakeTime = now;
          _triggerCrash(gForce);
        }
      }
    });
  }

  Future<void> _triggerCrash(double gForce) async {
    setState(() {
      _crashDetected = true;
    });

    // Send to API
    try {
      final response = await http.post(
        Uri.parse('http://${Platform.isAndroid ? '10.0.2.2' : 'localhost'}:7071/api/telemetry'), 
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'lat': _initialCenter.latitude,
          'long': _initialCenter.longitude,
          'crash_detected': true,
          'g_force': gForce,
        }),
      );
      debugPrint('Telemetry sent: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error sending telemetry: $e');
    }
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://atlas.microsoft.com/map/tiles?subscription-key={subscriptionKey}&api-version=2.0&layer=basic&style=dark&zoom={z}&x={x}&y={y}',
                additionalOptions: const {
                  'subscriptionKey': azureKey,
                },
                userAgentPackageName: 'com.example.cruze_mobile',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    color: Colors.blue,
                    strokeWidth: 4.0,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentPosition,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.navigation,
                      color: Colors.blue,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // HUD Overlay
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SAFETY SCORE',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '100',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.shield,
                    color: Colors.green,
                    size: 32,
                  ),
                ],
              ),
            ),
          ),
          
          // CRASH OVERLAY
          if (_crashDetected)
            Container(
              color: Colors.red.withOpacity(0.8),
              width: double.infinity,
              height: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning, color: Colors.white, size: 100),
                  const SizedBox(height: 20),
                  const Text(
                    'CRASH DETECTED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Notifying Emergency Contacts...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _crashDetected = false;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('I AM OKAY'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
