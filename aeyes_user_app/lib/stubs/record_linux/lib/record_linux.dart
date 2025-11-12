// Stub implementation for record_linux
// This app only targets Android/iOS, so this is never used

import 'dart:typed_data';
import 'package:record_platform_interface/record_platform_interface.dart';

/// Stub implementation - never used for Android/iOS builds
class RecordLinux extends RecordPlatform {
  @override
  Future<void> dispose() async {
    // Stub - never called
  }

  @override
  Future<bool> hasPermission() async {
    return false; // Stub
  }

  @override
  Future<Amplitude> getAmplitude() async {
    return Amplitude(current: -160, max: 0);
  }

  @override
  Future<bool> isPaused() async {
    return false;
  }

  @override
  Future<bool> isRecording() async {
    return false;
  }

  @override
  Future<void> pause() async {
    // Stub
  }

  @override
  Future<void> resume() async {
    // Stub
  }

  @override
  Future<void> start(RecordConfig config, {String? path}) async {
    throw UnimplementedError('record_linux is not supported (Android/iOS only app)');
  }

  @override
  Future<String?> stop() async {
    throw UnimplementedError('record_linux is not supported (Android/iOS only app)');
  }

  @override
  Future<void> cancel() async {
    // Stub
  }

  @override
  Future<Stream<Uint8List>> startStream(String recorderId, RecordConfig config) async {
    throw UnimplementedError('record_linux is not supported (Android/iOS only app)');
  }
}
