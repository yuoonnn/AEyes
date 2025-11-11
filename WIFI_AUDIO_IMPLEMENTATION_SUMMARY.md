# Wi-Fi Audio Streaming Implementation Summary

## What Was Implemented

### Flutter App Side

1. **WiFiAudioService** (`lib/services/wifi_audio_service.dart`)
   - Manages Wi-Fi connection to ESP32-S3
   - Streams PCM audio data via HTTP POST requests
   - Supports chunked audio streaming for large audio files
   - Handles connection testing and status checking

2. **TTSAudioGenerator** (`lib/services/tts_audio_generator.dart`)
   - Generates audio bytes from text using Google Cloud TTS API
   - Supports multiple languages and voice configurations
   - Returns PCM audio data (16-bit, mono, 16kHz)

3. **Updated TTSService** (`lib/services/tts_service.dart`)
   - Integrated Wi-Fi audio streaming
   - Automatic fallback: Wi-Fi → BLE → Phone Speaker
   - Supports both Wi-Fi and BLE audio output

4. **Updated Settings Model** (`lib/models/settings.dart`)
   - Added `esp32WifiIp` field for ESP32 IP address
   - Added `esp32WifiPort` field for ESP32 port (default: 8080)

5. **Updated Database Service** (`lib/services/database_service.dart`)
   - Saves/loads ESP32 Wi-Fi configuration from Firestore

6. **Updated Main App** (`lib/main.dart`)
   - Initializes Wi-Fi audio service
   - Configures TTS service with Wi-Fi audio
   - Loads ESP32 Wi-Fi settings from database

### ESP32-S3 Side

1. **Wi-Fi Server** (`ESP32_WiFi_Audio_Receiver.ino`)
   - HTTP server on port 8080
   - Supports AP mode (Access Point) and STA mode (Station)
   - Receives audio streams via HTTP POST
   - Buffers and plays audio through I2S

2. **Audio Playback System**
   - FreeRTOS task for audio playback
   - Queue-based audio buffering
   - I2S output to MAX98357A amplifier
   - Supports 16kHz, 16-bit, mono PCM audio

3. **HTTP Endpoints**
   - `/ping` - Connection test
   - `/audio_start` - Start audio stream with metadata
   - `/audio_chunked` - Receive audio chunks
   - `/audio_end` - End audio stream
   - `/audio_stop` - Stop and clear audio queue
   - `/status` - Get server status

## How It Works

### Audio Streaming Flow

1. **Text Input**: User triggers TTS (e.g., from image analysis)
2. **Audio Generation**: Flutter app uses Google Cloud TTS to generate PCM audio bytes
3. **Wi-Fi Streaming**: 
   - App sends `/audio_start` with metadata (sample rate, etc.)
   - App sends multiple `/audio_chunked` requests with audio data (4KB chunks)
   - App sends `/audio_end` when complete
4. **ESP32 Processing**:
   - ESP32 receives chunks and adds to audio queue
   - Audio playback task reads from queue and outputs to I2S
   - MAX98357A amplifies and sends to bone conduction speaker

### Fallback Mechanism

The TTS service automatically falls back if Wi-Fi audio is unavailable:
1. **Wi-Fi Audio** (primary) - High quality, low latency
2. **BLE Audio** (fallback) - Lower quality, but works if Wi-Fi unavailable
3. **Phone Speaker** (final fallback) - Always available

## Configuration

### ESP32-S3 Configuration

**AP Mode (Default)**:
- SSID: `ESP32S3-AEyes`
- Password: `aeyes1234`
- IP: `192.168.4.1`

**STA Mode** (Optional):
- Edit sketch to set `STA_SSID` and `STA_PASSWORD`
- ESP32 connects to existing Wi-Fi network
- Check Serial Monitor for assigned IP address

### Flutter App Configuration

1. **Google Cloud TTS API Key** (Optional but recommended):
   ```bash
   flutter run --dart-define=GOOGLE_CLOUD_TTS_API_KEY=your_key_here
   ```

2. **ESP32 Wi-Fi IP Address**:
   - Set in app settings (Settings screen)
   - Or programmatically:
     ```dart
     wifiAudioService.setIpAddress('192.168.4.1', port: 8080);
     ```

## Dependencies

### Flutter App
- `http: ^1.2.1` - HTTP client for Wi-Fi streaming
- `flutter_tts: ^3.8.3` - TTS engine (for fallback)
- Google Cloud TTS API - For audio generation (optional)

### ESP32-S3
- `WebServer` - HTTP server (included in ESP32 Arduino core)
- `ArduinoJson` - JSON parsing (for `/audio_start` endpoint)
- `WiFi` - Wi-Fi connectivity (included in ESP32 Arduino core)
- `driver/i2s.h` - I2S audio output (included in ESP32 Arduino core)

## Testing

### Test Wi-Fi Connection
```dart
final wifiAudioService = WiFiAudioService();
await wifiAudioService.setIpAddress('192.168.4.1', port: 8080);
final connected = await wifiAudioService.testConnection();
print('Connected: $connected');
```

### Test Audio Streaming
```dart
final ttsService = TTSService();
ttsService.setWiFiAudioService(wifiAudioService);
await ttsService.speak("Hello, this is a test message");
```

### Test ESP32 Endpoints
```bash
# Test connection
curl http://192.168.4.1:8080/ping

# Check status
curl http://192.168.4.1:8080/status
```

## Known Issues & Limitations

1. **Binary Data Reading**: The ESP32 WebServer library might have issues reading binary data from request body. The current implementation reads from `server.client()` directly, which should work but may need testing.

2. **Memory Limitations**: ESP32 has limited RAM. Large audio files might cause memory issues. Chunked streaming helps, but very long audio clips might still cause problems.

3. **Network Latency**: Wi-Fi latency depends on network conditions. AP mode (direct connection) provides lower latency than STA mode (through router).

4. **Audio Quality**: 16kHz mono is sufficient for speech but may not be ideal for music or high-quality audio.

5. **No Encryption**: Audio stream is not encrypted. Consider adding HTTPS/TLS for production.

## Future Improvements

1. **Audio Compression**: Add Opus or ADPCM compression to reduce bandwidth
2. **WebSocket Support**: Lower latency than HTTP POST
3. **Audio Format Negotiation**: Support multiple sample rates and formats
4. **Automatic Wi-Fi Configuration**: WiFiManager-style configuration
5. **Audio Encryption**: Encrypt audio stream for security
6. **Streaming Status**: Real-time feedback on streaming status
7. **Error Recovery**: Automatic retry and error recovery
8. **Audio Buffering**: Better buffering strategy for smooth playback

## File Structure

```
aeyes_user_app/
├── lib/
│   ├── services/
│   │   ├── wifi_audio_service.dart      # Wi-Fi audio streaming service
│   │   ├── tts_audio_generator.dart     # TTS audio generation
│   │   └── tts_service.dart             # Updated TTS service with Wi-Fi support
│   ├── models/
│   │   └── settings.dart                # Updated with Wi-Fi settings
│   └── main.dart                        # Updated with Wi-Fi initialization
│
ESP32_WiFi_Audio_Receiver.ino            # ESP32-S3 Wi-Fi audio receiver sketch
WIFI_AUDIO_SETUP_GUIDE.md                # Setup instructions
WIFI_AUDIO_IMPLEMENTATION_SUMMARY.md     # This file
```

## Usage Example

```dart
// Initialize services
final wifiAudioService = WiFiAudioService();
final ttsService = TTSService();

// Configure Wi-Fi
await wifiAudioService.setIpAddress('192.168.4.1', port: 8080);

// Configure TTS
ttsService.setWiFiAudioService(wifiAudioService);
ttsService.setGoogleCloudApiKey('your_api_key');

// Speak text (automatically uses Wi-Fi if available)
await ttsService.speak("Hello, this text will be spoken through the bone conduction speaker");
```

## Notes

- The implementation prioritizes Wi-Fi audio over BLE and phone speaker
- If Wi-Fi is not configured or unavailable, the system automatically falls back to BLE or phone speaker
- Google Cloud TTS API key is optional - if not provided, the system will use fallback methods
- ESP32-S3 must be on the same Wi-Fi network as the phone (or phone connected to ESP32's AP)
- Audio is streamed in 4KB chunks to prevent overwhelming the ESP32's limited buffer

