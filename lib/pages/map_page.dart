import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'bluetooth_connect_page.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class MapPage extends StatefulWidget {
  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  LatLng? _currentLocation;
  LatLng? _destination;
  List<LatLng> _routePoints = [];
  String? _currentTurnDirection;
  StreamSubscription<Position>? _positionStreamSubscription;
  LatLng? _nextWaypoint;
  double _distanceToNextWaypoint = 0;
  final Distance distance = const Distance();
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _initializeLocationTracking();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeLocationTracking() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }

      // Get initial position
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });

      // Add a small delay to ensure the map is rendered
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        _mapController.move(_currentLocation!, 16.0);
      }

      // Start listening to location updates
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
        ),
      ).listen((Position position) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _updateNextWaypoint();
          if (mounted) {
            _mapController.move(_currentLocation!, 16.0);
          }
        });
      });

    } catch (e) {
      print('Error setting up location tracking: $e');
    }
  }

  void _updateNextWaypoint() {
    if (_routePoints.isEmpty || _currentLocation == null) return;

    LatLng? nextPoint;
    double minDistance = double.infinity;

    for (var point in _routePoints) {
      double dist = distance.as(
          LengthUnit.Meter, _currentLocation!, point);
      if (dist < minDistance) {
        minDistance = dist;
        nextPoint = point;
      }
    }

    if (nextPoint != null) {
      int currentIndex = _routePoints.indexOf(nextPoint);
      if (currentIndex < _routePoints.length - 1) {
        setState(() {
          _nextWaypoint = _routePoints[currentIndex + 1];
          _distanceToNextWaypoint = distance.as(
              LengthUnit.Meter, _currentLocation!, _nextWaypoint!);
        });
      }
    }
  }

  Future<void> _getDirections() async {
    if (_currentLocation == null || _destination == null) return;

    final url =
        'https://router.project-osrm.org/route/v1/driving/${_currentLocation!.longitude},${_currentLocation!.latitude};${_destination!.longitude},${_destination!.latitude}?overview=full&steps=true&geometries=polyline';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Debug print the entire response
        print('Full API Response: ${json.encode(data)}');
        
        final String encodedPolyline = data['routes'][0]['geometry'];
        final List steps = data['routes'][0]['legs'][0]['steps'];

        // Decode the polyline
        final PolylinePoints polylinePoints = PolylinePoints();
        List<PointLatLng> decodedPolyline = polylinePoints.decodePolyline(encodedPolyline);
        
        setState(() {
          _routePoints = decodedPolyline
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();
          
          // Process all steps to find the next actual turn
          for (var step in steps) {
            String type = step['maneuver']['type'] ?? '';
            String modifier = step['maneuver']['modifier'] ?? '';
            
            // Skip 'depart' and look for actual turns
            if (type != 'depart') {
              _processTurnDirection(step);
              break;
            }
          }
          
          _updateNextWaypoint();
        });
      } else {
        print('Failed to fetch directions: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('Error fetching directions: $e');
      print('Error stack trace: ${e.toString()}');
    }
  }

  void _processTurnDirection(Map<String, dynamic> step) {
    String type = step['maneuver']['type'] ?? '';
    String modifier = step['maneuver']['modifier'] ?? '';
    double? bearing_before = step['maneuver']['bearing_before']?.toDouble();
    double? bearing_after = step['maneuver']['bearing_after']?.toDouble();

    // Debugging: Print the maneuver type and modifier
    print('Maneuver type: $type, modifier: $modifier');

    setState(() {
      if (type == 'turn' || type == 'new name' || type == 'merge' || 
          type == 'on ramp' || type == 'off ramp' || type == 'depart' ||
          type == 'end of road') {
        if (modifier.contains('left')) {
          _currentTurnDirection = 'L';
        } else if (modifier.contains('right')) {
          _currentTurnDirection = 'R';
        } else {
          _currentTurnDirection = 'S';
        }
      } else if (type == 'roundabout' || type == 'rotary') {
        if (modifier.contains('left')) {
          _currentTurnDirection = 'L';
        } else if (modifier.contains('right')) {
          _currentTurnDirection = 'R';
        } else {
          _currentTurnDirection = 'S';
        }
      } else {
        _currentTurnDirection = 'S';
      }
    });

    // Debugging: Print the determined turn direction
    print('Determined turn direction: $_currentTurnDirection');

    Provider.of<BluetoothConnectionStatus>(context, listen: false)
        .sendData(_currentTurnDirection!);
  }

  void _sendTurnByTurnDirections(List steps) {
    for (var i = 0; i < steps.length; i++) {
      _processTurnDirection(steps[i]);
      Future.delayed(Duration(seconds: 3));
    }
  }

  void _onMapTap(LatLng latLng) {
    setState(() {
      _destination = latLng;
    });
    _getDirections();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map Page'),
      ),
      body: Stack(
        children: [
          _currentLocation == null
              ? const Center(child: CircularProgressIndicator())
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentLocation!,
                    initialZoom: 16.0,
                    onTap: (tapPosition, latLng) => _onMapTap(latLng),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: ['a', 'b', 'c'],
                    ),
                    if (_currentLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _currentLocation!,
                            child: const Icon(
                              Icons.my_location,
                              color: Colors.blue,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    if (_destination != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _destination!,
                            child: const Icon(
                              Icons.flag,
                              color: Colors.red,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    if (_routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePoints,
                            strokeWidth: 4.0,
                            color: Colors.blue,
                          ),
                        ],
                      ),
                  ],
                ),
          if (_nextWaypoint != null)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_currentTurnDirection != null)
                    Card(
                      color: Colors.blue,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _currentTurnDirection == 'L' 
                                ? Icons.turn_left 
                                : _currentTurnDirection == 'R'
                                  ? Icons.turn_right
                                  : Icons.straight,
                              color: Colors.white,
                              size: 30,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _currentTurnDirection == 'L' 
                                ? 'Turn Left'
                                : _currentTurnDirection == 'R'
                                  ? 'Turn Right'
                                  : 'Go Straight',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.directions, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            'Next waypoint: ${(_distanceToNextWaypoint).toStringAsFixed(0)} meters',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
