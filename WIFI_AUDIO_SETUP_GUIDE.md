# Wi-Fi Audio Streaming Setup Guide

This guide explains how to set up Wi-Fi audio streaming from the Flutter app to the ESP32-S3 bone conduction speaker.

## Overview

The system streams TTS (Text-to-Speech) audio from your phone to the ESP32-S3 via Wi-Fi, which then plays the audio through the bone conduction speaker. This provides higher quality audio than BLE and supports longer audio clips.

## Architecture

1. **Flutter App**: Generates TTS audio using Google Cloud TTS API, streams audio bytes via HTTP POST to ESP32-S3
2. **ESP32-S3**: Receives audio stream via Wi-Fi HTTP server, buffers and plays through I2S to MAX98357A amplifier
3. **Bone Conduction Speaker**: Outputs audio to the user

## Prerequisites

### Flutter App
- Google Cloud TTS API key (optional but recommended for high-quality audio)
- ESP32-S3 Wi-Fi IP address configured in settings

### ESP32-S3
- ESP32-S3 WROOM development board
- MAX98357A I2S amplifier
- Bone conduction speaker
- Wi-Fi connectivity (AP mode or STA mode)

## Setup Steps

### 1. ESP32-S3 Setup

#### Option A: Access Point (AP) Mode (Recommended for Initial Setup)
The ESP32-S3 creates its own Wi-Fi network that your phone connects to.

1. Upload the `ESP32_WiFi_Audio_Receiver.ino` sketch to your ESP32-S3
2. The ESP32 will create a Wi-Fi network named `ESP32S3-AEyes` with password `aeyes1234`
3. Connect your phone to this Wi-Fi network
4. The ESP32 will have IP address `192.168.4.1` (default AP IP)

#### Option B: Station (STA) Mode
The ESP32-S3 connects to your existing Wi-Fi network.

1. Edit `ESP32_WiFi_Audio_Receiver.ino` and uncomment/configure:
   ```cpp
   const char* STA_SSID = "YourWiFiSSID";
   const char* STA_PASSWORD = "YourWiFiPassword";
   ```
2. Upload the sketch
3. Check Serial Monitor for the ESP32's IP address on your network
4. Make sure your phone is on the same Wi-Fi network

### 2. Flutter App Setup

#### Step 1: Configure Google Cloud TTS API Key (Optional but Recommended)

1. Get a Google Cloud TTS API key from Google Cloud Console
2. Set it as an environment variable when running the app:
   ```bash
   flutter run --dart-define=GOOGLE_CLOUD_TTS_API_KEY=your_api_key_here
   ```
   
   Or add it to your build configuration in Android Studio/Xcode.

#### Step 2: Configure ESP32 Wi-Fi IP Address

1. Open the app and go to Settings
2. Enter the ESP32-S3 IP address:
   - AP mode: `192.168.4.1`
   - STA mode: Check Serial Monitor for the IP address
3. Port: `8080` (default)
4. Save settings

Alternatively, you can configure it programmatically:
```dart
final wifiAudioService = WiFiAudioService();
await wifiAudioService.setIpAddress('192.168.4.1', port: 8080);
```

### 3. Usage

The TTS service automatically uses Wi-Fi audio streaming when:
- Wi-Fi audio service is configured with an IP address
- Google Cloud TTS API key is set (for audio generation)
- Bone conduction is enabled

The system falls back to:
1. BLE audio (if BLE is connected)
2. Phone speaker (if neither Wi-Fi nor BLE is available)

## Testing

### Test Connection
```dart
final wifiAudioService = WiFiAudioService();
await wifiAudioService.setIpAddress('192.168.4.1', port: 8080);
final isConnected = await wifiAudioService.testConnection();
print('Wi-Fi connection: $isConnected');
```

### Test Audio Streaming
```dart
final ttsService = TTSService();
ttsService.setWiFiAudioService(wifiAudioService);
await ttsService.speak("Hello, this is a test");
```

## Troubleshooting

### ESP32 Not Receiving Audio

1. **Check Wi-Fi Connection**
   - Verify ESP32 is in AP mode and phone is connected to `ESP32S3-AEyes` network
   - Or verify both devices are on the same Wi-Fi network (STA mode)
   - Check Serial Monitor for ESP32 IP address

2. **Check IP Address Configuration**
   - Verify IP address in app settings matches ESP32 IP
   - AP mode: Usually `192.168.4.1`
   - STA mode: Check Serial Monitor

3. **Check HTTP Server**
   - Test with: `curl http://192.168.4.1:8080/ping`
   - Should return "OK"

4. **Check Audio Queue**
   - Monitor Serial Monitor for audio reception messages
   - Check if audio buffer queue is filling up

### Audio Quality Issues

1. **Sample Rate Mismatch**
   - Ensure ESP32 and app use same sample rate (default: 16000 Hz)
   - Check I2S configuration matches audio format

2. **Buffer Underruns**
   - Increase chunk size in Flutter app
   - Increase DMA buffer size in ESP32 I2S config
   - Reduce audio playback task priority

3. **Network Latency**
   - Use AP mode for lower latency (direct connection)
   - Reduce chunk size for faster transmission
   - Check Wi-Fi signal strength

### Google Cloud TTS Not Working

1. **API Key Not Set**
   - Verify API key is set via environment variable
   - Check app logs for API key configuration messages

2. **API Quota Exceeded**
   - Check Google Cloud Console for quota limits
   - Consider using fallback TTS methods

3. **Network Issues**
   - Verify phone has internet connectivity
   - Check firewall/proxy settings

## API Endpoints

The ESP32-S3 HTTP server provides these endpoints:

- `GET /ping` - Test connection
- `POST /audio_start` - Start audio stream (JSON with metadata)
- `POST /audio_chunked` - Send audio chunk (binary data)
- `POST /audio_end` - End audio stream
- `POST /audio_stop` - Stop audio and clear queue
- `GET /status` - Get server status (JSON)

## Audio Format

- **Sample Rate**: 16000 Hz (configurable)
- **Bits Per Sample**: 16
- **Channels**: 1 (mono)
- **Encoding**: Linear PCM (16-bit signed integers, little-endian)
- **Format**: Raw PCM data (no WAV header)

## Performance Considerations

- **Chunk Size**: 4KB chunks provide good balance between latency and reliability
- **Buffer Size**: ESP32 has limited RAM - keep audio queue reasonable
- **Network**: AP mode provides lower latency than STA mode
- **Audio Quality**: 16kHz mono is sufficient for speech

## Security Notes

- AP mode password is hardcoded in ESP32 sketch - change it for production
- No encryption on Wi-Fi audio stream - consider HTTPS for production
- API keys should be stored securely, not hardcoded

## Future Improvements

- [ ] Add audio compression (Opus, ADPCM) to reduce bandwidth
- [ ] Add WebSocket support for lower latency
- [ ] Add audio encryption
- [ ] Add automatic Wi-Fi configuration
- [ ] Add audio format negotiation
- [ ] Add streaming status feedback

