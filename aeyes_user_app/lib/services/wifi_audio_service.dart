import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Service for streaming audio to ESP32-S3 via Wi-Fi
class WiFiAudioService {
  static const String _prefKeyIpAddress = 'esp32_wifi_ip';
  static const String _defaultIpAddress = '192.168.4.1'; // ESP32-S3 default AP IP
  static const int _defaultPort = 8080;
  static const Duration _connectionTimeout = Duration(seconds: 5);
  static const Duration _sendTimeout = Duration(seconds: 30);

  String? _ipAddress;
  int _port = _defaultPort;
  bool _isConnected = false;

  /// Get current IP address
  String? get ipAddress => _ipAddress;
  
  /// Get current port
  int get port => _port;
  
  /// Check if service is configured with an IP address
  bool get isConfigured => _ipAddress != null && _ipAddress!.isNotEmpty;
  
  /// Get connection status
  bool get isConnected => _isConnected;

  WiFiAudioService() {
    _loadSettings();
  }

  /// Load IP address from preferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _ipAddress = prefs.getString(_prefKeyIpAddress) ?? _defaultIpAddress;
      _port = prefs.getInt('esp32_wifi_port') ?? _defaultPort;
    } catch (e) {
      print('Error loading Wi-Fi settings: $e');
      _ipAddress = _defaultIpAddress;
    }
  }

  /// Set ESP32-S3 IP address and port
  Future<void> setIpAddress(String ipAddress, {int? port}) async {
    _ipAddress = ipAddress;
    if (port != null) {
      _port = port;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyIpAddress, ipAddress);
      if (port != null) {
        await prefs.setInt('esp32_wifi_port', port);
      }
      print('Wi-Fi audio service configured: $ipAddress:$_port');
    } catch (e) {
      print('Error saving Wi-Fi settings: $e');
    }
  }

  /// Test connection to ESP32-S3
  Future<bool> testConnection() async {
    if (!isConfigured) {
      print('Wi-Fi audio service not configured');
      return false;
    }

    try {
      final url = Uri.parse('http://$_ipAddress:$_port/ping');
      final response = await http
          .get(url)
          .timeout(_connectionTimeout);

      _isConnected = response.statusCode == 200;
      return _isConnected;
    } catch (e) {
      _isConnected = false;
      print('Connection test failed: $e');
      return false;
    }
  }

  /// Stream PCM audio data to ESP32-S3
  /// 
  /// [audioData] - PCM audio bytes (16-bit, mono, 16kHz recommended)
  /// [sampleRate] - Audio sample rate (default: 16000 Hz)
  /// [bitsPerSample] - Bits per sample (default: 16)
  /// [channels] - Number of channels (default: 1 for mono)
  Future<bool> streamAudio(
    Uint8List audioData, {
    int sampleRate = 16000,
    int bitsPerSample = 16,
    int channels = 1,
  }) async {
    if (!isConfigured) {
      print('Wi-Fi audio service not configured');
      return false;
    }

    if (audioData.isEmpty) {
      print('Empty audio data');
      return false;
    }

    try {
      // Send audio start command with metadata
      final startUrl = Uri.parse('http://$_ipAddress:$_port/audio_start');
      final startResponse = await http.post(
        startUrl,
        headers: {'Content-Type': 'application/json'},
        body: '''
        {
          "sample_rate": $sampleRate,
          "bits_per_sample": $bitsPerSample,
          "channels": $channels,
          "total_size": ${audioData.length}
        }
        ''',
      ).timeout(_connectionTimeout);

      if (startResponse.statusCode != 200) {
        print('Failed to start audio stream: ${startResponse.statusCode}');
        return false;
      }

      // Stream audio in chunks (ESP32 has limited buffer)
      const int chunkSize = 4096; // 4KB chunks
      int offset = 0;
      int chunkIndex = 0;

      while (offset < audioData.length) {
        final chunkEnd = (offset + chunkSize < audioData.length)
            ? offset + chunkSize
            : audioData.length;
        final chunk = audioData.sublist(offset, chunkEnd);

        final chunkUrl = Uri.parse('http://$_ipAddress:$_port/audio_chunked');
        final chunkResponse = await http.post(
          chunkUrl,
          headers: {
            'Content-Type': 'application/octet-stream',
            'X-Chunk-Index': chunkIndex.toString(),
            'X-Chunk-Size': chunk.length.toString(),
          },
          body: chunk,
        ).timeout(_sendTimeout);

        if (chunkResponse.statusCode != 200) {
          print('Failed to send chunk $chunkIndex: ${chunkResponse.statusCode}');
          return false;
        }

        offset = chunkEnd;
        chunkIndex++;

        // Small delay to prevent overwhelming ESP32
        if (offset < audioData.length) {
          await Future.delayed(const Duration(milliseconds: 10));
        }
      }

      // Send audio end command
      final endUrl = Uri.parse('http://$_ipAddress:$_port/audio_end');
      await http.post(endUrl).timeout(_connectionTimeout);

      print('Audio streamed successfully: ${audioData.length} bytes in $chunkIndex chunks');
      _isConnected = true;
      return true;
    } catch (e) {
      print('Error streaming audio: $e');
      _isConnected = false;
      return false;
    }
  }

  /// Stream audio in chunks (useful for large audio files)
  /// 
  /// This method splits audio into smaller chunks and streams them sequentially
  Future<bool> streamAudioChunked(
    Uint8List audioData, {
    int sampleRate = 16000,
    int bitsPerSample = 16,
    int channels = 1,
    int chunkSize = 4096, // 4KB chunks
  }) async {
    if (!isConfigured) {
      print('Wi-Fi audio service not configured');
      return false;
    }

    if (audioData.isEmpty) {
      print('Empty audio data');
      return false;
    }

    try {
      final url = Uri.parse('http://$_ipAddress:$_port/audio_chunked');
      
      // Send header with audio metadata
      final headerResponse = await http.post(
        Uri.parse('http://$_ipAddress:$_port/audio_start'),
        headers: {'Content-Type': 'application/json'},
        body: '''
        {
          "sample_rate": $sampleRate,
          "bits_per_sample": $bitsPerSample,
          "channels": $channels,
          "total_size": ${audioData.length},
          "chunk_size": $chunkSize
        }
        ''',
      ).timeout(_connectionTimeout);

      if (headerResponse.statusCode != 200) {
        print('Failed to send audio header: ${headerResponse.statusCode}');
        return false;
      }

      // Stream chunks
      int offset = 0;
      int chunkIndex = 0;
      
      while (offset < audioData.length) {
        final chunkEnd = (offset + chunkSize < audioData.length) 
            ? offset + chunkSize 
            : audioData.length;
        final chunk = audioData.sublist(offset, chunkEnd);
        
        final chunkResponse = await http.post(
          url,
          headers: {
            'Content-Type': 'application/octet-stream',
            'X-Chunk-Index': chunkIndex.toString(),
            'X-Chunk-Size': chunk.length.toString(),
            'X-Total-Size': audioData.length.toString(),
          },
          body: chunk,
        ).timeout(_sendTimeout);

        if (chunkResponse.statusCode != 200) {
          print('Failed to send chunk $chunkIndex: ${chunkResponse.statusCode}');
          return false;
        }

        offset = chunkEnd;
        chunkIndex++;
      }

      // Send end marker
      await http.post(
        Uri.parse('http://$_ipAddress:$_port/audio_end'),
      ).timeout(_connectionTimeout);

      print('Audio streamed in chunks: ${audioData.length} bytes in $chunkIndex chunks');
      _isConnected = true;
      return true;
    } catch (e) {
      print('Error streaming audio chunks: $e');
      _isConnected = false;
      return false;
    }
  }

  /// Send stop command to ESP32-S3
  Future<bool> stopAudio() async {
    if (!isConfigured) return false;

    try {
      final url = Uri.parse('http://$_ipAddress:$_port/audio_stop');
      final response = await http.post(url).timeout(_connectionTimeout);
      return response.statusCode == 200;
    } catch (e) {
      print('Error stopping audio: $e');
      return false;
    }
  }

  /// Get ESP32-S3 status
  Future<Map<String, dynamic>?> getStatus() async {
    if (!isConfigured) return null;

    try {
      final url = Uri.parse('http://$_ipAddress:$_port/status');
      final response = await http.get(url).timeout(_connectionTimeout);
      
      if (response.statusCode == 200) {
        // Parse JSON response if available
        try {
          // For now, return simple status
          return {'status': 'connected', 'ip': _ipAddress, 'port': _port};
        } catch (_) {
          return {'status': 'connected', 'ip': _ipAddress, 'port': _port};
        }
      }
      return null;
    } catch (e) {
      print('Error getting status: $e');
      return null;
    }
  }
}

