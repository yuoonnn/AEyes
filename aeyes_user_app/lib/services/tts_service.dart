import 'package:flutter_tts/flutter_tts.dart';
import 'bluetooth_service.dart';

class TTSService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;
  AppBluetoothService? _bluetoothService;

  TTSService() {
    _initTTS();
  }

  /// Set Bluetooth service for bone conduction audio output
  void setBluetoothService(AppBluetoothService? bluetoothService) {
    _bluetoothService = bluetoothService;
  }

  Future<void> _initTTS() async {
    try {
      // Set proper parameters with correct types
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5); // double, not int
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

  /// Speak text - optionally send to bone conduction if Bluetooth is connected
  Future<void> speak(String text, {bool useBoneConduction = false}) async {
    if (_isSpeaking || text.isEmpty) return;
    
    try {
      _isSpeaking = true;
      
      // If bone conduction is requested and Bluetooth is connected, send to ESP32
      if (useBoneConduction && 
          _bluetoothService != null && 
          _bluetoothService!.isConnected) {
        await _bluetoothService!.sendTextForTTS(text);
        print('Sent TTS to bone conduction: $text');
      } else {
        // Otherwise use phone speaker
        await _flutterTts.speak(text);
      }
    } catch (e) {
      _isSpeaking = false;
      print('Error in TTS speak: $e');
      rethrow;
    }
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