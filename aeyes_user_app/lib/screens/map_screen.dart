import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

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

  @override
  void initState() {
    super.initState();
    _loadUserLocation();
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
          });
        }
      }
    } catch (e) {
      print('Error loading user location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading location')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openInOpenStreetMap() async {
  if (_userLat == null || _userLng == null) return;
  
  // Correct OpenStreetMap URL format
  final url = 'https://www.openstreetmap.org/?mlat=$_userLat&mlon=$_userLng&map=15/$_userLat/$_userLng';
  
  try {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } else {
      throw 'Could not launch URL';
    }
  } catch (e) {
    print('Error opening OpenStreetMap: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open OpenStreetMap')),
      );
    }
  }
}

  Future<void> _openInGoogleMaps() async {
  if (_userLat == null || _userLng == null) return;
  
  // Correct Google Maps URL format
  final url = 'https://www.google.com/maps?q=$_userLat,$_userLng';
  
  try {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } else {
      throw 'Could not launch URL';
    }
  } catch (e) {
    print('Error opening Google Maps: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps')),
      );
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Location'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUserLocation,
            tooltip: 'Refresh Location',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userLat == null || _userLng == null
              ? const Center(child: Text('No location data available'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Location Info Card
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'User Location',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const Icon(Icons.location_pin, color: Colors.red, size: 40),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Latitude: ${_userLat!.toStringAsFixed(6)}',
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                        Text(
                                          'Longitude: ${_userLng!.toStringAsFixed(6)}',
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Open in Maps Buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.map),
                                      label: const Text('OpenStreetMap'),
                                      onPressed: _openInOpenStreetMap,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.map),
                                      label: const Text('Google Maps'),
                                      onPressed: _openInGoogleMaps,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Simple Map Preview Placeholder
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Location Preview',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                height: 200,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.map_outlined, size: 50, color: Colors.grey),
                                      SizedBox(height: 8),
                                      Text('Tap buttons above to view in maps'),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Use the buttons above to open in full maps application',
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}