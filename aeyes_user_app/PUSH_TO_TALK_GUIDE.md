# Push-to-Talk Voice Control Guide

## ✅ Implementation Complete!

Your app now has **push-to-talk voice control** that works exactly as you described:

1. **User holds the button** → Starts listening to voice
2. **User speaks a question** (e.g., "what's in front of me", "how much am I holding")
3. **User releases the button** → Stops listening, captures image from ESP32, sends both to OpenAI
4. **AI analyzes** the image with the voice command as the prompt
5. **Result is spoken** via TTS

## 🎯 How It Works

### Flow Diagram
```
[User Holds Button] 
    ↓
[Speech Recognition Starts]
    ↓
[User Speaks: "What's in front of me?"]
    ↓
[User Releases Button]
    ↓
[Speech Recognition Stops & Gets Final Text]
    ↓
[Request ESP32 to Capture Image]
    ↓
[ESP32 Captures & Sends Image via BLE]
    ↓
[Send Voice Command + Image to OpenAI]
    ↓
[AI Analyzes with Custom Prompt]
    ↓
[Display Result + Speak via TTS]
```

## 📱 Where to Find It

The push-to-talk button is now on the **Home Screen** in a dedicated card section:
- Look for "Voice-Controlled Analysis" card
- Large circular button (100px) with microphone icon
- Button turns red and pulses when listening
- Shows loading spinner while processing

## 🔧 Technical Details

### Files Modified/Created:

1. **`lib/services/openai_service.dart`**
   - Added `analyzeImageWithPrompt()` method
   - Modified `analyzeImage()` to accept optional `prompt` parameter
   - Voice command becomes the AI prompt

2. **`lib/services/bluetooth_service.dart`**
   - Added `requestImageCapture()` method
   - Sends "CAPTURE\n" command to ESP32 via BLE

3. **`lib/widgets/push_to_talk_button.dart`** (NEW)
   - Complete push-to-talk implementation
   - Handles speech recognition, image capture, and AI analysis
   - Visual feedback (pulsing, colors, loading states)

4. **`lib/screens/home_screen.dart`**
   - Added push-to-talk button UI
   - Integrated with TTS service for audio feedback
   - Shows results in snackbar and updates AI state

## ⚠️ ESP32 Side Requirements

**IMPORTANT**: Your ESP32 code needs to handle the "CAPTURE" command sent via BLE.

### Current Status
The app sends `"CAPTURE\n"` to the ESP32's image characteristic. Your ESP32 should:

1. **Listen for write commands** on the image characteristic (currently it's notify-only)
2. **Parse the "CAPTURE" command**
3. **Call `sendCameraImage()`** when command is received

### ESP32 Code Update Needed

You'll need to modify your ESP32 code to:

```cpp
// In your BLE characteristic setup, make it writable:
pCharacteristic = pService->createCharacteristic(
  CHARACTERISTIC_UUID,
  BLECharacteristic::PROPERTY_NOTIFY | BLECharacteristic::PROPERTY_WRITE
);

// Add a callback to handle writes:
class MyCharacteristicCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {
    std::string value = pCharacteristic->getValue();
    if (value == "CAPTURE\n" || value.find("CAPTURE") != std::string::npos) {
      sendCameraImage();
    }
  }
};

pCharacteristic->setCallbacks(new MyCharacteristicCallbacks());
```

## 🎤 Usage Examples

### Example 1: "What's in front of me?"
1. Hold button
2. Say: "What's in front of me?"
3. Release button
4. ESP32 captures image
5. AI analyzes: "I can see a door ahead, about 3 meters away. There's a table to your left with some objects on it."

### Example 2: "How much am I holding?"
1. Hold button
2. Say: "How much am I holding?"
3. Release button
4. ESP32 captures image
5. AI analyzes: "You are holding a 100 peso bill and two 20 peso coins. Total: 140 pesos."

### Example 3: "Describe this room"
1. Hold button
2. Say: "Describe this room"
3. Release button
4. ESP32 captures image
5. AI analyzes: "This is a living room with a sofa, coffee table, and a window. The room appears well-lit and tidy."

## 🐛 Troubleshooting

### "ESP32 not connected"
- Make sure ESP32 is paired and connected via Bluetooth screen
- Check that BLE connection is active

### "No voice command detected"
- Speak clearly and wait for the final result
- Check microphone permissions
- Try speaking louder or closer to the microphone

### "Image capture timeout"
- ESP32 may not be responding to CAPTURE command
- Check ESP32 serial monitor for errors
- Verify ESP32 code handles the CAPTURE command

### "Analysis failed"
- Check OpenAI API key is set
- Verify internet connection
- Check API quota/limits

## 🔄 Alternative: Manual Image Capture

If ESP32 doesn't support the CAPTURE command yet, you can:
1. Use ESP32 button to capture image manually
2. The image will still be received and can be analyzed
3. But voice command won't be automatically paired with it

## 📝 Next Steps

1. **Test the flow**: Try holding the button and speaking
2. **Update ESP32 code**: Add CAPTURE command handler (see above)
3. **Customize prompts**: Modify the prompt template in `push_to_talk_button.dart` if needed
4. **Add more examples**: Update the example text in HomeScreen

---

**Note**: The voice command is sent to OpenAI as: 
> "You are assisting a blind user. Answer this question about the image: [your voice command]. Be clear, concise, and helpful."

You can customize this prompt in `push_to_talk_button.dart` line ~210.

