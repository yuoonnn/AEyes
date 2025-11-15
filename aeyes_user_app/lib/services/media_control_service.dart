import 'package:flutter/services.dart';
import 'dart:developer' as developer;

/// Service to control system media playback (music apps like Spotify, YouTube Music, etc.)
class MediaControlService {
  static const MethodChannel _channel = MethodChannel('com.aeyes.media_control');
  static bool _initialized = false;
  static bool _hasPermission = false;
  static bool _promptedForPermission = false;

  /// Initialize the media control service
  static Future<void> initialize() async {
    try {
      final granted = await _channel.invokeMethod<bool>('initialize') ?? false;
      _hasPermission = granted;
      _initialized = true;
      if (!granted) {
        developer.log(
          '⚠️ Media control requires notification access. Prompting user to enable it.',
        );
      } else {
        developer.log('✅ Media control service initialized');
      }
    } catch (e) {
      developer.log('⚠️ Media control initialization failed: $e');
    }
  }

  static Future<bool> hasPermission() async {
    try {
      final granted = await _channel.invokeMethod<bool>('hasPermission') ?? false;
      _hasPermission = granted;
      return granted;
    } catch (e) {
      developer.log('⚠️ Failed to check media control permission: $e');
      return false;
    }
  }

  static Future<void> requestPermission() async {
    try {
      await _channel.invokeMethod('requestPermission');
      developer.log('ℹ️ Opened notification access settings for media controls');
    } catch (e) {
      developer.log('⚠️ Failed to open notification access settings: $e');
    }
  }

  static Future<bool> _ensurePermission() async {
    if (!_initialized) {
      await initialize();
    }
    if (_hasPermission) return true;

    final granted = await hasPermission();
    if (!granted && !_promptedForPermission) {
      _promptedForPermission = true;
      developer.log(
        '⚠️ Notification access is required so the watch buttons can control media playback.',
      );
      await requestPermission();
    }
    _hasPermission = granted;
    return granted;
  }

  static Future<T?> _invokeWithPermission<T>(String method) async {
    if (!await _ensurePermission()) {
      developer.log('❌ Media control unavailable: notification access not granted');
      return null;
    }
    try {
      final result = await _channel.invokeMethod<T>(method);
      return result;
    } on PlatformException catch (e) {
      developer.log('❌ $method failed: ${e.message ?? e.code}');
    } catch (e) {
      developer.log('❌ $method failed: $e');
    }
    return null;
  }

  /// Play or pause media playback
  static Future<void> playPause() async {
    await _invokeWithPermission('playPause');
  }

  /// Skip to next track
  static Future<void> nextTrack() async {
    await _invokeWithPermission('nextTrack');
  }

  /// Go to previous track
  static Future<void> previousTrack() async {
    await _invokeWithPermission('previousTrack');
  }

  /// Increase volume
  static Future<void> volumeUp() async {
    await _invokeWithPermission('volumeUp');
  }

  /// Decrease volume
  static Future<void> volumeDown() async {
    await _invokeWithPermission('volumeDown');
  }

  /// Handle button event from ESP32
  /// Format: "buttonId:event" (e.g., "4:MEDIA_PLAYPAUSE", "5:VOLUME_UP")
  static Future<void> handleButtonEvent(String buttonData) async {
    if (!buttonData.contains(':')) {
      developer.log('⚠️ Invalid button data format: $buttonData');
      return;
    }

    final parts = buttonData.split(':');
    if (parts.length < 2) return;

    final buttonId = parts[0];
    final event = parts[1];

    developer.log('🎮 Media control button: $buttonId -> $event');

    switch (event) {
      case 'MEDIA_PLAYPAUSE':
        await playPause();
        break;
      case 'MEDIA_LONG':
        // Long press on media button (5s) - could be used for additional media control
        // For now, just toggle play/pause as a fallback action
        developer.log('🎮 Media button long press - toggling play/pause');
        await playPause();
        break;
      case 'VOLUME_UP':
        await volumeUp();
        break;
      case 'VOLUME_DOWN':
        await volumeDown();
        break;
      case 'SKIP_TRACK':
        await nextTrack();
        break;
      case 'PREVIOUS_TRACK':
        await previousTrack();
        break;
      default:
        developer.log('⚠️ Unknown media control event: $event');
    }
  }
}

