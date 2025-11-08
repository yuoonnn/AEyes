# ESP32 Integration Guide for Volume Settings

This guide explains how the volume settings are set up and ready for ESP32 integration.

## ✅ What's Ready

### 1. Volume Settings Storage
- **TTS Volume**: 0-100 (stored in Firestore)
- **Beep Volume**: 0-100 (stored in Firestore)
- Both volumes are saved when user changes them in Settings screen
- Settings persist in Firestore and load automatically

### 2. Methods Available for ESP32 Integration

#### Option 1: Send Volume Settings as JSON (Recommended)
```dart
// In your BluetoothService or wherever you handle ESP32 communication
final bluetoothService = BluetoothService();

// After connecting to ESP32, send volume settings
await bluetoothService.sendVolumeSettings();
```

**JSON Format Sent:**
```json
{
  "tts_volume": 75,
  "beep_volume": 50,
  "timestamp": 1234567890
}
```

#### Option 2: Get Volume Settings as Bytes
```dart
// Get as simple byte array: [tts_volume, beep_volume]
final volumeBytes = await bluetoothService.getVolumeSettingsAsBytes();
// volumeBytes = [75, 50] (example: TTS=75%, Beep=50%)

// Send to ESP32
await bluetoothService.sendDataToESP32(volumeBytes);
```

#### Option 3: Get Volume Settings Map
```dart
final ttsService = TTSService();
final volumes = await ttsService.getVolumeSettings();
// Returns: {'tts_volume': 75, 'beep_volume': 50}

// Your classmate can format this however ESP32 needs it
```

## 📡 When to Send Volume Settings

### Recommended Times:
1. **After connecting to ESP32**: Send current volume settings immediately
2. **When user changes volume in Settings**: Send updated settings
3. **Periodically**: Send every few minutes to keep ESP32 in sync

### Example Implementation:

```dart
// In your Bluetooth screen or connection handler
void _onDeviceConnected() async {
  // After successful connection
  await bluetoothService.sendVolumeSettings();
}

// In Settings screen, after saving
void _saveSettings() async {
  // ... save to Firestore ...
  
  // Send to ESP32 if connected
  if (bluetoothService.isConnected) {
    await bluetoothService.sendVolumeSettings();
  }
}
```

## 🔧 ESP32 Side (For Your Classmate)

### Expected Data Format:

**JSON Format:**
```json
{
  "tts_volume": 75,      // 0-100
  "beep_volume": 50,     // 0-100
  "timestamp": 1234567890
}
```

**Byte Format (Alternative):**
```
[tts_volume, beep_volume]
Example: [75, 50]
```

### ESP32 Implementation Notes:

1. **Parse JSON** (if using JSON format):
   ```cpp
   // ESP32 Arduino example
   DynamicJsonDocument doc(1024);
   deserializeJson(doc, receivedData);
   int ttsVolume = doc["tts_volume"];      // 0-100
   int beepVolume = doc["beep_volume"];   // 0-100
   ```

2. **Parse Bytes** (if using byte format):
   ```cpp
   // ESP32 Arduino example
   uint8_t ttsVolume = receivedData[0];  // 0-100
   uint8_t beepVolume = receivedData[1]; // 0-100
   ```

3. **Apply to Hardware**:
   - TTS Volume: Control speaker/audio output volume
   - Beep Volume: Control bone conduction speaker volume

## 📝 Current Implementation

### Settings Screen
- User can adjust TTS Volume (0-100%)
- User can adjust Beep Volume (0-100%)
- Settings are saved to Firestore immediately
- Settings persist across app restarts

### Bluetooth Service
- `sendVolumeSettings()`: Sends JSON format to ESP32
- `getVolumeSettingsAsBytes()`: Returns byte array format
- `sendDataToESP32()`: Generic method to send any data

### TTS Service
- `getVolumeSettings()`: Returns volume map
- `getVolumeSettingsForESP32()`: Returns formatted map with timestamp
- `getVolumeSettingsJSON()`: Returns JSON string

## 🚀 Integration Steps for Your Classmate

1. **ESP32 should listen for BLE write characteristic**
2. **Parse the received data** (JSON or bytes)
3. **Extract `tts_volume` and `beep_volume`** (0-100)
4. **Apply to hardware**:
   - Map TTS volume to audio output
   - Map Beep volume to bone conduction speaker

## 📊 Data Flow

```
User changes volume in Settings
    ↓
Save to Firestore
    ↓
If ESP32 connected:
    ↓
Send via BLE (JSON or bytes)
    ↓
ESP32 receives and applies to hardware
```

## 🔄 Auto-Sync (Optional)

You can set up automatic syncing:

```dart
// In your app initialization or connection handler
Timer.periodic(Duration(minutes: 5), (timer) async {
  if (bluetoothService.isConnected) {
    await bluetoothService.sendVolumeSettings();
  }
});
```

## 📌 Notes

- **Volume Range**: Both volumes are 0-100 (0% to 100%)
- **Default Values**: 50 (50%) if not set
- **Storage**: Saved in Firestore `settings` collection
- **Format**: Can send as JSON or raw bytes (your classmate's choice)

## ✅ Ready to Use!

The volume settings module is **fully ready** for ESP32 integration. Your classmate just needs to:
1. Receive the data via BLE
2. Parse it (JSON or bytes)
3. Apply to hardware

All the app-side code is ready and waiting! 🎉

