# Instructions for Classmate - Pulling AudioSpeaker Branch

## 🚀 Quick Start (If you already have the repo cloned)

```bash
cd AEyes
git fetch origin
git checkout AudioSpeaker
```

That's it! The AudioSpeaker branch is now checked out and ready to use.

**⚠️ If you have uncommitted changes:**

**Option 1: Stash changes (Recommended - keeps your work safe)**
```bash
git stash
git checkout AudioSpeaker
# Your changes are saved! Restore them later with: git stash pop
```

**Option 2: Discard changes (if you don't need them)**
```bash
# ⚠️ First, check what will be discarded
git status

# Quick way (recommended if you're sure)
git reset --hard HEAD
# This discards ALL changes (staged + unstaged) at once

# OR modern way (Git 2.23+) - step by step, more explicit
git restore --staged .  # Unstage any staged changes
git restore .           # Discard all working directory changes
```

**Which to use?**
- `git reset --hard HEAD` - ✅ **Recommended** - Simple, one command, does everything
- `git restore .` + `git restore --staged .` - More explicit, but requires two commands
- Both do the same thing, but `git reset --hard HEAD` is simpler
- ⚠️ **Warning:** Both commands permanently discard changes - make sure you don't need them!

**Option 3: Commit changes first (if you want to keep them)**
```bash
git add .
git commit -m "Save my work"
git checkout AudioSpeaker
```

---

## Prerequisites

1. Git installed on your computer
2. Access to the GitHub repository: `https://github.com/yuoonnn/AEyes.git`
3. ESP32-S3 development board with USB cable
4. Arduino IDE or PlatformIO installed
5. Flutter SDK installed (if testing the app)

## Step 1: Navigate to the Repository

```bash
cd AEyes
```

## Step 2: Fetch Latest Changes from GitHub

```bash
git fetch origin
```

This downloads the new `AudioSpeaker` branch from GitHub without switching to it yet.

## Step 3: Checkout the AudioSpeaker Branch

```bash
git checkout AudioSpeaker
```

Git will automatically create a local `AudioSpeaker` branch that tracks the remote `origin/AudioSpeaker` branch.

**Note:** If you have uncommitted changes, Git might prevent you from switching branches. You can either:
- Commit your changes first: `git add .` then `git commit -m "Your message"`
- Stash your changes: `git stash` (you can restore them later with `git stash pop`)
- Or discard changes if not needed: `git reset --hard`

## Step 4: Verify You're on the Correct Branch

```bash
git branch
```

You should see `* AudioSpeaker` (the asterisk indicates the current branch).

## Step 5: Upload ESP32 Code

1. Open `ESP32_WiFi_Audio_Receiver.ino` in Arduino IDE or PlatformIO
2. Install required libraries (if not already installed):
   - ArduinoJson (for JSON parsing)
   - WebServer (usually included with ESP32 Arduino core)
   - WiFi (usually included with ESP32 Arduino core)

3. Configure Wi-Fi settings (optional):
   - **AP Mode (Default)**: No changes needed - ESP32 will create its own Wi-Fi network
   - **STA Mode**: Uncomment and configure `STA_SSID` and `STA_PASSWORD` in the sketch

4. Select your board:
   - Board: ESP32S3 Dev Module
   - Upload Speed: 921600 (or lower if you have issues)
   - Port: Select your ESP32's COM port

5. Upload the sketch to ESP32-S3

6. Open Serial Monitor (115200 baud) to see:
   - Wi-Fi AP IP address (usually `192.168.4.1`)
   - Connection status
   - Audio reception logs

## Step 6: Test the ESP32

### Test Wi-Fi Connection:
1. Look for Wi-Fi network named `ESP32S3-AEyes` (password: `aeyes1234`)
2. Connect your phone or computer to this network
3. Open a browser and go to: `http://192.168.4.1:8080/ping`
   - Should return "OK"

### Test Status Endpoint:
```bash
curl http://192.168.4.1:8080/status
```

Should return JSON with connection status.

## Step 7: Set Up Flutter App (Optional - for testing)

If you want to test the Flutter app:

1. Navigate to the Flutter app directory:
   ```bash
   cd aeyes_user_app
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Configure ESP32 Wi-Fi IP in the app:
   - The app will use `192.168.4.1` by default (AP mode)
   - Or configure it in Settings screen if using STA mode

4. Run the app:
   ```bash
   flutter run
   ```

## Step 8: Testing Audio Streaming

1. **Connect Phone to ESP32 Wi-Fi**:
   - Connect to `ESP32S3-AEyes` network (password: `aeyes1234`)

2. **Configure App**:
   - Open app Settings
   - Set ESP32 Wi-Fi IP: `192.168.4.1`
   - Set Port: `8080`

3. **Test TTS**:
   - Trigger TTS (e.g., capture an image for analysis)
   - Audio should play through bone conduction speaker

4. **Monitor Serial Output**:
   - Watch Serial Monitor for audio reception logs
   - Check for any errors

## Troubleshooting

### ESP32 Not Creating Wi-Fi Network
- Check Serial Monitor for error messages
- Verify Wi-Fi antenna is connected (if external)
- Try resetting ESP32

### Can't Connect to ESP32
- Verify you're connected to `ESP32S3-AEyes` network
- Check IP address in Serial Monitor
- Try pinging: `ping 192.168.4.1`

### Audio Not Playing
- Check Serial Monitor for audio reception messages
- Verify I2S connections (BCLK, LRCLK, DIN)
- Check MAX98357A amplifier connections
- Verify bone conduction speaker is connected

### Flutter App Can't Connect
- Verify phone is on same Wi-Fi network as ESP32
- Check ESP32 IP address matches app settings
- Check firewall/security settings on phone
- Test with `curl` command first

## Getting Latest Changes

If the branch is updated on GitHub, pull the latest changes:

```bash
git pull origin AudioSpeaker
```

## Files to Check

Important files in this branch:
- `ESP32_WiFi_Audio_Receiver.ino` - ESP32 Arduino sketch
- `aeyes_user_app/lib/services/wifi_audio_service.dart` - Wi-Fi audio service
- `aeyes_user_app/lib/services/tts_service.dart` - Updated TTS service
- `WIFI_AUDIO_SETUP_GUIDE.md` - Detailed setup guide
- `WIFI_AUDIO_IMPLEMENTATION_SUMMARY.md` - Implementation details

## Hardware Connections

Verify these connections on ESP32-S3:

### I2S Audio (MAX98357A):
- BCLK → GPIO 40
- LRCLK → GPIO 39
- DIN → GPIO 38
- GND → GND
- VDD → 3.3V or 5V

### Camera (OV2640):
- Already configured in the sketch

### Buttons:
- Button 1 → GPIO 1
- Button 2 → GPIO 2
- Button 3 → GPIO 3
- Button 4 → GPIO 14
- Button 5 → GPIO 21
- Button 6 → GPIO 47

## Need Help?

Check these files for more information:
- `WIFI_AUDIO_SETUP_GUIDE.md` - Complete setup guide
- `WIFI_AUDIO_IMPLEMENTATION_SUMMARY.md` - Technical details
- Serial Monitor output - Real-time debugging information

## Next Steps

1. Upload the ESP32 code
2. Test Wi-Fi connection
3. Test audio streaming
4. Report any issues or improvements needed

Good luck! 🚀

