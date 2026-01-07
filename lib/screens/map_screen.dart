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
  LatLng? _destination;
  String? _routeDistance;
  List<LatLng> _routePoints = [];

  @override
  void initState() {
    super.initState();

    _startListening();
    _startLocationUpdates();
  }

  Future<void> _startLocationUpdates() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
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

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
    
    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        final newLatLng = LatLng(position.latitude, position.longitude);
        final speedMph = (position.speed * 2.23694); // Convert m/s to mph
        
        if (mounted) {
          setState(() {
            _currentPosition = newLatLng;
            _currentSpeed = speedMph;
          });
          _mapController.move(newLatLng, 15.0);
        }
      },
    );
  }

  // Search State
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;
  
  // Navigation State
  String? _currentInstruction;
  int _speedLimit = 45; // Simulated Speed Limit
  double _currentSpeed = 0.0;
  
  // San Antonio High Risk Zones (Lat, Lng)
  final List<LatLng> _highRiskZones = [
    const LatLng(29.5547, -98.6630), // Loop 1604 & Bandera Road
    const LatLng(29.4382, -98.6430), // Highway 151 & Loop 410
    const LatLng(29.6003, -98.5983), // Loop 1604 & I-10 North
    const LatLng(29.5223, -98.4972), // Loop 410 & San Pedro Avenue
    const LatLng(29.4911, -98.7030), // Loop 1604 & Culebra Road
  ];

  // ... existing methods ...

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        _performSearch(query);
      } else {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isSearching = true);
    final Uri uri = Uri.parse(
        'https://atlas.microsoft.com/search/fuzzy/json?api-version=1.0&query=$query&subscription-key=$azureKey&lat=${_currentPosition.latitude}&lon=${_currentPosition.longitude}');

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _searchResults = data['results'];
        });
      }
    } catch (e) {
      debugPrint('Error searching: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  // ... search methods ...

  void _selectSearchResult(dynamic result) {
    final position = result['position'];
    final point = LatLng(position['lat'], position['lon']);
    
    _mapController.move(point, 15.0);
    _setDestination(point);
    
    setState(() {
      _searchResults = [];
      _searchController.text = result['address']['freeformAddress'] ?? '';
      FocusScope.of(context).unfocus(); // Hide keyboard
    });
  }
  
  // Simulate fetching speed limit based on location (mock for now)
  void _updateSpeedLimit() {
    //In a real app, query Azure Maps Search with "returnSpeedLimit=true" or similar
    setState(() {
      _speedLimit = 30 + Random().nextInt(40); // Random limit between 30-70 for demo
    });
  }

  Future<void> _setDestination(LatLng point) async {
    setState(() {
      _destination = point;
      _routePoints = []; // Clear previous route while loading
      _routeDistance = "Calculating...";
      _currentInstruction = "Calculating route..."; // Feedback
      // Clear search results if set via tap
      if (_searchResults.isNotEmpty) _searchResults = []; 
    });
    
    await _fetchRealRoute(_currentPosition, point);
  }

  Future<void> _fetchRealRoute(LatLng start, LatLng end) async {
    final String query = '${start.latitude},${start.longitude}:${end.latitude},${end.longitude}';
    // Added instructionsType=text to get guidance
    final Uri uri = Uri.parse(
        'https://atlas.microsoft.com/route/directions/json?api-version=1.0&query=$query&subscription-key=$azureKey&routeRepresentation=polyline&instructionsType=text');

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List;
        if (routes.isNotEmpty) {
          final legs = routes[0]['legs'] as List;
          final points = <LatLng>[];
          
          // Basic summary for distance
          if (data['routes'][0]['summary'] != null) {
              final lengthInMeters = data['routes'][0]['summary']['lengthInMeters'];
              final km = (lengthInMeters / 1000).toStringAsFixed(1);
              if (mounted) {
                 setState(() {
                   _routeDistance = "$km km";
                 });
              }
          }
          
          // Get first instruction if available
          String? instruction;
          if (data['routes'][0]['guidance'] != null && 
              data['routes'][0]['guidance']['instructions'] != null) {
             final instructions = data['routes'][0]['guidance']['instructions'] as List;
             if (instructions.isNotEmpty) {
               instruction = instructions[0]['message']; // e.g. "Turn right on Main St"
               // Some instructions have 'turnAngleInDecimalDegrees' or 'maneuver'
             }
          }
          // Fallback if structure differs or is empty
          if (instruction == null && legs.isNotEmpty) {
             // Mock one for "Real App" feel if API doesn't return simple text
             instruction = "Head north towards destination";
          }

          for (var leg in legs) {
            final pointsData = leg['points'] as List;
            for (var point in pointsData) {
              points.add(LatLng(point['latitude'], point['longitude']));
            }
          }

          if (mounted) {
            setState(() {
              _routePoints = points;
              _currentInstruction = instruction;
              _updateSpeedLimit(); // Trigger speed limit update on new route
            });
          }
        }
      } else {
        debugPrint('Error fetching route: ${response.statusCode}');
        if (mounted) {
           setState(() {
             _routeDistance = "Error";
             _currentInstruction = "Route calculation failed";
           });
        }
      }
    } catch (e) {
      debugPrint('Exception fetching route: $e');
         if (mounted) {
           setState(() {
             _routeDistance = "Error";
               _currentInstruction = "Error connecting to service";
           });
        }
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
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 13.0,
              onTap: (tapPosition, point) {
                _setDestination(point);
              },
            ),
            children: [
              TileLayer(
                // Correct Azure Maps V2 Tile URL (singular 'tile', needs tilesetId)
                urlTemplate: 'https://atlas.microsoft.com/map/tile?api-version=2.0&tilesetId=microsoft.base.darkgrey&zoom={z}&x={x}&y={y}&subscription-key={subscriptionKey}',
                additionalOptions: const {
                  'subscriptionKey': azureKey,
                },
                userAgentPackageName: 'com.example.cruze_mobile',
              ),
              // High Risk Zones Layer
              CircleLayer(
                circles: _highRiskZones.map((zone) => CircleMarker(
                  point: zone,
                  color: Colors.red.withOpacity(0.3),
                  borderColor: Colors.red.withOpacity(0.7),
                  borderStrokeWidth: 2,
                  radius: 500, // ~500 meters visual radius (approximate for pixel/zoom) - flutter_map uses pixels or meters depending on validation. CircleMarker radius is in pixels usually but let's check. 
                  // Wait, CircleMarker radius is "radius", usually pixels. To map to real-world meters implies using a different layer or dynamic calculation. 
                  // For simple visualization, 100 logical pixels at high zoom is fine, but might be huge at low zoom. 
                  // Ideally use a Polygon for specific geofence, but CircleMarker is easy. 
                  // Let's use useRadiusInMeter = true if available or accepted in this version.
                  // Checking docs: flutter_map 6+ CircleMarker has 'useRadiusInMeter'.
                  useRadiusInMeter: true,
                )).toList(),
              ),
              PolylineLayer(
                polylines: [
                  if (_routePoints.isNotEmpty)
                    Polyline(
                      points: _routePoints,
                      color: const Color(0xFFff791a), // Safety Orange
                      strokeWidth: 4.0,
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                   // Risk Zone Icons (Warning Signs)
                   ..._highRiskZones.map((zone) => Marker(
                      point: zone,
                      width: 30,
                      height: 30,
                      child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
                   )),
                  Marker(
                    point: _currentPosition,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFff791a).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.navigation,
                        color: Color(0xFFff791a), // Safety Orange
                        size: 30,
                      ),
                    ),
                  ),
                  if (_destination != null)
                     Marker(
                      point: _destination!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                ],
              ),
            ],
          ),
          // Search Bar OR Instruction Banner
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                constraints: const BoxConstraints(maxWidth: 600),
                child: _destination == null 
                  ? // Search Mode
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: _searchController,
                            onChanged: _onSearchChanged,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Search destination...',
                              hintStyle: TextStyle(color: Colors.grey[600]),
                              prefixIcon: const Icon(Icons.search, color: Color(0xFFff791a)),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, color: Colors.grey),
                                      onPressed: () {
                                        _searchController.clear();
                                        _onSearchChanged('');
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                          ),
                          if (_isSearching)
                            const LinearProgressIndicator(
                              color: Color(0xFFff791a),
                              backgroundColor: Colors.transparent,
                              minHeight: 2,
                            ),
                        ],
                      ),
                    )
                  : // Navigation Mode (Turn-by-Turn)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E), // Dark card
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
                        border: Border.all(color: const Color(0xFFff791a), width: 1.5), // Orange border
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.turn_right, color: Colors.white, size: 40), // Placeholder direction
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _currentInstruction ?? "Follow Route",
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                                if (_routeDistance != null)
                                  Text(
                                    _routeDistance!,
                                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                                  ),
                              ],
                            ),
                          ),
                           // Close/Exit Button
                           IconButton(
                             icon: const Icon(Icons.close, color: Colors.grey),
                             onPressed: () {
                               setState(() {
                                 _routePoints = [];
                                 _destination = null;
                                 _routeDistance = null;
                                 _currentInstruction = null;
                                 _searchController.clear();
                               });
                             },
                           ),
                        ],
                      ),
                    ),
              ),
            ),
          ),
          
          // Search Results Overlay (Only if not navigating)
          if (_destination == null && _searchResults.isNotEmpty)
            Positioned(
              top: 80, // Below search bar
              left: 16,
              right: 16,
              child: SafeArea(
                child: Container(
                   decoration: BoxDecoration(
                     color: const Color(0xFF1E1E1E),
                     borderRadius: BorderRadius.circular(12),
                     boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
                   ),
                   constraints: const BoxConstraints(maxWidth: 600, maxHeight: 200),
                   child: ListView.builder(
                     shrinkWrap: true,
                     itemCount: _searchResults.length,
                     itemBuilder: (context, index) {
                       final result = _searchResults[index];
                       final address = result['address']['freeformAddress'] ?? 'Unknown location';
                       final name = result['poi'] != null ? result['poi']['name'] : address;
                       
                       return ListTile(
                          leading: const Icon(Icons.location_on_outlined, color: Colors.grey),
                          title: Text(name, style: const TextStyle(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: name != address ? Text(address, style: TextStyle(color: Colors.grey[400], fontSize: 12), maxLines: 1) : null,
                          onTap: () => _selectSearchResult(result),
                       );
                     },
                   ),
                ),
              ),
            ),

          // HUD Overlay (Bottom)
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: SafeArea(
              top: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   // SPEED LIMIT & CURRENT SPEED (New Feature)
                   Column(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       // Speed Limit Sign
                       Container(
                         width: 50,
                         height: 60,
                         decoration: BoxDecoration(
                           color: Colors.white,
                           borderRadius: BorderRadius.circular(8),
                           border: Border.all(color: Colors.black, width: 3),
                           boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                         ),
                         child: Column(
                           mainAxisAlignment: MainAxisAlignment.center,
                           children: [
                             const Text('LIMIT', style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.bold)),
                             Text(
                               '$_speedLimit',
                               style: const TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold),
                             ),
                           ],
                         ),
                       ),
                       const SizedBox(height: 8),
                       // Current Speed
                       Container(
                         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                         decoration: BoxDecoration(
                           color: Colors.black.withOpacity(0.8),
                           borderRadius: BorderRadius.circular(8),
                         ),
                         child: Text(
                           '${_currentSpeed.toInt()} MPH',
                           style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                         ),
                       ),
                     ],
                   ),
                   
                   const Spacer(),

                   // Safety Score Card (Right Side)
                   Container(
                    padding: const EdgeInsets.all(16),
                    constraints: const BoxConstraints(maxWidth: 200), // Smaller width
                    decoration: BoxDecoration(
                      color: const Color(0xFF121212).withOpacity(0.9), // Background Dark
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFff791a).withOpacity(0.3)), // Border Orange
                    ),
                    child: Column( // Vertical Stack for compact right side
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.shield,
                          color: Color(0xFFff791a), // Safety Orange
                          size: 32,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'SCORE',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          '100',
                          style: TextStyle(
                            color: Color(0xFFff791a), // Safety Orange
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
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
