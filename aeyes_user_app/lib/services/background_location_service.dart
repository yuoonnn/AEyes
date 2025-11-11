import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'database_service.dart';

/// Background location tracking service
/// Updates user location every 30 seconds or on significant movement
class BackgroundLocationService {
  final DatabaseService _databaseService = DatabaseService();
  Timer? _periodicTimer;
  StreamSubscription<Position>? _positionStream;
  
  // Use ValueNotifier for real-time status updates
  final ValueNotifier<bool> isTracking = ValueNotifier<bool>(false);
  
  Position? _lastSavedPosition;
  
  // Minimum distance in meters to trigger a location update (50 meters)
  static const int _minDistanceForUpdate = 50;
  
  // Update interval in seconds (30 seconds)
  static const Duration _updateInterval = Duration(seconds: 30);

  /// Start background location tracking
  Future<bool> startTracking() async {
    if (isTracking.value) {
      print('Location tracking already started');
      return true;
    }

    // Check permissions
    final hasPermission = await _checkLocationPermission();
    if (!hasPermission) {
      print('Location permission not granted');
      isTracking.value = false;
      return false;
    }

    // Check if location services are enabled
    final isEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isEnabled) {
      print('Location services not enabled');
      isTracking.value = false;
      return false;
    }

    try {
      // Update status immediately
      isTracking.value = true;
      
      // Get initial location and save it
      final initialPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await _saveLocation(initialPosition);
      _lastSavedPosition = initialPosition;

      // Start periodic updates (every 30 seconds)
      _periodicTimer = Timer.periodic(_updateInterval, (timer) async {
        await _updateLocationPeriodically();
      });

      // Start listening for significant position changes
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: _minDistanceForUpdate,
        ),
      ).listen(
        (Position position) async {
          await _saveLocationIfSignificant(position);
        },
        onError: (error) {
          print('Error in position stream: $error');
          // If there's an error, stop tracking
          stopTracking();
        },
      );

      print('Background location tracking started');
      return true;
    } catch (e) {
      print('Error starting location tracking: $e');
      isTracking.value = false;
      return false;
    }
  }

  /// Stop background location tracking
  void stopTracking() {
    if (!isTracking.value) return;

    _periodicTimer?.cancel();
    _periodicTimer = null;
    
    _positionStream?.cancel();
    _positionStream = null;
    
    // Update status
    isTracking.value = false;
    _lastSavedPosition = null;
    
    print('Background location tracking stopped');
  }

  /// Get current tracking status (for compatibility with existing code)
  bool get isTrackingStatus => isTracking.value;

  /// Periodic location update (every 30 seconds)
  Future<void> _updateLocationPeriodically() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await _saveLocation(position);
      _lastSavedPosition = position;
    } catch (e) {
      print('Error in periodic location update: $e');
      // If we can't get location, stop tracking
      stopTracking();
    }
  }

  /// Save location if user has moved significantly
  Future<void> _saveLocationIfSignificant(Position position) async {
    if (_lastSavedPosition == null) {
      await _saveLocation(position);
      _lastSavedPosition = position;
      return;
    }

    // Calculate distance from last saved position
    final distance = Geolocator.distanceBetween(
      _lastSavedPosition!.latitude,
      _lastSavedPosition!.longitude,
      position.latitude,
      position.longitude,
    );

    // Only save if moved more than minimum distance
    if (distance >= _minDistanceForUpdate) {
      await _saveLocation(position);
      _lastSavedPosition = position;
      print('Location updated due to movement: ${distance.toStringAsFixed(2)}m');
    }
  }

  /// Save location to Firestore
  Future<void> _saveLocation(Position position) async {
    try {
      await _databaseService.saveLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
      );
      print('Location saved: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      print('Error saving location: $e');
      // If we can't save to database, stop tracking
      stopTracking();
    }
  }

  /// Check location permission
  Future<bool> _checkLocationPermission() async {
    // Check foreground location permission
    var status = await Permission.location.status;
    if (!status.isGranted) {
      status = await Permission.location.request();
      if (!status.isGranted) {
        return false;
      }
    }

    // For Android 10+ (API 29+), also check background location permission
    if (await _isAndroid10OrHigher()) {
      var backgroundStatus = await Permission.locationAlways.status;
      if (!backgroundStatus.isGranted) {
        // Request background location permission
        backgroundStatus = await Permission.locationAlways.request();
        if (!backgroundStatus.isGranted) {
          print('Background location permission not granted, but continuing with foreground tracking');
          // Continue anyway - will work when app is in foreground
        }
      }
    }

    return true;
  }

  /// Check if Android version is 10 or higher (API 29+)
  Future<bool> _isAndroid10OrHigher() async {
    try {
      final status = await Permission.locationAlways.status;
      return true; // If we can check this, we're on Android 10+
    } catch (e) {
      return false; // Probably iOS or older Android
    }
  }

  /// Dispose resources
  void dispose() {
    stopTracking();
    isTracking.dispose(); // Important: dispose the ValueNotifier
  }
}