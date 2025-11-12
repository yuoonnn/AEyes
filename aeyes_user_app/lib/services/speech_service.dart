// Temporarily disabled due to speech_to_text plugin compatibility issues
// import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'openai_service.dart';

/// Service for handling voice control using the device's microphone
/// Records audio when ESP32 button is pressed, then processes to text
class SpeechService {
  // final stt.SpeechToText _speech = stt.SpeechToText(); // Disabled
  final AudioRecorder _audioRecorder = AudioRecorder();
  final OpenAIService? _openAIService;
  bool _isListening = false;
  bool _isAvailable = false;
  bool _isRecording = false;
  String _lastWords = '';
  String? _currentRecordingPath;

  // Callback for when speech is recognized
  Function(String)? onSpeechResult;

  // Callback for when listening status changes
  Function(bool)? onListeningStatusChanged;

  // Callback for errors
  Function(String)? onError;

  SpeechService({OpenAIService? openAIService})
    : _openAIService = openAIService;

  bool get isListening => _isListening;
  bool get isAvailable => _isAvailable;
  bool get isRecording => _isRecording;
  String get lastWords => _lastWords;

  /// Initialize the speech recognition service
  Future<bool> initialize() async {
    try {
      // Request microphone permission
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        onError?.call('Microphone permission denied');
        return false;
      }

      // Check if audio recorder is available
      if (await _audioRecorder.hasPermission()) {
        _isAvailable = true;
        return true;
      } else {
        onError?.call('Audio recording not available on this device');
        return false;
      }
    } catch (e) {
      onError?.call('Failed to initialize audio recording: $e');
      return false;
    }
  }

  /// Start recording audio (triggered by ESP32 button press)
  Future<void> startRecording() async {
    if (_isRecording) {
      return; // Already recording
    }

    if (!_isAvailable) {
      final initialized = await initialize();
      if (!initialized) {
        return;
      }
    }

    try {
      // Get temporary file path for recording
      final directory = Directory.systemTemp;
      _currentRecordingPath =
          '${directory.path}/voice_command_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentRecordingPath!,
      );

      _isRecording = true;
      onListeningStatusChanged?.call(true);
    } catch (e) {
      onError?.call('Failed to start recording: $e');
      _isRecording = false;
    }
  }

  /// Stop recording and process audio to text (triggered by ESP32 button release)
  Future<String?> stopRecording() async {
    if (!_isRecording) {
      return null;
    }

    try {
      final path = await _audioRecorder.stop();
      _isRecording = false;
      onListeningStatusChanged?.call(false);

      if (path == null || path.isEmpty) {
        onError?.call('Recording path is null or empty');
        return null;
      }

      // Process audio to text
      // TODO: Implement speech-to-text conversion
      // For now, we'll need to use a service or re-enable speech_to_text
      // This is a placeholder - you'll need to implement actual STT
      final text = await _processAudioToText(path);

      // Clean up recording file
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        // Ignore cleanup errors
      }

      _currentRecordingPath = null;
      return text;
    } catch (e) {
      onError?.call('Failed to stop recording: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Process recorded audio file to text using OpenAI Whisper API
  Future<String?> _processAudioToText(String audioPath) async {
    final openAIService = _openAIService;
    if (openAIService == null) {
      onError?.call('OpenAI service not available for speech-to-text');
      return null;
    }

    try {
      final text = await openAIService.transcribeAudio(audioPath);
      if (text.isNotEmpty) {
        return text.trim();
      } else {
        onError?.call('No text extracted from audio');
        return null;
      }
    } catch (e) {
      onError?.call('Failed to transcribe audio: $e');
      return null;
    }
  }

  /// Start listening for voice commands
  /// NOTE: Temporarily disabled
  Future<void> startListening({
    String localeId = 'en_US',
    bool listenFor = true,
    Duration? pauseFor,
    dynamic listenMode, // Changed from stt.ListenMode? to dynamic
    bool cancelOnError = false,
    bool partialResults = true,
    bool onDevice = false,
  }) async {
    onError?.call('Speech recognition temporarily disabled');
    return;

    /* Original code - disabled
    if (!_isAvailable) {
      final initialized = await initialize();
      if (!initialized) {
        return;
      }
    }

    if (_isListening) {
      return;
    }

    try {
      await _speech.listen(
        onResult: (result) {
          _lastWords = result.recognizedWords;
          
          if (result.finalResult) {
            // Only process final results
            onSpeechResult?.call(result.recognizedWords);
            _lastWords = '';
          } else if (partialResults) {
            // Optionally handle partial results
            // onSpeechResult?.call(result.recognizedWords);
          }
        },
        localeId: localeId,
        listenFor: listenFor ? const Duration(seconds: 30) : null,
        pauseFor: pauseFor ?? const Duration(seconds: 3),
        listenMode: listenMode ?? stt.ListenMode.confirmation,
        cancelOnError: cancelOnError,
        partialResults: partialResults,
        onDevice: onDevice,
      );
    } catch (e) {
      onError?.call('Failed to start listening: $e');
    }
    */
  }

  /// Stop listening for voice commands
  /// NOTE: Temporarily disabled
  Future<void> stopListening() async {
    if (!_isListening) return;

    _isListening = false;
    onListeningStatusChanged?.call(false);

    /* Original code - disabled
    try {
      await _speech.stop();
      _isListening = false;
      onListeningStatusChanged?.call(false);
    } catch (e) {
      onError?.call('Failed to stop listening: $e');
    }
    */
  }

  /// Cancel listening (discards current results)
  /// NOTE: Temporarily disabled
  Future<void> cancelListening() async {
    if (!_isListening) return;

    _isListening = false;
    _lastWords = '';
    onListeningStatusChanged?.call(false);

    /* Original code - disabled
    try {
      await _speech.cancel();
      _isListening = false;
      _lastWords = '';
      onListeningStatusChanged?.call(false);
    } catch (e) {
      onError?.call('Failed to cancel listening: $e');
    }
    */
  }

  /// Check if microphone permission is granted
  Future<bool> checkPermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// Request microphone permission
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Get available locales for speech recognition
  /// NOTE: Temporarily disabled - returns empty list
  Future<List<dynamic>> getAvailableLocales() async {
    // Temporarily disabled
    return [];

    /* Original code - disabled
    if (!_isAvailable) {
      await initialize();
    }
    return _speech.locales();
    */
  }

  void dispose() async {
    if (_isRecording) {
      await _audioRecorder.stop();
    }
    await _audioRecorder.dispose();
    _isListening = false;
    _isRecording = false;
  }
}
