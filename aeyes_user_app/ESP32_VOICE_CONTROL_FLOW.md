# ESP32 Voice Control Flow

## ✅ Current Implementation

The app is now set up to receive voice commands from ESP32 and automatically pair them with image captures for OpenAI analysis.

## 🔄 How It Works

### Flow:
```
1. User holds ESP32 Button 3 (push-to-talk)
   ↓
2. ESP32 records voice (while button is held)
   ↓
3. ESP32 processes voice to text (speech-to-text)
   ↓
4. ESP32 sends voice command text via BLE: "VOICE\n<text>\n"
   ↓
5. ESP32 captures image
   ↓
6. ESP32 sends image via BLE (existing image protocol)
   ↓
7. Phone receives voice command text → stores it
   ↓
8. Phone receives image → checks for recent voice command (within 5 seconds)
   ↓
9. Phone sends BOTH voice command + image to OpenAI
   ↓
10. OpenAI analyzes image with voice command as the prompt
   ↓
11. Result is displayed and spoken via TTS
```

## 📱 App Side (Already Complete)

✅ **Voice command parsing** - App parses "VOICE\n<text>\n" messages  
✅ **Voice command storage** - Stores voice command for 5 seconds  
✅ **Image + voice pairing** - Automatically pairs voice command with next image  
✅ **OpenAI integration** - Sends voice command as custom prompt to OpenAI  
✅ **TTS output** - Speaks the analysis result  

## 🔧 ESP32 Side (Needs Implementation)

### What's Already Done:
✅ Button 3 detection (long press = 5 seconds)  
✅ `sendVoiceCommand()` function to send voice text  
✅ Image capture and sending  
✅ BLE communication setup  

### What ESP32 Needs to Implement:

1. **Voice Recording** (while button is held)
   - Use ESP32's I2S microphone input
   - Record audio while button is LOW (held down)
   - Stop recording when button is released

2. **Speech-to-Text Processing**
   - Option A: Use ESP32's built-in speech recognition (if available)
   - Option B: Send audio to phone for processing (more complex)
   - Option C: Use cloud service (requires WiFi)

3. **Send Voice Command Text**
   - After processing voice to text, call `sendVoiceCommand(voiceText)`
   - Then call `sendCameraImage()`

### Example ESP32 Code Structure:

```cpp
// In Button 3 long press handler:
else if (i == 2) {  // Button 3
  if (wasLong) {
    // 1. Record voice while button was held
    String voiceText = recordAndProcessVoice(); // TODO: Implement this
    
    // 2. Send voice command text
    if (voiceText.length() > 0) {
      sendVoiceCommand(voiceText.c_str());
      delay(100);
    }
    
    // 3. Capture and send image
    sendCameraImage();
  }
}
```

## 📡 BLE Message Format

### Voice Command Format:
```
"VOICE\n<voice_text>\n"
```

Example:
```
"VOICE\nwhat's in front of me\n"
```

### Button Event Format (existing):
```
"BTN\n<button_id>\n<event>\n"
```

## 🎯 Current Status

- ✅ App can receive and parse voice commands from ESP32
- ✅ App automatically pairs voice commands with images
- ✅ App sends voice command + image to OpenAI
- ⏳ ESP32 needs to implement voice recording + STT
- ✅ ESP32 has placeholder code ready for integration

## 📝 Next Steps for ESP32

1. **Add microphone input** to ESP32 (I2S or analog)
2. **Implement voice recording** while button is held
3. **Add speech-to-text** processing (ESP32 native or cloud)
4. **Replace placeholder** in Button 3 handler with actual voice processing
5. **Test the complete flow**

## 🔍 Testing

Once ESP32 voice processing is implemented:

1. Hold ESP32 Button 3
2. Speak: "What's in front of me?"
3. Release button
4. ESP32 should:
   - Process voice to text
   - Send "VOICE\nwhat's in front of me\n"
   - Capture and send image
5. Phone should:
   - Receive voice command
   - Receive image
   - Send both to OpenAI with prompt: "what's in front of me"
   - Display and speak the result

---

**Note**: The placeholder in ESP32 code currently sends "what's in front of me" as a test. Replace this with actual voice processing results.

