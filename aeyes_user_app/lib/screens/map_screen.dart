import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/location_service.dart';
import '../services/database_service.dart';

class MapScreen extends StatefulWidget {
  final String? userId; // If provided, show this user's location (for guardians)
  
  const MapScreen({Key? key, this.userId}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final LocationService _locationService = LocationService();
  final DatabaseService _databaseService = DatabaseService();
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  LatLng? _userLocation;
  bool _isLoading = true;
  String _errorMessage = '';
  final List<Marker> _markers = [];

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    try {
      // If userId is provided (guardian viewing user's location), get user's location
      if (widget.userId != null) {
        await _loadUserLocation(widget.userId!);
      } else {
        // Otherwise, get current user's location
        await _loadCurrentLocation();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading location: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCurrentLocation() async {
    // Check permission
    final hasPermission = await _locationService.checkLocationPermission();
    if (!hasPermission) {
      final granted = await _locationService.requestLocationPermission();
      if (!granted) {
        setState(() {
          _errorMessage = 'Location permission denied';
          _isLoading = false;
        });
        return;
      }
    }

    // Get current location
    final position = await _locationService.getCurrentLocation();
    if (position != null) {
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _markers.clear();
        _markers.add(
          Marker(
            point: _currentLocation!,
            width: 50,
            height: 50,
            child: const Tooltip(
              message: 'Your Location',
              child: Icon(Icons.location_on, color: Colors.blue, size: 50),
            ),
          ),
        );
        _isLoading = false;
      });

      // Move camera to current location
      _mapController.move(_currentLocation!, 15.0);

      // Save location to Firestore
      await _locationService.saveCurrentLocation();
    } else {
      setState(() {
        _errorMessage = 'Could not get current location';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserLocation(String userId) async {
    try {
      final location = await _locationService.getLatestUserLocation(userId);
      
      if (location != null && location['latitude'] != null && location['longitude'] != null) {
        setState(() {
          _userLocation = LatLng(
            (location['latitude'] as num).toDouble(),
            (location['longitude'] as num).toDouble(),
          );
          _markers.clear();
          _markers.add(
            Marker(
              point: _userLocation!,
              width: 50,
              height: 50,
              child: const Tooltip(
                message: 'User Location',
                child: Icon(Icons.location_on, color: Colors.red, size: 50),
              ),
            ),
          );
          _isLoading = false;
        });

        _mapController.move(_userLocation!, 15.0);
      } else {
        // Fallback to default location if no location found
        setState(() {
          _userLocation = const LatLng(14.5995, 120.9842);
          _markers.clear();
          _markers.add(
            Marker(
              point: _userLocation!,
              width: 50,
              height: 50,
              child: const Tooltip(
                message: 'User Location (Default)',
                child: Icon(Icons.location_on, color: Colors.red, size: 50),
              ),
            ),
          );
          _isLoading = false;
        });
        _mapController.move(_userLocation!, 15.0);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading user location: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userId != null ? 'User Location' : 'My Location'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () async {
              if (_currentLocation != null) {
                _mapController.move(_currentLocation!, 15.0);
              } else {
                await _loadCurrentLocation();
              }
            },
            tooltip: 'Center on my location',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage,
                        style: TextStyle(color: Colors.red.shade700),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _errorMessage = '';
                            _isLoading = true;
                          });
                          _initializeMap();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : (_currentLocation == null && _userLocation == null)
                  ? const Center(child: Text('No location available'))
                  : FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _currentLocation ?? _userLocation ?? const LatLng(14.5995, 120.9842),
                        initialZoom: 15.0,
                        minZoom: 3.0,
                        maxZoom: 18.0,
                      ),
                      children: [
                        // OpenStreetMap tile layer (completely free, no API key needed)
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.aeyesUserApp',
                          maxZoom: 19,
                        ),
                        // Markers layer
                        MarkerLayer(
                          markers: _markers,
                        ),
                      ],
                    ),
    );
  }
}
