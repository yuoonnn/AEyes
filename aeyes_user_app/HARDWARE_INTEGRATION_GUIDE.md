# Hardware Integration Guide

This guide explains how the app is now ready for integration with ESP32 hardware supporting:
- ✅ **Voice Control**
- ✅ **Button Control**  
- ✅ **Bone Conduction Audio**

## 🎉 What's Ready

### 1. **Button Control** ✅
The app can now receive and handle button press events from the ESP32.

**How it works:**
- ESP32 sends button press data via BLE characteristic (notify)
- App automatically subscribes to button characteristic on connection
- Button events trigger callbacks that can be handled in your screens

**Example Usage:**
```dart
// In your screen (e.g., HomeScreen)
bluetoothService.onButtonPressed = (String buttonData) {
  // buttonData could be "0", "1", "2" or action strings like "capture", "help"
  switch (buttonData.trim()) {
    case '0':
    case 'capture':
      // Trigger image capture
      break;
    case '1':
    case 'help':
      // Trigger emergency/help
      break;
    default:
      // Handle other buttons
  }
};
```

**ESP32 Side Requirements:**
- Create a BLE characteristic with **notify** property (no read/write)
- Send button ID or action string when button is pressed
- Format: Send as string bytes (e.g., "0", "1", "capture", "help")

---

### 2. **Voice Control** ✅
The app can now receive voice commands from the ESP32 in two ways:

#### Option A: Processed Text (Recommended)
ESP32 processes voice → sends text command → app receives text

```dart
// In your screen
bluetoothService.onVoiceCommandText = (String command) {
  final lowerCommand = command.toLowerCase().trim();
  
  if (lowerCommand.contains('help')) {
    // Handle help command
  } else if (lowerCommand.contains('capture')) {
    // Handle capture command
  }
};
```

#### Option B: Raw Audio Data
ESP32 sends raw audio → app can process with speech-to-text

```dart
// In your screen
bluetoothService.onVoiceCommandReceived = (Uint8List audioData) {
  // Process audio data with speech-to-text service
  // For example, use Google Speech-to-Text API
};
```

**ESP32 Side Requirements:**
- Create a BLE characteristic with **notify + read** properties
- Send either:
  - **Text format**: Processed voice command as string (e.g., "capture image", "help")
  - **Audio format**: Raw audio bytes (PCM, WAV, etc.)

---

### 3. **Bone Conduction Audio** ✅
The app can now send TTS/audio to the ESP32's bone conduction speaker.

**How it works:**
- App generates TTS or has audio data
- Sends audio data to ESP32 via BLE write characteristic
- ESP32 plays audio through bone conduction speaker

**Example Usage:**
```dart
// Method 1: Send text for TTS (if ESP32 has TTS capability)
await bluetoothService.sendTextForTTS("Hello, this is a test message");

// Method 2: Send raw audio data
final audioBytes = Uint8List.fromList([...]); // Your audio data
await bluetoothService.sendAudioToBoneConduction(audioBytes);

// Method 3: Use TTS Service with bone conduction
final ttsService = TTSService();
ttsService.setBluetoothService(bluetoothService);
await ttsService.speak("Hello world", useBoneConduction: true);
```

**ESP32 Side Requirements:**
- Create a BLE characteristic with **write** property (no notify)
- Receive audio data chunks (BLE MTU is ~20 bytes, so data is chunked)
- Play received audio through bone conduction speaker
- If receiving text: Use ESP32's TTS engine to convert text to speech

---

## 📡 BLE Characteristic Requirements

Your ESP32 needs to expose these BLE characteristics:

### 1. **Image Characteristic** (Already Working)
- **Properties**: Read + Notify
- **Purpose**: Send image data from ESP32 camera to app
- **Status**: ✅ Already implemented

### 2. **Button Characteristic** (NEW)
- **Properties**: Notify only (no read, no write)
- **Purpose**: Send button press events
- **Data Format**: String bytes (e.g., "0", "1", "capture", "help")
- **UUID**: Your custom UUID

### 3. **Voice Command Characteristic** (NEW)
- **Properties**: Notify + Read
- **Purpose**: Send voice command data (text or audio)
- **Data Format**: 
  - Text: UTF-8 string bytes
  - Audio: Raw audio bytes
- **UUID**: Your custom UUID

### 4. **Audio Output Characteristic** (NEW)
- **Properties**: Write only (no notify, no read)
- **Purpose**: Receive audio/TTS data from app
- **Data Format**: 
  - Text: UTF-8 string bytes (if ESP32 has TTS)
  - Audio: Raw audio bytes (PCM, WAV, etc.)
- **UUID**: Your custom UUID

---

## 🔧 Connection Flow

When the app connects to ESP32:

1. **Discovers all BLE services and characteristics**
2. **Automatically identifies characteristics by their properties:**
   - Image: Read + Notify
   - Button: Notify only
   - Voice: Notify + Read
   - Audio: Write only
3. **Subscribes to notification characteristics** (Image, Button, Voice)
4. **Stores write characteristic** (Audio Output)
5. **Logs which characteristics were found**

**Connection Log Example:**
```
Connecting to ESP32: AEyes_Device
Service UUID: 12345678-1234-1234-1234-123456789abc
  Characteristic UUID: abc123..., Properties: {read, notify}
Subscribed to image characteristic
Subscribed to button characteristic
Subscribed to voice command characteristic
Found audio output characteristic
Successfully connected to AEyes_Device
Characteristics found: Image=true, Button=true, Voice=true, Audio=true
```

---

## 📝 Implementation Checklist for Your Groupmate

### ESP32 Side:
- [ ] Create BLE service with custom UUID
- [ ] Add Button characteristic (notify only)
  - [ ] Send button ID/action when button pressed
- [ ] Add Voice Command characteristic (notify + read)
  - [ ] Send processed text OR raw audio when voice detected
- [ ] Add Audio Output characteristic (write only)
  - [ ] Receive audio/text chunks
  - [ ] Play through bone conduction speaker
- [ ] Test button press → app receives event
- [ ] Test voice command → app receives text/audio
- [ ] Test app sends audio → ESP32 plays on bone conduction

### App Side (Already Done):
- [x] Button event handlers
- [x] Voice command handlers
- [x] Audio output methods
- [x] Automatic characteristic discovery
- [x] TTS service integration

---

## 🎯 Example Integration Scenarios

### Scenario 1: User presses button on glasses
```
ESP32 → Button pressed → Send "capture" via Button characteristic
App → Receives "capture" → Triggers image analysis
App → Sends result via TTS → ESP32 → Plays on bone conduction
```

### Scenario 2: User speaks voice command
```
ESP32 → Voice detected → Process with ESP32 STT → Send "help" via Voice characteristic
App → Receives "help" → Triggers emergency/help flow
App → Sends "Calling for help..." via Audio Output → ESP32 → Plays on bone conduction
```

### Scenario 3: App wants to notify user
```
App → Generates TTS: "Obstacle detected ahead"
App → Sends text via Audio Output characteristic
ESP32 → Receives text → Converts to speech → Plays on bone conduction
```

---

## 🚀 Quick Start

1. **Connect to ESP32** (already working)
   ```dart
   await bluetoothService.connect(device);
   ```

2. **Set up button handler** (in HomeScreen or wherever needed)
   ```dart
   bluetoothService.onButtonPressed = (String button) {
     // Handle button press
   };
   ```

3. **Set up voice handler** (in HomeScreen or wherever needed)
   ```dart
   bluetoothService.onVoiceCommandText = (String command) {
     // Handle voice command
   };
   ```

4. **Send audio to bone conduction**
   ```dart
   await bluetoothService.sendTextForTTS("Hello from app");
   ```

---

## 📊 Data Flow Diagrams

### Button Control Flow:
```
[ESP32 Button] → [BLE Button Characteristic] → [App onButtonPressed] → [Action Handler]
```

### Voice Control Flow:
```
[ESP32 Mic] → [ESP32 STT] → [BLE Voice Characteristic] → [App onVoiceCommandText] → [Command Handler]
```

### Bone Conduction Flow:
```
[App TTS/Text] → [BLE Audio Output Characteristic] → [ESP32] → [Bone Conduction Speaker]
```

---

## ✅ Integration Status

| Feature | App Ready | ESP32 Needed | Status |
|---------|----------|--------------|--------|
| Image Receiving | ✅ | ✅ | **Working** |
| Button Control | ✅ | ⏳ | **Ready for ESP32** |
| Voice Control | ✅ | ⏳ | **Ready for ESP32** |
| Bone Conduction | ✅ | ⏳ | **Ready for ESP32** |
| Volume Settings | ✅ | ✅ | **Working** |

---

## 🎉 Summary

**Your app is NOW READY for full hardware integration!**

All three features (voice control, button control, bone conduction) are implemented on the app side. Your groupmate just needs to:

1. **Implement the BLE characteristics** on ESP32 (Button, Voice, Audio Output)
2. **Send data in the expected formats** (see requirements above)
3. **Test the integration** with the app

The app will automatically discover and use these characteristics when connected to the ESP32.

---

## 📞 Need Help?

If your groupmate needs help with:
- **BLE characteristic setup**: See ESP32 BLE documentation
- **Data format**: See "BLE Characteristic Requirements" section above
- **Testing**: Use the connection logs to verify characteristics are found

The app logs all discovered characteristics, so debugging should be straightforward!

