import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';

class MapScreen extends StatefulWidget {
  final String userId;
  
  const MapScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  double? _userLat;
  double? _userLng;
  bool _isLoading = true;
  final MapController _mapController = MapController();
  
  // Mapbox API key - same as used in home_screen.dart
  static const String _mapboxApiKey = 'pk.eyJ1IjoiY2hyaXNzZWdncyIsImEiOiJjbWh4aW4wbGkwMXA4MnFzaHVjaGc3NDgwIn0.I51_0mt0LivtIciiYF9jSw';
  
  // Mapbox tile URL template
  String get _mapboxTileUrl => 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token=$_mapboxApiKey';
  
  @override
  void initState() {
    super.initState();
    _loadUserLocation();
  }
  
  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadUserLocation() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('locations')
          .where('user_id', isEqualTo: widget.userId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty && mounted) {
        final locationData = snapshot.docs.first.data();
        final lat = locationData['latitude'];
        final lng = locationData['longitude'];
        
        if (lat != null && lng != null) {
          setState(() {
            _userLat = (lat as num).toDouble();
            _userLng = (lng as num).toDouble();
            _isLoading = false;
          });
          
          // Move map to user location after a short delay
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && _userLat != null && _userLng != null) {
              _mapController.move(
                LatLng(_userLat!, _userLng!),
                15.0,
              );
            }
          });
        } else {
          setState(() => _isLoading = false);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading user location: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading location')),
        );
      }
    }
  }
  
  void _centerOnUser() {
    if (_userLat != null && _userLng != null) {
      _mapController.move(
        LatLng(_userLat!, _userLng!),
        15.0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Location'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _centerOnUser,
            tooltip: 'Center on User',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadUserLocation();
            },
            tooltip: 'Refresh Location',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userLat == null || _userLng == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_off, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No location data available',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    // Mapbox Map using flutter_map
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: LatLng(_userLat!, _userLng!),
                        initialZoom: 15.0,
                        minZoom: 5.0,
                        maxZoom: 18.0,
                      ),
                      children: [
                        // Mapbox tiles
                        TileLayer(
                          urlTemplate: _mapboxTileUrl,
                          additionalOptions: {
                            'accessToken': _mapboxApiKey,
                          },
                          userAgentPackageName: 'com.example.aeyesUserApp',
                        ),
                        // Marker for user location
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(_userLat!, _userLng!),
                              width: 40,
                              height: 40,
                              child: Icon(
                                Icons.location_on,
                                color: AppTheme.error,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    // Location Info Overlay
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    color: AppTheme.error,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'User Location',
                                    style: AppTheme.textStyleTitle.copyWith(
                                      fontWeight: AppTheme.fontWeightBold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Latitude: ${_userLat!.toStringAsFixed(6)}',
                                style: AppTheme.textStyleBody,
                              ),
                              Text(
                                'Longitude: ${_userLng!.toStringAsFixed(6)}',
                                style: AppTheme.textStyleBody,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
