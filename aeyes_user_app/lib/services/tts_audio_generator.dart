import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Service for generating TTS audio bytes
/// Supports multiple TTS engines (Google Cloud TTS, etc.)
class TTSAudioGenerator {
  static const String _googleCloudTtsUrl = 
      'https://texttospeech.googleapis.com/v1/text:synthesize';
  
  String? _googleCloudApiKey;
  bool _useGoogleCloudTts = false;

  /// Set Google Cloud TTS API key
  void setGoogleCloudApiKey(String? apiKey) {
    _googleCloudApiKey = apiKey;
    _useGoogleCloudTts = apiKey != null && apiKey.isNotEmpty;
  }

  /// Generate audio bytes from text using Google Cloud TTS
  /// 
  /// Returns PCM audio bytes (16-bit, mono, 16kHz)
  /// Returns null if generation fails
  Future<Uint8List?> generateAudioFromText(
    String text, {
    String languageCode = 'en-US',
    String voiceName = 'en-US-Standard-B', // Neutral voice
    double speakingRate = 1.0, // 0.25 to 4.0
    double pitch = 0.0, // -20.0 to 20.0 semitones
    double volumeGainDb = 0.0, // -96.0 to 16.0 dB
  }) async {
    if (!_useGoogleCloudTts || _googleCloudApiKey == null) {
      print('Google Cloud TTS not configured');
      return null;
    }

    if (text.isEmpty) {
      return null;
    }

    try {
      final url = Uri.parse('$_googleCloudTtsUrl?key=$_googleCloudApiKey');
      
      final requestBody = {
        'input': {'text': text},
        'voice': {
          'languageCode': languageCode,
          'name': voiceName,
        },
        'audioConfig': {
          'audioEncoding': 'LINEAR16', // 16-bit PCM
          'sampleRateHertz': 16000,
          'speakingRate': speakingRate,
          'pitch': pitch,
          'volumeGainDb': volumeGainDb,
        },
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final audioContent = jsonResponse['audioContent'] as String?;
        
        if (audioContent != null) {
          // Decode base64 audio content
          final audioBytes = base64Decode(audioContent);
          print('Generated audio: ${audioBytes.length} bytes');
          return Uint8List.fromList(audioBytes);
        }
      } else {
        print('Google Cloud TTS error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error generating TTS audio: $e');
    }

    return null;
  }

  /// Generate audio with custom parameters
  Future<Uint8List?> generateAudio(
    String text, {
    String? languageCode,
    String? voiceName,
    double? speakingRate,
    double? pitch,
    double? volumeGainDb,
  }) async {
    // Map language codes
    final lang = languageCode ?? 'en-US';
    final voice = voiceName ?? _getDefaultVoice(lang);
    final rate = speakingRate ?? 1.0;
    final pitchValue = pitch ?? 0.0;
    final volume = volumeGainDb ?? 0.0;

    return generateAudioFromText(
      text,
      languageCode: lang,
      voiceName: voice,
      speakingRate: rate,
      pitch: pitchValue,
      volumeGainDb: volume,
    );
  }

  /// Get default voice for language code
  String _getDefaultVoice(String languageCode) {
    switch (languageCode) {
      case 'en-US':
        return 'en-US-Standard-B';
      case 'en-GB':
        return 'en-GB-Standard-B';
      case 'tl-PH': // Tagalog
        return 'fil-PH-Standard-A'; // Filipino/Tagalog
      case 'es-ES':
        return 'es-ES-Standard-A';
      case 'fr-FR':
        return 'fr-FR-Standard-A';
      default:
        return 'en-US-Standard-B';
    }
  }

  /// Check if TTS audio generation is available
  bool get isAvailable => _useGoogleCloudTts;
}

