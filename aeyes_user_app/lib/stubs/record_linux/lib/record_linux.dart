// Stub implementation for record_linux
// This app only targets Android/iOS, so this is never used

import 'dart:async';
import 'dart:typed_data';

import 'package:record_platform_interface/record_platform_interface.dart';

/// Stub implementation - never used for Android/iOS builds
class RecordLinux extends RecordPlatform {
  static void registerWith() {
    RecordPlatform.instance = RecordLinux();
  }

  Never _unsupported(String message) =>
      throw UnimplementedError('record_linux is not supported: $message');

  @override
  Future<void> create(String recorderId) async =>
      _unsupported('create($recorderId)');

  @override
  Future<void> start(String recorderId, RecordConfig config,
          {required String path}) async =>
      _unsupported('start($recorderId)');

  @override
  Future<Stream<Uint8List>> startStream(
          String recorderId, RecordConfig config) async =>
      _unsupported('startStream($recorderId)');

  @override
  Future<String?> stop(String recorderId) async =>
      _unsupported('stop($recorderId)');

  @override
  Future<void> pause(String recorderId) async =>
      _unsupported('pause($recorderId)');

  @override
  Future<void> resume(String recorderId) async =>
      _unsupported('resume($recorderId)');

  @override
  Future<bool> isRecording(String recorderId) async => false;

  @override
  Future<bool> isPaused(String recorderId) async => false;

  @override
  Future<bool> hasPermission(String recorderId) async => false;

  @override
  Future<void> dispose(String recorderId) async {}

  @override
  Future<Amplitude> getAmplitude(String recorderId) async =>
      Amplitude(current: -160, max: -160);

  @override
  Future<bool> isEncoderSupported(
          String recorderId, AudioEncoder encoder) async =>
      false;

  @override
  Future<List<InputDevice>> listInputDevices(String recorderId) async =>
      const [];

  @override
  Future<void> cancel(String recorderId) async {}

  @override
  Stream<RecordState> onStateChanged(String recorderId) => const Stream.empty();
}
