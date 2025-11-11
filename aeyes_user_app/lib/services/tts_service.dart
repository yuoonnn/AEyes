import 'package:flutter_tts/flutter_tts.dart';
import 'bluetooth_service.dart';
import 'wifi_audio_service.dart';
import 'tts_audio_generator.dart';

class TTSService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;
  AppBluetoothService? _bluetoothService;
  WiFiAudioService? _wifiAudioService;
  TTSAudioGenerator? _audioGenerator;
  
  // Audio output preference
  bool _preferWiFiAudio = true; // Prefer Wi-Fi over phone speaker
  bool _preferBoneConduction = true; // Prefer bone conduction when available
  
  // Store TTS settings (flutter_tts doesn't provide getters)
  String _currentLanguage = 'en-US';
  double _currentSpeechRate = 0.5;

  TTSService() {
    _initTTS();
    _audioGenerator = TTSAudioGenerator();
  }

  /// Set Bluetooth service for bone conduction audio output
  void setBluetoothService(AppBluetoothService? bluetoothService) {
    _bluetoothService = bluetoothService;
  }

  /// Set Wi-Fi audio service for streaming to ESP32-S3
  void setWiFiAudioService(WiFiAudioService? wifiAudioService) {
    _wifiAudioService = wifiAudioService;
  }

  /// Set Google Cloud TTS API key for audio generation
  void setGoogleCloudApiKey(String? apiKey) {
    _audioGenerator?.setGoogleCloudApiKey(apiKey);
  }

  /// Set audio output preference
  void setPreferWiFiAudio(bool prefer) {
    _preferWiFiAudio = prefer;
  }

  /// Set bone conduction preference
  void setPreferBoneConduction(bool prefer) {
    _preferBoneConduction = prefer;
  }

  Future<void> _initTTS() async {
    try {
      // Set proper parameters with correct types and store values
      _currentLanguage = "en-US";
      _currentSpeechRate = 0.5;
      await _flutterTts.setLanguage(_currentLanguage);
      await _flutterTts.setSpeechRate(_currentSpeechRate); // double, not int
      await _flutterTts.setVolume(1.0);     // double, not int
      await _flutterTts.setPitch(1.0);      // double, not int
      
      // Set completion handler
      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
      });
      
      _flutterTts.setErrorHandler((msg) {
        _isSpeaking = false;
        print('TTS Error: $msg');
      });
    } catch (e) {
      print('Error initializing TTS: $e');
    }
  }

  /// Speak text - automatically routes to best available audio output
  /// Priority: Wi-Fi audio (bone conduction) > Bluetooth > Phone speaker
  Future<void> speak(String text, {bool useBoneConduction = false}) async {
    if (_isSpeaking || text.isEmpty) return;
    
    try {
      _isSpeaking = true;
      
      // Determine output method based on preferences and availability
      bool shouldUseBoneConduction = useBoneConduction || _preferBoneConduction;
      
      // Try Wi-Fi audio streaming first (best quality for bone conduction)
      if (shouldUseBoneConduction && 
          _preferWiFiAudio &&
          _wifiAudioService != null && 
          _wifiAudioService!.isConfigured &&
          _audioGenerator != null &&
          _audioGenerator!.isAvailable) {
        try {
          // Generate audio bytes
          final audioBytes = await _audioGenerator!.generateAudio(
            text,
            languageCode: await _getLanguageCode(),
            speakingRate: await _getSpeakingRate(),
          );
          
          if (audioBytes != null && audioBytes.isNotEmpty) {
            // Stream audio via Wi-Fi
            final success = await _wifiAudioService!.streamAudio(
              audioBytes,
              sampleRate: 16000,
              bitsPerSample: 16,
              channels: 1,
            );
            
            if (success) {
              print('TTS audio streamed via Wi-Fi to bone conduction: ${audioBytes.length} bytes');
              _isSpeaking = false; // Reset when streaming completes
              return;
            } else {
              print('Wi-Fi audio streaming failed, trying fallback...');
            }
          }
        } catch (e) {
          print('Error in Wi-Fi audio streaming: $e');
          // Fall through to fallback methods
        }
      }
      
      // Fallback: Try Bluetooth BLE audio (if available)
      if (shouldUseBoneConduction && 
          _bluetoothService != null && 
          _bluetoothService!.isConnected) {
        try {
          await _bluetoothService!.sendTextForTTS(text);
          print('Sent TTS to bone conduction via BLE: $text');
          _isSpeaking = false;
          return;
        } catch (e) {
          print('Error sending TTS via BLE: $e');
          // Fall through to phone speaker
        }
      }
      
      // Final fallback: Use phone speaker
      await _flutterTts.speak(text);
      print('TTS played on phone speaker: $text');
    } catch (e) {
      _isSpeaking = false;
      print('Error in TTS speak: $e');
      rethrow;
    }
  }

  /// Get current language code for TTS
  Future<String> _getLanguageCode() async {
    // Return stored language value
    return _currentLanguage;
  }

  /// Get current speaking rate for TTS
  Future<double> _getSpeakingRate() async {
    // Convert flutter_tts rate (0.0-1.0) to Google Cloud TTS rate (0.25-4.0)
    // Map 0.0-1.0 to 0.5-2.0 (reasonable range)
    return 0.5 + (_currentSpeechRate * 1.5);
  }
  
  /// Set language (also updates stored value)
  Future<void> setLanguage(String language) async {
    _currentLanguage = language;
    await _flutterTts.setLanguage(language);
  }
  
  /// Set speech rate (also updates stored value)
  Future<void> setSpeechRate(double rate) async {
    _currentSpeechRate = rate;
    await _flutterTts.setSpeechRate(rate);
  }

  Future<void> stop() async {
    try {
      await _flutterTts.stop();
      _isSpeaking = false;
    } catch (e) {
      print('Error stopping TTS: $e');
    }
  }

  bool get isSpeaking => _isSpeaking;

  void dispose() {
    _flutterTts.stop();
  }
}