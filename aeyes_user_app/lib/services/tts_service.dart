import 'package:flutter_tts/flutter_tts.dart';
import '../services/database_service.dart';
import '../models/settings.dart';

class TTSService {
  final FlutterTts _tts = FlutterTts();
  final DatabaseService _databaseService = DatabaseService();

  /// Map app language codes to TTS-supported language codes
  /// Flutter TTS may not support all language codes directly
  static String _mapLanguageCode(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'en-US';
      case 'tl':
        return 'tl-PH'; // Tagalog (Philippines)
      default:
        return 'en-US'; // Fallback to English
    }
  }

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

  /// Get current language from settings
  Future<String> getCurrentLanguage() async {
    final settings = await _databaseService.getSettings();
    return settings?.ttsLanguage ?? 'en';
  }

  /// Speak text with current volume settings and language
  Future<void> speak(String text, {String? languageCode}) async {
    // Get volume settings
    final volumes = await getVolumeSettings();
    final ttsVolume = volumes['tts_volume'] ?? 50;
    
    // Get language code from parameter or settings
    final langCode = languageCode ?? await getCurrentLanguage();
    final ttsLanguage = _mapLanguageCode(langCode);
    
    try {
      // Set TTS volume (0.0 to 1.0)
      await _tts.setVolume(ttsVolume / 100.0);
      
      // Try to set the language, fallback to en-US if it fails
      // setLanguage returns a Future<bool> indicating success
      final languageSet = await _tts.setLanguage(ttsLanguage);
      if (!languageSet) {
        // If language setting fails, fallback to English
        print('Warning: Failed to set TTS language to $ttsLanguage, using en-US');
        await _tts.setLanguage('en-US');
      }
      
      await _tts.setPitch(1.0);
      await _tts.setSpeechRate(0.9);
      await _tts.speak(text);
    } catch (e) {
      print('Error in TTS speak: $e');
      // Re-throw to let caller handle the error
      rethrow;
    }
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
