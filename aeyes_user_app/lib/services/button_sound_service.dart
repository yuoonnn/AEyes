import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Handles playback of short beep sounds when hardware buttons are pressed.
///
/// The beeps are generated programmatically so no audio assets are required.
/// Button 2 (capture) uses a medium tone, button 3 uses a lower tone,
/// while buttons 4–6 share the same higher tone.
class ButtonSoundService {
  ButtonSoundService._internal();

  static final ButtonSoundService _instance = ButtonSoundService._internal();

  factory ButtonSoundService() => _instance;

  final AudioPlayer _player = AudioPlayer(
    playerId: 'button-beep',
  );

  Uint8List? _standardBeep;
  Uint8List? _deepBeep;
  Uint8List? _captureBeep;
  double _volume = 0.5;
  bool _initialized = false;
  bool _initializing = false;

  /// Sets the playback volume (0.0 – 1.0).
  void setVolume(double value) {
    _volume = value.clamp(0.0, 1.0);
  }

  /// Plays the appropriate beep sound for the given button event.
  ///
  /// `buttonData` follows the format `<id>:<event>` as emitted by the ESP32.
  /// Button 1 is silent, button 2 (capture) has a medium tone, button 3 has
  /// a distinct lower tone, while buttons 4–6 share the same higher tone.
  Future<void> playForButtonEvent(String buttonData) async {
    final colonIndex = buttonData.indexOf(':');
    final buttonId =
        colonIndex == -1 ? buttonData.trim() : buttonData.substring(0, colonIndex).trim();

    // Ignore unknown or muted buttons.
    if (buttonId.isEmpty || buttonId == '1') {
      return;
    }

    // Only play on release notifications to prevent double-beeps.
    final event =
        colonIndex == -1 ? null : buttonData.substring(colonIndex + 1).trim().toUpperCase();
    if (event == null) {
      // Fallback: play once if we cannot determine the event type.
    } else if (!_shouldPlayForEvent(event)) {
      return;
    }

    await _ensureInitialized();

    final beepBytes = buttonId == '2'
        ? _captureBeep
        : buttonId == '3'
            ? _deepBeep
            : _standardBeep;
    if (beepBytes == null) {
      return;
    }

    try {
      // Restart the player to guarantee the beep plays promptly.
      await _player.stop();
      await _player.play(BytesSource(beepBytes), volume: _volume);
      debugPrint('🔈 Button $buttonId beep played at volume $_volume');
    } catch (error, stackTrace) {
      debugPrint('⚠️ Failed to play button beep: $error\n$stackTrace');
    }
  }

  Future<void> _ensureInitialized() async {
    if (_initialized || _initializing) {
      while (_initializing) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      return;
    }

    _initializing = true;
    try {
      await _player.setPlayerMode(PlayerMode.mediaPlayer);
      _standardBeep ??= _generateBeepBytes(
        frequencyHz: 880, // Bright tone for buttons 4–6
        durationMs: 120,
      );
      _deepBeep ??= _generateBeepBytes(
        frequencyHz: 440, // Lower tone for button 3
        durationMs: 140,
      );
      _captureBeep ??= _generateBeepBytes(
        frequencyHz: 660, // Medium tone for button 2 (capture)
        durationMs: 100,
      );
      _initialized = true;
    } finally {
      _initializing = false;
    }
  }

  bool _shouldPlayForEvent(String event) {
    // ESP32 emits events such as PTT_SHORT, PTT_LONG, MEDIA_PLAYPAUSE, etc.
    // We play sounds for primary actions and ignore secondary status updates.
    const allowedEventSuffixes = <String>[
      'SHORT',
      'LONG',
      'CAPTURE',
      'MEDIA_PLAYPAUSE',
      'MEDIA_LONG',
      'VOLUME_UP',
      'VOLUME_DOWN',
      'SKIP_TRACK',
      'PREVIOUS_TRACK',
    ];

    for (final suffix in allowedEventSuffixes) {
      if (event.endsWith(suffix)) {
        return true;
      }
    }
    return false;
  }

  Uint8List _generateBeepBytes({
    required double frequencyHz,
    required int durationMs,
    int sampleRate = 44100,
  }) {
    final sampleCount = (sampleRate * durationMs / 1000).round();
    final bytesPerSample = 2; // 16-bit PCM
    final byteCount = sampleCount * bytesPerSample;
    final data = BytesBuilder();

    // WAV header
    data.add(_asciiBytes('RIFF'));
    data.add(_int32ToBytes(36 + byteCount));
    data.add(_asciiBytes('WAVE'));
    data.add(_asciiBytes('fmt '));
    data.add(_int32ToBytes(16)); // PCM header size
    data.add(_int16ToBytes(1)); // Audio format = 1 (PCM)
    data.add(_int16ToBytes(1)); // Mono
    data.add(_int32ToBytes(sampleRate));
    data.add(_int32ToBytes(sampleRate * bytesPerSample));
    data.add(_int16ToBytes(bytesPerSample));
    data.add(_int16ToBytes(16)); // Bits per sample
    data.add(_asciiBytes('data'));
    data.add(_int32ToBytes(byteCount));

    final tone = BytesBuilder();
    final amplitude = 32767 * 0.7;
    for (var i = 0; i < sampleCount; i++) {
      final time = i / sampleRate;
      final envelope = _hannWindow(i, sampleCount);
      final sampleValue = (sin(2 * pi * frequencyHz * time) * amplitude * envelope).round();
      tone.add(_int16ToBytes(sampleValue));
    }

    data.add(tone.toBytes());
    return data.toBytes();
  }

  List<int> _asciiBytes(String value) => value.codeUnits;

  List<int> _int16ToBytes(int value) => Uint8List(2)
    ..buffer.asByteData().setInt16(0, value, Endian.little);

  List<int> _int32ToBytes(int value) => Uint8List(4)
    ..buffer.asByteData().setInt32(0, value, Endian.little);

  double _hannWindow(int index, int sampleCount) {
    if (sampleCount <= 1) return 1.0;
    return 0.5 * (1 - cos((2 * pi * index) / (sampleCount - 1)));
  }
}

