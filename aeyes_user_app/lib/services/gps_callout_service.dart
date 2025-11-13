import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'tts_service.dart';

// TimeoutException is part of dart:async, no need to import separately

/// GPS-based callout service using Mapbox Geocoding API
/// Announces location names via TTS periodically (every 2 minutes)
class GPSCalloutService {
  final TTSService _ttsService;
  final String? _mapboxApiKey;
  Timer? _periodicTimer;
  
  // Update interval (3 minutes)
  static const Duration _updateInterval = Duration(minutes: 3);
  
  bool _isEnabled = true;
  
  // Mapbox API configuration
  static const String _mapboxBaseUrl = 'https://api.mapbox.com/geocoding/v5/mapbox.places';
  
  GPSCalloutService(this._ttsService, {String? mapboxApiKey}) 
      : _mapboxApiKey = mapboxApiKey {
    if (_mapboxApiKey == null || _mapboxApiKey!.isEmpty) {
      print('⚠️ Mapbox API key not provided. GPS callouts will be disabled.');
      _isEnabled = false;
    } else {
      print('✅ GPS callout service initialized with Mapbox API key');
    }
  }
  
  /// Get location name from coordinates using Mapbox Geocoding API
  Future<String?> _getLocationName(double latitude, double longitude) async {
    if (_mapboxApiKey == null || _mapboxApiKey!.isEmpty) {
      return null;
    }
    
    try {
      final url = Uri.parse(
        '$_mapboxBaseUrl/$longitude,$latitude.json?access_token=$_mapboxApiKey&types=poi,address,neighborhood,locality'
      );
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Mapbox API request timed out');
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List?;
        
        if (features != null && features.isNotEmpty) {
          // Try to get the most relevant feature
          for (final feature in features) {
            final properties = feature['properties'] as Map?;
            final context = feature['context'] as List?;
            
            // Prefer POI names, then addresses, then neighborhoods
            if (properties != null) {
              final name = properties['name'] as String?;
              final category = properties['category'] as String?;
              
              if (name != null && name.isNotEmpty) {
                // Get locality/place name from context
                String? locality;
                if (context != null) {
                  for (final item in context) {
                    final id = item['id'] as String?;
                    if (id != null && id.startsWith('place')) {
                      locality = item['text'] as String?;
                      break;
                    }
                  }
                }
                
                if (locality != null && locality.isNotEmpty) {
                  return '$name, $locality';
                }
                return name;
              }
            }
            
            // Fallback to place name
            final placeName = feature['place_name'] as String?;
            if (placeName != null && placeName.isNotEmpty) {
              // Extract just the first part (most relevant)
              final parts = placeName.split(',');
              if (parts.isNotEmpty) {
                return parts[0].trim();
              }
            }
          }
        }
      } else {
        print('Mapbox API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error getting location name from Mapbox: $e');
    }
    
    return null;
  }
  
  /// Start periodic GPS callout monitoring (every 2 minutes)
  Future<void> start() async {
    if (!_isEnabled || _mapboxApiKey == null || _mapboxApiKey!.isEmpty) {
      print('GPS callouts disabled - Mapbox API key not configured');
      return;
    }
    
    // Check location permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('Location permission denied - GPS callouts disabled');
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      print('Location permission denied forever - GPS callouts disabled');
      return;
    }
    
    // Stop any existing timer
    _periodicTimer?.cancel();
    
    // Get initial position and announce immediately
    try {
      final initialPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await announceLocation(initialPosition);
    } catch (e) {
      print('Error getting initial position: $e');
    }
    
    // Start periodic timer (every 2 minutes)
    _periodicTimer = Timer.periodic(_updateInterval, (timer) async {
      await _updateLocationAndAnnounce();
    });
    
    print('GPS callout service started (updates every 3 minutes)');
  }
  
  /// Update location and announce
  Future<void> _updateLocationAndAnnounce() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await announceLocation(position);
    } catch (e) {
      print('Error updating location for GPS callout: $e');
    }
  }
  
  /// Stop GPS callout monitoring
  void stop() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    print('GPS callout service stopped');
  }
  
  /// Announce location via TTS (public method for manual refresh)
  Future<void> announceLocation(Position position) async {
    if (!_isEnabled || _mapboxApiKey == null || _mapboxApiKey!.isEmpty) return;
    
    // Get location name from Mapbox
    final locationName = await _getLocationName(
      position.latitude,
      position.longitude,
    );
    
    if (locationName != null && locationName.isNotEmpty) {
      // Announce via TTS
      try {
        await _ttsService.stop(); // Stop any current TTS
        await _ttsService.speak('You are at $locationName');
        print('📍 GPS callout: $locationName');
      } catch (e) {
        print('Error announcing location: $e');
      }
    } else {
      // Fallback: announce coordinates if name lookup fails
      try {
        await _ttsService.stop();
        await _ttsService.speak(
          'Location: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}'
        );
        print('📍 GPS callout: coordinates only');
      } catch (e) {
        print('Error announcing coordinates: $e');
      }
    }
  }
  
  bool get isEnabled => _isEnabled;
  
  void dispose() {
    stop();
  }
}

