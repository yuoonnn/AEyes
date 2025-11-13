import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'tts_service.dart';

/// Location search service using Mapbox Geocoding API
/// Provides nearby places, place search, and location information
class LocationSearchService {
  final String? _mapboxApiKey;
  final TTSService? _ttsService;
  
  static const String _mapboxBaseUrl = 'https://api.mapbox.com/geocoding/v5/mapbox.places';
  
  LocationSearchService({String? mapboxApiKey, TTSService? ttsService})
      : _mapboxApiKey = mapboxApiKey,
        _ttsService = ttsService;
  
  /// Search for places by name (forward geocoding)
  Future<List<Map<String, dynamic>>> searchPlaces(String query, {Position? currentPosition}) async {
    if (_mapboxApiKey == null || _mapboxApiKey!.isEmpty) {
      return [];
    }
    
    try {
      // Build proximity parameter if we have current position
      String proximityParam = '';
      if (currentPosition != null) {
        proximityParam = '&proximity=${currentPosition.longitude},${currentPosition.latitude}';
      }
      
      final url = Uri.parse(
        '$_mapboxBaseUrl/$query.json?access_token=$_mapboxApiKey&types=poi,address$proximityParam&limit=5'
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
        
        if (features != null) {
          return features.map((feature) {
            final properties = feature['properties'] as Map?;
            final geometry = feature['geometry'] as Map?;
            final coordinates = geometry?['coordinates'] as List?;
            
            return {
              'name': properties?['name'] ?? feature['place_name'] ?? 'Unknown',
              'address': feature['place_name'] ?? '',
              'category': properties?['category'] ?? '',
              'latitude': coordinates != null && coordinates.length >= 2 ? coordinates[1] : null,
              'longitude': coordinates != null && coordinates.length >= 2 ? coordinates[0] : null,
              'distance': currentPosition != null && coordinates != null && coordinates.length >= 2
                  ? Geolocator.distanceBetween(
                      currentPosition.latitude,
                      currentPosition.longitude,
                      coordinates[1],
                      coordinates[0],
                    )
                  : null,
            };
          }).toList();
        }
      }
    } catch (e) {
      print('Error searching places: $e');
    }
    
    return [];
  }
  
  /// Find nearby places by category
  Future<List<Map<String, dynamic>>> findNearbyPlaces({
    required Position position,
    String? category, // e.g., 'restaurant', 'pharmacy', 'hospital', 'store'
    int limit = 5,
  }) async {
    if (_mapboxApiKey == null || _mapboxApiKey!.isEmpty) {
      return [];
    }
    
    try {
      // Build category filter
      String categoryParam = category != null ? '&types=poi&category=$category' : '&types=poi';
      
      final url = Uri.parse(
        '$_mapboxBaseUrl/${position.longitude},${position.latitude}.json?access_token=$_mapboxApiKey$categoryParam&limit=$limit'
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
        
        if (features != null) {
          return features.map((feature) {
            final properties = feature['properties'] as Map?;
            final geometry = feature['geometry'] as Map?;
            final coordinates = geometry?['coordinates'] as List?;
            
            final lat = coordinates != null && coordinates.length >= 2 ? coordinates[1] : position.latitude;
            final lng = coordinates != null && coordinates.length >= 2 ? coordinates[0] : position.longitude;
            
            return {
              'name': properties?['name'] ?? feature['place_name'] ?? 'Unknown',
              'address': feature['place_name'] ?? '',
              'category': properties?['category'] ?? '',
              'latitude': lat,
              'longitude': lng,
              'distance': Geolocator.distanceBetween(
                position.latitude,
                position.longitude,
                lat,
                lng,
              ),
            };
          }).toList()
            ..sort((a, b) {
              final distA = a['distance'] as double? ?? double.infinity;
              final distB = b['distance'] as double? ?? double.infinity;
              return distA.compareTo(distB);
            });
        }
      }
    } catch (e) {
      print('Error finding nearby places: $e');
    }
    
    return [];
  }
  
  /// Get detailed location information
  Future<Map<String, dynamic>?> getLocationDetails(Position position) async {
    if (_mapboxApiKey == null || _mapboxApiKey!.isEmpty) {
      return null;
    }
    
    try {
      final url = Uri.parse(
        '$_mapboxBaseUrl/${position.longitude},${position.latitude}.json?access_token=$_mapboxApiKey&types=poi,address,neighborhood,locality,place'
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
          final mainFeature = features[0];
          final properties = mainFeature['properties'] as Map?;
          final context = mainFeature['context'] as List?;
          
          // Extract address components
          String? street = '';
          String? neighborhood = '';
          String? city = '';
          String? region = '';
          String? country = '';
          
          if (context != null) {
            for (final item in context) {
              final id = item['id'] as String?;
              final text = item['text'] as String?;
              if (id != null && text != null) {
                if (id.startsWith('address')) street = text;
                if (id.startsWith('neighborhood')) neighborhood = text;
                if (id.startsWith('locality')) city = text;
                if (id.startsWith('place')) city = text;
                if (id.startsWith('region')) region = text;
                if (id.startsWith('country')) country = text;
              }
            }
          }
          
          return {
            'name': properties?['name'] ?? mainFeature['place_name'] ?? 'Unknown',
            'fullAddress': mainFeature['place_name'] ?? '',
            'street': street,
            'neighborhood': neighborhood,
            'city': city,
            'region': region,
            'country': country,
            'category': properties?['category'] ?? '',
          };
        }
      }
    } catch (e) {
      print('Error getting location details: $e');
    }
    
    return null;
  }
  
  /// Get bearing (direction) from one point to another
  double getBearing(Position from, Position to) {
    return Geolocator.bearingBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }
  
  /// Format distance in a human-readable way
  String formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.toStringAsFixed(0)} meters';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)} kilometers';
    }
  }
  
  /// Format bearing (direction) in a human-readable way
  String formatBearing(double bearing) {
    // Normalize bearing to 0-360
    double normalized = bearing % 360;
    if (normalized < 0) normalized += 360;
    
    // Convert to cardinal/ordinal directions
    if (normalized >= 337.5 || normalized < 22.5) return 'north';
    if (normalized >= 22.5 && normalized < 67.5) return 'northeast';
    if (normalized >= 67.5 && normalized < 112.5) return 'east';
    if (normalized >= 112.5 && normalized < 157.5) return 'southeast';
    if (normalized >= 157.5 && normalized < 202.5) return 'south';
    if (normalized >= 202.5 && normalized < 247.5) return 'southwest';
    if (normalized >= 247.5 && normalized < 292.5) return 'west';
    if (normalized >= 292.5 && normalized < 337.5) return 'northwest';
    
    return '${normalized.toStringAsFixed(0)} degrees';
  }
  
  /// Announce nearby places via TTS
  Future<void> announceNearbyPlaces({
    required Position position,
    String? category,
    int limit = 3,
  }) async {
    if (_ttsService == null) return;
    
    final places = await findNearbyPlaces(
      position: position,
      category: category,
      limit: limit,
    );
    
    if (places.isEmpty) {
      await _ttsService!.speak('No nearby places found');
      return;
    }
    
    String announcement = category != null 
        ? 'Nearby $category: '
        : 'Nearby places: ';
    
    for (int i = 0; i < places.length && i < limit; i++) {
      final place = places[i];
      final name = place['name'] as String? ?? 'Unknown';
      final distance = place['distance'] as double?;
      
      announcement += name;
      if (distance != null) {
        announcement += ', ${formatDistance(distance)} away';
      }
      if (i < places.length - 1 && i < limit - 1) {
        announcement += '. ';
      }
    }
    
    await _ttsService!.speak(announcement);
  }
  
  /// Search for a place and announce results
  Future<void> searchAndAnnounce(String query, Position? currentPosition) async {
    if (_ttsService == null) return;
    
    final places = await searchPlaces(query, currentPosition: currentPosition);
    
    if (places.isEmpty) {
      await _ttsService!.speak('No places found for $query');
      return;
    }
    
    final place = places[0]; // Get closest match
    final name = place['name'] as String? ?? 'Unknown';
    final address = place['address'] as String? ?? '';
    final distance = place['distance'] as double?;
    
    String announcement = 'Found $name';
    if (distance != null && currentPosition != null) {
      announcement += ', ${formatDistance(distance)} away';
    }
    if (address.isNotEmpty && address != name) {
      announcement += ', at $address';
    }
    
    await _ttsService!.speak(announcement);
  }
}

