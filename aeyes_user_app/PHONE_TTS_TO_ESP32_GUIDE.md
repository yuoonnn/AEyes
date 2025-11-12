# Phone TTS to ESP32 Streaming Guide

## Current Status

The code has been updated to support phone TTS audio generation and streaming to ESP32, but it requires native platform code implementation.

## How It Works

1. **Phone TTS Generation**: Uses platform channels to call native TTS APIs (Android TextToSpeech or iOS AVSpeechSynthesizer)
2. **Audio File Creation**: Native code generates a WAV audio file
3. **Streaming**: Flutter reads the file and streams it to ESP32 via Wi-Fi

## Implementation Options

### Option 1: Implement Native Code (Recommended for Production)

You need to implement native code for Android and iOS to generate TTS audio files.

#### Android Implementation

Add to `android/app/src/main/kotlin/.../MainActivity.kt`:

```kotlin
import android.speech.tts.TextToSpeech
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import java.io.File
import java.io.FileOutputStream
import java.util.Locale

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.aeyes.tts/generate"
    private var tts: TextToSpeech? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "generateAudio") {
                val text = call.argument<String>("text") ?: ""
                val language = call.argument<String>("language") ?: "en-US"
                val rate = call.argument<Double>("rate") ?: 1.0
                val outputPath = call.argument<String>("outputPath") ?: ""
                
                generateTTSAudio(text, language, rate, outputPath, result)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun generateTTSAudio(text: String, language: String, rate: Double, outputPath: String, result: MethodChannel.Result) {
        tts = TextToSpeech(this) { status ->
            if (status == TextToSpeech.SUCCESS) {
                val locale = Locale.forLanguageTag(language.replace("-", "_"))
                tts?.language = locale
                tts?.setSpeechRate(rate.toFloat())
                
                // Use synthesizeToFile (API 21+)
                val file = File(outputPath)
                val params = Bundle()
                val utteranceId = "tts_${System.currentTimeMillis()}"
                
                val synthesisResult = tts?.synthesizeToFile(text, params, file, utteranceId)
                
                if (synthesisResult == TextToSpeech.SUCCESS) {
                    result.success(true)
                } else {
                    result.error("TTS_ERROR", "Failed to synthesize audio", null)
                }
            } else {
                result.error("TTS_INIT_ERROR", "Failed to initialize TTS", null)
            }
        }
    }
}
```

#### iOS Implementation

Add to `ios/Runner/AppDelegate.swift`:

```swift
import AVFoundation

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let ttsChannel = FlutterMethodChannel(name: "com.aeyes.tts/generate",
                                          binaryMessenger: controller.binaryMessenger)
    
    ttsChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "generateAudio" {
        guard let args = call.arguments as? [String: Any],
              let text = args["text"] as? String,
              let language = args["language"] as? String,
              let rate = args["rate"] as? Double,
              let outputPath = args["outputPath"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
          return
        }
        
        self.generateTTSAudio(text: text, language: language, rate: rate, outputPath: outputPath, result: result)
      } else {
        result(FlutterMethodNotImplemented)
      }
    })
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  func generateTTSAudio(text: String, language: String, rate: Double, outputPath: String, result: @escaping FlutterResult) {
    let synthesizer = AVSpeechSynthesizer()
    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = AVSpeechSynthesisVoice(language: language)
    utterance.rate = Float(rate * 0.5) // AVSpeechUtterance rate is 0.0-1.0
    
    // Create audio file
    let audioFileURL = URL(fileURLWithPath: outputPath)
    
    // Note: AVSpeechSynthesizer doesn't directly support file output
    // You'll need to use AVAudioEngine to record the output
    // This is more complex - consider using a library or alternative approach
    
    result(FlutterError(code: "NOT_IMPLEMENTED", message: "iOS TTS file generation requires AVAudioEngine implementation", details: nil))
  }
}
```

### Option 2: Use Alternative Package (Simpler)

Consider using a package that supports TTS file generation, such as:
- `flutter_tts` with platform channel extensions
- Custom package that wraps native TTS file generation

### Option 3: Use Phone Speaker + Record (Workaround)

1. Use `flutter_tts` to speak
2. Record the audio output using `record` package
3. Stream the recorded audio to ESP32

This requires audio recording permissions and is more complex.

## Current Code Status

The Flutter code is ready and will:
1. Try phone TTS first (when native code is implemented)
2. Fall back to ElevenLabs if phone TTS fails
3. Fall back to phone speaker if both fail

## Next Steps

1. **For Quick Testing**: The code will fall back to phone speaker, which works now
2. **For Production**: Implement the native code above for Android (iOS is more complex)
3. **Alternative**: Use a TTS service that provides audio files directly

## Testing

After implementing native code:
1. Run the app
2. Trigger TTS (e.g., image analysis)
3. Check logs for `[PhoneTTS] ✅ Generated audio file`
4. Audio should stream to ESP32 at `192.168.100.70:8080`

