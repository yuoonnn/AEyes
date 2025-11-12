# Voice Control Implementation Guide

## ✅ What's Been Set Up

Your app now has **voice control** capabilities using the device's microphone! Here's what was implemented:

### 1. **Permissions Added**
- ✅ **Android**: Microphone permission (`RECORD_AUDIO`) added to `AndroidManifest.xml`
- ✅ **iOS**: Microphone and Speech Recognition permissions added to `Info.plist`

### 2. **Speech Recognition Service**
- ✅ Created `SpeechService` class in `lib/services/speech_service.dart`
- ✅ Integrated into `main.dart` and initialized on app startup
- ✅ Connected to `HomeScreen` for voice command processing

### 3. **Package Added**
- ✅ `speech_to_text: ^6.6.0` added to `pubspec.yaml`

## 🎤 How to Use Voice Control

### Basic Usage

The `SpeechService` is already initialized and connected in your app. Here's how to use it:

#### 1. **Start Listening**
```dart
await speechService.startListening();
```

#### 2. **Stop Listening**
```dart
await speechService.stopListening();
```

#### 3. **Handle Voice Commands**
The service automatically processes voice commands in `HomeScreen`. Currently supports:
- **"help"** or **"emergency"** - Shows emergency alert
- **"capture"**, **"analyze"**, or **"take picture"** - Triggers capture command
- **"settings"** - Navigates to settings screen
- **"home"** - Does nothing (already on home)

### Using the Voice Control Button Widget

A reusable button widget is available at `lib/widgets/voice_control_button.dart`:

```dart
import '../widgets/voice_control_button.dart';

// In your widget build method:
VoiceControlButton(
  speechService: speechService,
  backgroundColor: Colors.blue,
  iconColor: Colors.white,
  size: 60.0,
)
```

The button:
- Shows a microphone icon
- Animates when listening
- Automatically handles permission requests
- Changes color when active

### Custom Voice Command Handling

To add custom voice commands, modify the `onSpeechResult` callback in `HomeScreen`:

```dart
widget.speechService!.onSpeechResult = (String text) {
  final lowerCommand = text.toLowerCase().trim();
  
  // Add your custom commands here
  if (lowerCommand.contains('your command')) {
    // Handle your command
  }
};
```

## 📱 Platform-Specific Notes

### Android
- Requires `RECORD_AUDIO` permission (already added)
- Permission is requested automatically when starting to listen
- Works with Google Speech Recognition service

### iOS
- Requires `NSMicrophoneUsageDescription` (already added)
- Requires `NSSpeechRecognitionUsageDescription` (already added)
- Uses Apple's Speech Recognition framework
- May require internet connection for some languages

## 🔧 Advanced Configuration

### Change Language
```dart
await speechService.startListening(localeId: 'en_US'); // or 'tl_PH' for Tagalog
```

### Get Available Locales
```dart
final locales = await speechService.getAvailableLocales();
for (var locale in locales) {
  print('${locale.localeId}: ${locale.name}');
}
```

### Listen for Longer Duration
```dart
await speechService.startListening(
  listenFor: true,
  pauseFor: Duration(seconds: 5), // Pause after 5 seconds of silence
);
```

### Handle Partial Results
```dart
await speechService.startListening(
  partialResults: true, // Get results as user speaks
);
```

## 🎯 Example: Adding Voice Control to Any Screen

```dart
import '../services/speech_service.dart';

class MyScreen extends StatefulWidget {
  final SpeechService? speechService;
  
  @override
  void initState() {
    super.initState();
    
    if (widget.speechService != null) {
      widget.speechService!.onSpeechResult = (String text) {
        // Handle voice commands
        print('Heard: $text');
      };
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            if (widget.speechService != null) {
              await widget.speechService!.startListening();
            }
          },
          child: Text('Start Voice Control'),
        ),
      ),
    );
  }
}
```

## ⚠️ Important Notes

1. **Permissions**: The app will request microphone permission the first time you try to use voice control
2. **Internet**: Some speech recognition features may require internet connection
3. **Battery**: Continuous listening can drain battery - consider implementing timeout
4. **Privacy**: Voice data is processed by platform services (Google/Apple) - check their privacy policies

## 🐛 Troubleshooting

### "Speech recognition not available"
- Check if microphone permission is granted
- Ensure device has internet connection (for some languages)
- Try restarting the app

### "Microphone permission denied"
- Go to device settings → Apps → Your App → Permissions
- Enable microphone permission manually

### Voice commands not working
- Check that `speechService` is not null
- Verify `onSpeechResult` callback is set
- Check console logs for errors

## 🚀 Next Steps

You can now:
1. Add the `VoiceControlButton` widget to any screen
2. Customize voice commands in `HomeScreen`
3. Add voice control to other screens by passing `speechService`
4. Integrate with your existing ESP32 voice control system

---

**Note**: This implementation uses the phone's microphone. Your existing ESP32 voice control (via Bluetooth) continues to work independently!

