# iOS Testing Guide for AEyes App

This guide will help you set up and test the AEyes app on an iPhone using a Mac.

## Prerequisites

- ✅ Mac with Xcode installed
- ✅ iPhone (iOS 12.0 or later)
- ✅ Apple Developer Account (free account works for testing)
- ✅ USB cable to connect iPhone to Mac
- ✅ Project files (from Git or shared folder)

## Step 1: Prepare the Project

### Option A: Using Git (Recommended)
1. Make sure all changes are committed and pushed to your repository
2. Your friend should clone the repository:
   ```bash
   git clone https://github.com/yuoonnn/AEyes.git
   cd AEyes/aeyes_user_app
   ```

### Option B: Sharing Files
1. Zip the entire `aeyes_user_app` folder
2. Share it via cloud storage (Google Drive, Dropbox, etc.)
3. Your friend should extract it on their Mac

## Step 2: Install Dependencies

On the Mac, open Terminal and run:

```bash
cd "path/to/aeyes_user_app"
flutter pub get
```

## Step 3: Verify Firebase iOS Configuration

1. Check that `ios/Runner/GoogleService-Info.plist` exists
2. If missing, download it from Firebase Console:
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Select project: `aeyes-project`
   - Go to Project Settings → Your apps → iOS app
   - Download `GoogleService-Info.plist`
   - Place it in `ios/Runner/` folder

## Step 4: Open Project in Xcode

1. Open Terminal and navigate to the project:
   ```bash
   cd "path/to/aeyes_user_app/ios"
   open Runner.xcworkspace
   ```
   **Important**: Open `.xcworkspace`, NOT `.xcodeproj`

2. Wait for Xcode to index the project

## Step 5: Configure Signing & Capabilities

1. In Xcode, select the **Runner** project in the left sidebar
2. Select the **Runner** target
3. Go to **Signing & Capabilities** tab
4. Check **"Automatically manage signing"**
5. Select your **Team** (Apple Developer account)
   - If you don't have one, click "Add Account" and sign in with Apple ID
   - Free accounts work for development testing
6. Xcode will automatically generate a Bundle Identifier if needed

## Step 6: Connect iPhone

1. Connect your iPhone to the Mac using a USB cable
2. Unlock your iPhone
3. Trust the computer if prompted (tap "Trust" on iPhone)
4. In Xcode, at the top toolbar, you should see your iPhone in the device selector
5. If not visible:
   - Go to **Window** → **Devices and Simulators**
   - Make sure your iPhone appears and shows "Connected"

## Step 7: Enable Developer Mode on iPhone

1. On your iPhone, go to **Settings** → **Privacy & Security**
2. Scroll down to find **Developer Mode**
3. Enable **Developer Mode**
4. Restart your iPhone if prompted
5. After restart, confirm you want to enable Developer Mode

## Step 8: Build and Run

1. In Xcode, select your iPhone from the device selector (top toolbar)
2. Click the **Play** button (▶️) or press `Cmd + R`
3. Xcode will:
   - Build the app
   - Install it on your iPhone
   - Launch it automatically

### First Time Setup:
- On your iPhone, you may see: **"Untrusted Developer"**
- Go to **Settings** → **General** → **VPN & Device Management**
- Tap on your developer account
- Tap **"Trust [Your Name]"**
- Tap **"Trust"** to confirm
- Go back to the app and it should launch

## Step 9: Test Authentication

1. Test Email/Password login
2. Test Google Sign-In (make sure SHA-1 is added to Firebase for Android, but iOS uses different certificates)
3. Test Facebook Sign-In
4. Test Profile screen to see user data

## Troubleshooting

### "No devices found"
- Make sure iPhone is unlocked
- Trust the computer on iPhone
- Check USB cable connection
- Try a different USB port

### "Signing requires a development team"
- Go to Signing & Capabilities
- Select your Apple ID team
- Or create a free Apple Developer account

### "Failed to register bundle identifier"
- The Bundle ID might be taken
- Change it in Xcode: Runner target → General → Bundle Identifier
- Use something unique like: `com.yourname.aeyes_user_app`

### "GoogleService-Info.plist not found"
- Download it from Firebase Console
- Make sure it's in `ios/Runner/` folder
- In Xcode, right-click Runner folder → Add Files to Runner → Select the file

### Build Errors
- Run `flutter clean` in Terminal
- Run `flutter pub get`
- In Xcode: Product → Clean Build Folder (`Cmd + Shift + K`)
- Try building again

### App Crashes on Launch
- Check Xcode console for error messages
- Make sure Firebase is properly configured
- Verify `GoogleService-Info.plist` is correct

## Quick Checklist

- [ ] Project files on Mac
- [ ] `flutter pub get` completed
- [ ] `GoogleService-Info.plist` in `ios/Runner/`
- [ ] Xcode project opened (`.xcworkspace`)
- [ ] Signing configured with Apple ID
- [ ] iPhone connected and trusted
- [ ] Developer Mode enabled on iPhone
- [ ] App built and installed
- [ ] App trusted in iPhone settings
- [ ] App launches successfully

## Notes

- **Free Apple Developer Account**: Works for testing on your own devices
- **Paid Account ($99/year)**: Required for App Store distribution
- **TestFlight**: Requires paid account for beta testing with others
- **Development builds expire**: After 7 days, you'll need to rebuild

## Next Steps After Testing

1. Test all authentication methods
2. Test Bluetooth connection (if you have smart glasses)
3. Test all app features
4. Report any bugs or issues
5. If everything works, consider setting up TestFlight for easier testing

---

**Need Help?** Check the main `FIREBASE_IOS_SETUP.md` for more detailed Firebase configuration steps.

