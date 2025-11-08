import 'package:flutter_tts/flutter_tts.dart';
import '../services/database_service.dart';
import '../models/settings.dart';

class TTSService {
  final FlutterTts _tts = FlutterTts();
  final DatabaseService _databaseService = DatabaseService();

  /// Get current volume settings from Firestore
  Future<Map<String, int>> getVolumeSettings() async {
    final settings = await _databaseService.getSettings();
    if (settings != null) {
      return {
        'tts_volume': settings.audioVolume, // 0-100
        'beep_volume': settings.beepVolume, // 0-100
      };
    }
    // Default values if settings not found
    return {
      'tts_volume': 50,
      'beep_volume': 50,
    };
  }

  /// Speak text with current volume settings
  Future<void> speak(String text) async {
    // Get volume settings
    final volumes = await getVolumeSettings();
    final ttsVolume = volumes['tts_volume'] ?? 50;
    
    // Set TTS volume (0.0 to 1.0)
    await _tts.setVolume(ttsVolume / 100.0);
    await _tts.setLanguage("en-US");
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.9);
    await _tts.speak(text);
  }

  /// Get volume settings formatted for ESP32
  /// Returns a map with volume values ready to send via BLE
  Future<Map<String, dynamic>> getVolumeSettingsForESP32() async {
    final volumes = await getVolumeSettings();
    return {
      'tts_volume': volumes['tts_volume'], // 0-100
      'beep_volume': volumes['beep_volume'], // 0-100
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Format volume settings as JSON string for ESP32
  /// Your classmate can use this to send volume settings via BLE
  Future<String> getVolumeSettingsJSON() async {
    final volumes = await getVolumeSettingsForESP32();
    return '''
{
  "tts_volume": ${volumes['tts_volume']},
  "beep_volume": ${volumes['beep_volume']},
  "timestamp": ${volumes['timestamp']}
}
''';
  }
}
