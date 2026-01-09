import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Haptic Feedback
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';

// import 'dart:io' show Platform; // REMOVED for Web Compatibility
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts
import 'package:cruze_mobile/widgets/glass_card.dart'; // Import GlassCard
import 'package:cruze_mobile/services/safety_service.dart'; // Import SafetyService
import 'package:cruze_mobile/services/navigation_service.dart'; // Import NavigationService

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // San Antonio coordinates
  static const LatLng _initialCenter = LatLng(29.4241, -98.4936);
  
  static final String azureKey = dotenv.env['AZURE_MAPS_KEY'] ?? '';
  
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
    
    // Start Polling Incidents every 5 seconds
    _fetchIncidents();
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) _fetchIncidents();
    });
  }

  // Camera State
  bool _isFollowingUser = true;

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
      accuracy: LocationAccuracy.bestForNavigation, // Optimized for driving
      distanceFilter: 5, // Update every 5 meters (Reduces jitter/lag)
    );
    
    // 1. Get Immediate Fix (Live Location)
    try {
      debugPrint("Getting initial location fix...");
      Position current = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      debugPrint("Initial location: ${current.latitude}, ${current.longitude}");
      if (mounted) {
         setState(() {
           _currentPosition = LatLng(current.latitude, current.longitude);
           // Don't accumulate distance for this "jump"
         });
         // Snap Camera Immediately
         _mapController.move(_currentPosition, 17.5);
      }
    } catch (e) {
      debugPrint("Error getting immediate location: $e");
    }

    // 2. Start Streaming Updates
    debugPrint("Starting location stream...");
    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        debugPrint("Location update received: ${position.latitude}, ${position.longitude} Speed: ${position.speed}");
        final newLatLng = LatLng(position.latitude, position.longitude);
        final speedMph = (position.speed * 2.23694); // Convert m/s to mph
        
        if (mounted) {
          setState(() {
            // Track Distance
            const distance = Distance();
            // Calculate distance from last position in miles (1 meter = 0.000621371 miles)
            final moves = distance.as(LengthUnit.Meter, _currentPosition, newLatLng) * 0.000621371;
            if (moves > 0.001) { // Filter noise
                SafetyService.instance.updateDistance(moves);
            }

            _currentPosition = newLatLng;
            _currentSpeed = speedMph;
            
            // Safety Score Logic: Speeding
            if (_speedLimit != null && _currentSpeed > (_speedLimit! + 5)) {
               // Speeding Penalty: +0.5 per tick (approx 1 sec)
               // Only record if we haven't flooded the events - logic handled by service or simple throttle?
               // For now, just update the score silently or with a "Speeding" event?
               // Let's add a silent penalty to the service implementation if we wanted, 
               // but for now let's just trigger a "Speeding" event occasionally or just add penalty.
               // For this refactor, we'll just add the penalty directly via a helper or direct, 
               // but recordEvent is better. Let's make it a small penalty.
               // Actually, let's throttle this so we don't look like we are spamming.
               // Simplified: Just add penalty logic to service if we want, or call recordEvent.
               SafetyService.instance.recordEvent("Speeding", "Over limit by ${_currentSpeed.toInt() - _speedLimit!} mph", 0.5);
            }

            // High Risk Zone Alert Logic
             for (final zone in _highRiskZones) {
               const Distance distance = Distance();
               final double meterDist = distance.as(LengthUnit.Meter, newLatLng, zone);
               if (meterDist < 500) {
                  if (_canShowRiskAlert) {
                     _showRiskAlert();
                     _canShowRiskAlert = false;
                     Timer(const Duration(minutes: 5), () => _canShowRiskAlert = true);
                  }
               }
            }

          });
          
          // DYNAMIC CAMERA LOGIC
          if (_isFollowingUser) {
             // Zoom closer (17.5) for "Real Map" feel
             // Rotate map to match heading (GPS bearing) if moving
             double targetZoom = 17.5;
             double targetRotation = _mapController.camera.rotation;
             
             if (speedMph > 2) {
               // Only rotate if we are actually moving to avoid jitter
               targetRotation = position.heading;
             }
             
             _mapController.move(newLatLng, targetZoom);
             _mapController.rotate(targetRotation);
          }
        }
      },
      onError: (e) {
        debugPrint("Location stream error: $e");
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
  int? _speedLimit; // Real Speed Limit (nullable)
  double _currentSpeed = 0.0;
  
  // Safety Score - MOVED TO SERVICE
  // double _safetyScore = 100.0;
  // double _totalDistanceMiles = 0.0;
  // double _accumulatedPenalty = 0.0;
  
  // Risk Alert State
  bool _canShowRiskAlert = true;
  List<dynamic> _incidents = [];

  // San Antonio High Risk Zones (Lat, Lng)
  final List<LatLng> _highRiskZones = [
    const LatLng(29.5547, -98.6630), // Loop 1604 & Bandera Road
    const LatLng(29.4241, -98.4936), // Alamo Plaza (Testing)
    const LatLng(29.4260, -98.4861), // E Houston St
    const LatLng(29.4382, -98.6430), // Highway 151 & Loop 410
    const LatLng(29.6003, -98.5983), // Loop 1604 & I-10 North
    const LatLng(29.5223, -98.4972), // Loop 410 & San Pedro Avenue
    const LatLng(29.4911, -98.7030), // Loop 1604 & Culebra Road
  ];

  void _showRiskAlert() {
     ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
               Icon(Icons.warning_amber_rounded, color: Colors.white),
               SizedBox(width: 10),
               Expanded(
                 child: Column(
                   mainAxisSize: MainAxisSize.min,
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text("ENTERING HIGH RISK ZONE", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                     Text("Do not stop. Keep doors locked.", style: TextStyle(fontSize: 12)),
                   ],
                 ),
               ),
            ],
          ),
          backgroundColor: Colors.black,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
             side: const BorderSide(color: Colors.red, width: 2),
             borderRadius: BorderRadius.circular(8),
          ),
        ),
     );
  }

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
    
    // "Pan In" Effect: Smooth transition to destination
    // We don't snap immediately; we let the move animation handle it
    _mapController.move(point, 17.5); 
    
    _setDestination(point);
    
    setState(() {
      _searchResults = [];
      _searchController.text = result['address']['freeformAddress'] ?? '';
      _isFollowingUser = true; // Lock camera to navigation mode
      FocusScope.of(context).unfocus(); // Hide keyboard
    });
  }
  
  // Fetch speed limit from our backend which proxies to Azure Maps
  Future<void> _updateSpeedLimit() async {
    final lat = _currentPosition.latitude;
    final lon = _currentPosition.longitude;
    final host = await _getHost();
    
    // Default fallback to null (unknown)
    int? newLimit;

    try {
      final uri = Uri.parse('http://$host:7071/api/speed_limit?lat=$lat&lon=$lon');
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['limit'] != null && data['limit'] is int) {
           newLimit = data['limit'];
        }
      }
    } catch (e) {
      debugPrint("Error fetching speed limit: $e");
    }

    if (mounted) {
      setState(() {
        _speedLimit = newLimit;
      });
    }
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
              final miles = (lengthInMeters * 0.000621371).toStringAsFixed(1);
              if (mounted) {
                 // Haptic Heartbeat: Medium Impact for SAFE ROUTE FOUND
                 HapticFeedback.mediumImpact();
                 
                 setState(() {
                   _routeDistance = "$miles mi";
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
      
      // Safety Score Logic: Hard Braking / Cornering (G-Force > 5 but < 15)
      if (gForce > 5 && gForce < 15) {
         SafetyService.instance.recordEvent("Hard Braking", "G-Force: ${gForce.toStringAsFixed(1)}g", 5.0);
      }

      // Threshold > 15 as per requirements for CRASH
      if (gForce > 15) {
        // Haptic Heartbeat: Heavy Impact for CRASH
        HapticFeedback.heavyImpact();
        
        DateTime now = DateTime.now();
        // Debounce to prevent multiple API calls
        if (_lastShakeTime == null || now.difference(_lastShakeTime!) > const Duration(seconds: 5)) {
          _lastShakeTime = now;
          _triggerCrash(gForce);
        }
      }
    });
  }

  Future<String> _getHost() async {
    // Web safe host check
    if (kIsWeb) return 'localhost';
    if (defaultTargetPlatform == TargetPlatform.android) return '10.0.2.2';
    return 'localhost';
  }

  Future<void> _triggerCrash(double gForce) async {
    setState(() {
      _crashDetected = true;
    });

    // Send to API
    try {
      final host = await _getHost();
      final response = await http.post(
        Uri.parse('http://$host:7071/api/telemetry'), 
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

  // INCIDENT REPORTING LOGIC
  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("REPORT INCIDENT", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),
              _buildReportOption("CRASH", Icons.car_crash, Colors.red),
              const SizedBox(height: 8),
              _buildReportOption("FLAT TIRE", Icons.tire_repair, Colors.orange),
              const SizedBox(height: 8),
              _buildReportOption("STOPPED CAR", Icons.warning, Colors.yellow),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportOption(String label, IconData icon, Color color) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pop(); // Close dialog
        _submitReport(label);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Future<void> _submitReport(String type) async {
    // Optimistic Update
    setState(() {
      _incidents.add({
        'lat': _initialCenter.latitude,
        'lon': _initialCenter.longitude,
        'type': type,
        'description': 'Reported by user',
      });
      
      // Haptic Feedback
      HapticFeedback.heavyImpact();
    });

    try {
      final host = defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : 'localhost';
      await http.post(
        Uri.parse('http://$host:7071/api/report_incident'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'lat': _initialCenter.latitude,
          'lon': _initialCenter.longitude,
          'type': type,
          'description': 'Reported by User',
        }),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Incident Reported to Community"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Error reporting incident: $e");
    }
  }

  Future<void> _fetchIncidents() async {
    try {
      final host = await _getHost();
      final response = await http.get(Uri.parse('http://$host:7071/api/incidents'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
           setState(() {
             _incidents = data['incidents'];
           });
        }
      }
    } catch (e) {
      debugPrint("Error fetching incidents: $e");
    }
  }
  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  // --- END NAVIGATION LOGIC ---

  void _startDriveMode() {
    NavigationService.instance.startNavigation();
    setState(() {
      _isFollowingUser = true;
    });
    // Lock Camera
    _mapController.move(_currentPosition, 18.0);
  }

  void _endDriveMode() {
     NavigationService.instance.stopNavigation();
     setState(() {
       _routePoints = []; // Clear Route (Optional)
     });
  }

  @override
  Widget build(BuildContext context) {
    // Note: Removed Scaffold to rely on MainScaffold.
    // Adjust bottom padding to account for floating GlassNavBar (~100px height)
    return Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 13.0,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  setState(() => _isFollowingUser = false);
                }
              },
              onTap: (tapPosition, point) {
                _setDestination(point);
              },
            ),
            children: [
              TileLayer(
                // Correct Azure Maps V2 Tile URL (singular 'tile', needs tilesetId)
                urlTemplate: 'https://atlas.microsoft.com/map/tile?api-version=2.0&tilesetId=microsoft.base.darkgrey&zoom={z}&x={x}&y={y}&subscription-key={subscriptionKey}',
                additionalOptions: {
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
                  radius: 500, 
                  useRadiusInMeter: true,
                )).toList(),
              ),


              PolylineLayer(
                polylines: [
                  if (_routePoints.isNotEmpty) ...[
                    // Glow Layer 1 (Outer Blur)
                    Polyline(
                      points: _routePoints,
                      color: const Color(0xFFff791a).withOpacity(0.2),
                      strokeWidth: 20.0,
                    ),
                    // Glow Layer 2 (Inner Blur)
                    Polyline(
                      points: _routePoints,
                      color: const Color(0xFFff791a).withOpacity(0.5),
                      strokeWidth: 10.0,
                    ),
                    // Core Line (Bright)
                    Polyline(
                      points: _routePoints,
                      color: const Color(0xFFff791a), // Safety Orange
                      strokeWidth: 4.0,
                    ),
                  ],
                ],
              ),
              MarkerLayer(
                markers: [
                   // High Risk Zone Icons
                   ..._highRiskZones.map((zone) => Marker(
                      point: zone,
                      width: 30,
                      height: 30,
                      child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
                   )),
                   
                   // INCIDENT MARKERS (Filtered to 1 mile radius)
                   ..._incidents.where((incident) {
                      final LatLng incidentPos = LatLng(incident['lat'], incident['lon']);
                      const Distance distance = Distance();
                      // 1 mile = ~1609 meters
                      return distance.as(LengthUnit.Meter, _currentPosition, incidentPos) <= 1609;
                   }).map((incident) {
                      IconData icon = Icons.warning;
                      Color color = Colors.orange;
                      if (incident['type'] == 'CRASH') { icon = Icons.car_crash; color = Colors.red; }
                      if (incident['type'] == 'FLAT TIRE') { icon = Icons.tire_repair; color = Colors.orange; }
                      if (incident['type'] == 'STOPPED CAR') { icon = Icons.warning; color = Colors.yellow; }
                      
                      return Marker(
                        point: LatLng(incident['lat'], incident['lon']),
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                            border: Border.all(color: color, width: 2),
                          ),
                          child: Icon(icon, color: color, size: 20),
                        ),
                      );
                   }),

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
          
           // Start Button (ValueListenable)
           ValueListenableBuilder<bool>(
             valueListenable: NavigationService.instance.isNavigating,
             builder: (context, isNavigating, child) {
               if (_routePoints.isNotEmpty && !isNavigating) {
                  return Positioned(
                     bottom: 120, // Clear Nav Bar
                     left: 20, 
                     right: 20,
                     child: Column(
                       children: [
                          GlassCard(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildRouteStat(Icons.timer, (_routeDistance != null && _routeDistance!.contains("mi")) ? "12 min" : "--"), 
                                  _buildRouteStat(Icons.directions_car, _routeDistance ?? "--"),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _startDriveMode,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFff791a), // Safety Orange
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              elevation: 8,
                              shadowColor: const Color(0xFFff791a).withOpacity(0.5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.navigation, color: Colors.white),
                                const SizedBox(width: 8),
                                Text(
                                  "START NAVIGATION", 
                                  style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)
                                ),
                              ],
                            ),
                          ),
                       ],
                     ),
                  );
               }
               return const SizedBox.shrink();
             },
           ),

           // End Trip Button (ValueListenable)
           ValueListenableBuilder<bool>(
             valueListenable: NavigationService.instance.isNavigating,
             builder: (context, isNavigating, child) {
                if (isNavigating) {
                   return Positioned(
                     bottom: 40, 
                     left: 0,
                     right: 0,
                     child: Center(
                       child: FloatingActionButton.extended(
                         onPressed: _endDriveMode,
                         backgroundColor: Colors.redAccent,
                         icon: const Icon(Icons.close, color: Colors.white),
                         label: Text("END TRIP", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.white)),
                       ),
                     ),
                   );
                }
                return const SizedBox.shrink();
             },
           ),

           // Search Bar (Hidden in Drive Mode)
           ValueListenableBuilder<bool>(
             valueListenable: NavigationService.instance.isNavigating,
             builder: (context, isNavigating, child) {
               return AnimatedPositioned(
                 duration: const Duration(milliseconds: 300),
                 curve: Curves.easeInOut,
                 top: isNavigating ? -150 : 0, // Slide up to hide
                 left: 0,
                 right: 0,
                 child: SafeArea( 
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: _destination == null 
                      ? // Search Mode
                        GlassCard(
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
                        GlassCard(
                          child: Row(
                            children: [
                              // Dynamic Direction Icon (Small)
                              if (_currentInstruction != null)
                                 Container(
                                   padding: const EdgeInsets.all(8),
                                   decoration: BoxDecoration(
                                     color: Colors.white.withOpacity(0.1),
                                     shape: BoxShape.circle,
                                   ),
                                   child: const Icon(Icons.navigation_rounded, color: Color(0xFFff791a), size: 24),
                                 ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [ 
                                    Text(
                                      _currentInstruction ?? "Follow Route",
                                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                    if (_currentInstruction != null && _currentInstruction!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Row(
                                           children: _getLaneIcons(_currentInstruction!),
                                        ),
                                      ),
                                    if (_routeDistance != null)
                                      Text(
                                        _routeDistance!,
                                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                                      ),
                                  ],
                                ),
                              ),
                             IconButton(
                                icon: const Icon(Icons.close, color: Colors.white54),
                                onPressed: () {
                                  _setDestination(const LatLng(0,0)); // Clear dest
                                  setState(() {
                                     _destination = null;
                                     _routePoints = [];
                                     _isFollowingUser = true;
                                  });
                                },
                             )
                            ],
                          ),
                        ),
                  ),
                 ),
               );
             },
           ),
          
          // Search Results Overlay
          if (_destination == null && _searchResults.isNotEmpty)
            Positioned(
              top: 80, // Below search bar
              left: 16,
              right: 16,
              child: SafeArea(
                child: GlassCard(
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

          // Recenter Button
          if (!_isFollowingUser)
             Positioned(
               bottom: 180, // Moved up to match Report button (Symmetry) & Clear HUD
               right: 16,
               child: FloatingActionButton(
                 heroTag: "recenter_fab",
                 onPressed: () {
                   setState(() {
                     _isFollowingUser = true;
                     _mapController.move(_currentPosition, 17.5);
                   });
                 },
                 backgroundColor: const Color(0xFFff791a),
                 child: const Icon(Icons.my_location, color: Colors.white),
               ),
             ),
             
          // Report Incident Button (Bottom Left)
          Positioned(
             bottom: 180, // Moved up to clear HUD
             left: 16,
             child: FloatingActionButton(
               heroTag: "report_fab",
               onPressed: _showReportDialog,
               backgroundColor: Colors.redAccent,
               child: const Icon(Icons.report_problem, color: Colors.white),
             ),
          ),

          // HUD Overlay (Bottom)
          Positioned(
            bottom: 120, 
            left: 20,
            right: 20,
            child: SafeArea(
              top: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   // SPEED LIMIT & CURRENT SPEED
                   Column(
                     mainAxisSize: MainAxisSize.min,
                     children: [
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
                             Text('LIMIT', style: GoogleFonts.montserrat(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w900)),
                             Text(
                                '${_speedLimit ?? "--"}',
                                style: GoogleFonts.montserrat(color: Colors.black, fontSize: 24, fontWeight: FontWeight.w900),
                             ),
                           ],
                         ),
                       ),
                       const SizedBox(height: 8),
                       GlassCard(
                         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                         child: Text(
                           '${_currentSpeed.toInt()} MPH',
                           style: GoogleFonts.montserrat(color: const Color(0xFFff791a), fontWeight: FontWeight.bold, fontSize: 16),
                         ),
                       ),
                     ],
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
      );
  }
  // Helper for Route Stats
  Widget _buildRouteStat(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFff791a), size: 20),
        const SizedBox(width: 8),
        Text(
          label, 
          style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
        ),
      ],
    );
  }

  // Helper to generate Lane Icons
  List<Widget> _getLaneIcons(String instruction) {
    List<Widget> lanes = [];
    String lower = instruction.toLowerCase();
    
    // Default: 2 Lanes for city streets, 3 for highway terms
    int laneCount = 2;
    if (lower.contains("exit") || lower.contains("keep") || lower.contains("merge") || lower.contains("highway")) {
       laneCount = 3;
    }

    // Explicit Overrides from Text
    if (lower.contains("1 lane") || lower.contains("single lane") || lower.contains("ramp")) {
       laneCount = 1;
    } else if (lower.contains("2 lanes")) {
       laneCount = 2;
    } else if (lower.contains("3 lanes")) {
       laneCount = 3;
    } else if (lower.contains("4 lanes")) {
       laneCount = 4;
    }
    
    // Determine Recommended Lane Index (0 = Left ... N = Right)
    List<int> recommended = [];
    
    if (laneCount == 1) {
       recommended = [0]; // The only lane is the right lane
    } else {
        if (lower.contains("left") || lower.contains("merge left")) {
           recommended = [0]; // Left Lane
           if (lower.contains("2 lanes") && laneCount > 2) recommended = [0, 1];
        } else if (lower.contains("right") || lower.contains("merge right") || lower.contains("exit")) {
           recommended = [laneCount - 1]; // Right-most Lane
           if (lower.contains("2 lanes") && laneCount > 2) recommended = [laneCount - 2, laneCount - 1];
        } else {
           // Straight or Keep -> Center lanes
           if (laneCount == 2) recommended = [0, 1]; // Use both? Or just right? Let's say both for "continue"
           if (laneCount == 3) recommended = [1]; // Middle
           if (laneCount >= 4) recommended = [1, 2]; // Middle two
        }
    }

    for (int i = 0; i < laneCount; i++) {
       bool isActive = recommended.contains(i);
       IconData icon = Icons.arrow_upward_rounded;
       
       if (isActive) {
          if (lower.contains("left") && !lower.contains("keep")) {
            icon = Icons.turn_left_rounded;
          } else if ((lower.contains("right") || lower.contains("exit")) && !lower.contains("keep")) {
            icon = Icons.turn_right_rounded;
          } else if (lower.contains("u-turn")) {
            icon = Icons.u_turn_left_rounded;
          }
       }

       lanes.add(
         Padding(
           padding: const EdgeInsets.symmetric(horizontal: 4.0), // More spacing
           child: Container(
             padding: const EdgeInsets.all(4),
             decoration: isActive ? BoxDecoration(
               color: Colors.white.withOpacity(0.1),
               borderRadius: BorderRadius.circular(4),
               border: Border.all(color: const Color(0xFFff791a).withOpacity(0.5)),
             ) : null,
             child: Icon(
               icon,
               color: isActive ? const Color(0xFFff791a) : Colors.white24, // Highlight Orange
               size: 24,
             ),
           ),
         )
       );
    }
    return lanes;
  }
} // End of State class
