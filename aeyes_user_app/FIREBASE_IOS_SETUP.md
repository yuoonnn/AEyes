# Firebase iOS Setup Guide for AEyes User App

This guide will help you set up Firebase for iOS in the AEyes User App project.

## Prerequisites

1. A Google account
2. Access to [Firebase Console](https://console.firebase.google.com/)
3. macOS with Xcode installed (for iOS development)
4. An Apple Developer account (for device testing)

## Step 1: Get Your Bundle ID

Your iOS bundle ID is: **`com.example.aeyesUserApp`**

You can verify this in Xcode:
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the Runner project in the navigator
3. Select the Runner target
4. Go to the "General" tab
5. Check "Bundle Identifier" - it should be `com.example.aeyesUserApp`

## Step 2: Add iOS App to Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **`aeyes-project`** (or create a new one)
3. Click the **iOS icon** (🍎) or click "Add app" → "iOS"
4. Enter the following:
   - **Bundle ID**: `com.example.aeyesUserApp`
   - **App nickname**: `AEyes User App iOS` (optional)
   - **App Store ID**: Leave blank (for now)
5. Click **"Register app"**

## Step 3: Download GoogleService-Info.plist

1. After registering, Firebase will generate a `GoogleService-Info.plist` file
2. Click **"Download GoogleService-Info.plist"**
3. **IMPORTANT**: Do NOT add this file to your project yet - we'll do it properly in the next step

## Step 4: Add GoogleService-Info.plist to Xcode Project

### Method 1: Using Xcode (Recommended)

1. Open `ios/Runner.xcworkspace` in Xcode
2. In the Project Navigator (left sidebar), right-click on the **Runner** folder
3. Select **"Add Files to Runner..."**
4. Navigate to where you downloaded `GoogleService-Info.plist`
5. Select the file
6. **IMPORTANT**: Make sure these options are checked:
   - ✅ "Copy items if needed" (so the file is copied into your project)
   - ✅ "Add to targets: Runner" (so it's included in the build)
7. Click **"Add"**
8. Verify the file appears in the Runner folder in Xcode

### Method 2: Manual Copy (Alternative)

1. Copy the downloaded `GoogleService-Info.plist` file
2. Paste it into: `aeyes_user_app/ios/Runner/`
3. Open `ios/Runner.xcworkspace` in Xcode
4. Right-click on the Runner folder → "Add Files to Runner..."
5. Select the `GoogleService-Info.plist` file
6. Make sure "Copy items if needed" is **unchecked** (since it's already there)
7. Make sure "Add to targets: Runner" is **checked**
8. Click "Add"

## Step 5: Verify AppDelegate.swift

The `AppDelegate.swift` file should already have Firebase initialization:

```swift
import Flutter
import UIKit
import FirebaseCore

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Initialize Firebase
    FirebaseApp.configure()
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

If it doesn't match, update it to include `import FirebaseCore` and `FirebaseApp.configure()`.

## Step 6: Configure Authentication Providers (iOS)

### Email/Password Authentication

1. In Firebase Console, go to **Authentication** → **Sign-in method**
2. Enable **Email/Password** if not already enabled

### Google Sign-In for iOS

1. In Firebase Console, go to **Authentication** → **Sign-in method**
2. Enable **Google** sign-in
3. You'll need to configure OAuth:
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Select your Firebase project
   - Go to **APIs & Services** → **Credentials**
   - Create an **OAuth 2.0 Client ID** for iOS
   - Enter your bundle ID: `com.example.aeyesUserApp`
   - Download the configuration (if needed)

### Facebook Sign-In for iOS

1. In Firebase Console, enable **Facebook** sign-in
2. You'll need:
   - Facebook App ID
   - Facebook App Secret
   - Configure Facebook Login in [Facebook Developers](https://developers.facebook.com/)
   - Add iOS platform to your Facebook app
   - Configure bundle ID and URL schemes

## Step 7: Configure Info.plist (if needed)

For Google Sign-In, you may need to add URL schemes to `Info.plist`:

1. Open `ios/Runner/Info.plist` in Xcode
2. Add the following (if not present):

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.googleusercontent.apps.YOUR-REVERSED-CLIENT-ID</string>
    </array>
  </dict>
</array>
```

Replace `YOUR-REVERSED-CLIENT-ID` with the reversed client ID from your `GoogleService-Info.plist` (look for `REVERSED_CLIENT_ID`).

## Step 8: Install Pods (if needed)

If you haven't already, install CocoaPods dependencies:

```bash
cd ios
pod install
cd ..
```

## Step 9: Build and Test

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select a simulator or connected iOS device
3. Build and run the app: `flutter run` or press ⌘R in Xcode
4. Test Firebase authentication:
   - Try registering a new user
   - Try signing in with email/password
   - Try Google sign-in (if configured)
   - Check Firebase Console to see if users are being created

## Step 10: Verify Firebase Connection

1. Run the app on iOS simulator or device
2. Try to register/login
3. Check Firebase Console → **Authentication** → **Users** to see if users are created
4. Check Firebase Console → **Firestore Database** to see if data is being written

## Troubleshooting

### Error: "GoogleService-Info.plist not found"

**Solution:**
- Verify the file is in `ios/Runner/` directory
- Check that it's added to the Xcode project (should appear in Project Navigator)
- Verify it's included in the Runner target (check Target Membership in File Inspector)

### Error: "FirebaseApp.configure() failed"

**Solution:**
- Verify `GoogleService-Info.plist` is correctly placed
- Check that the bundle ID in `GoogleService-Info.plist` matches your app's bundle ID
- Make sure `import FirebaseCore` is present in `AppDelegate.swift`
- Clean build folder: In Xcode, Product → Clean Build Folder (⇧⌘K)

### Error: "No such module 'FirebaseCore'"

**Solution:**
- Run `cd ios && pod install && cd ..`
- Make sure you're opening `Runner.xcworkspace` (not `Runner.xcodeproj`)
- In Xcode, Product → Clean Build Folder

### Authentication not working

**Solution:**
- Verify authentication providers are enabled in Firebase Console
- Check that `GoogleService-Info.plist` has correct configuration
- For Google Sign-In, verify OAuth client ID is configured
- Check Xcode console for error messages

### Build errors

**Solution:**
```bash
flutter clean
cd ios
pod deintegrate
pod install
cd ..
flutter pub get
```

## Security Notes

⚠️ **IMPORTANT**: 
- Never commit `GoogleService-Info.plist` to public repositories
- Add it to `.gitignore` if it contains sensitive information
- For production, consider using environment variables or secure storage

## Next Steps

After iOS setup is complete:

1. ✅ Test authentication flows
2. ✅ Test Firestore read/write operations
3. ✅ Configure Firestore Security Rules
4. ✅ Set up push notifications (if needed)
5. ✅ Configure Analytics (if needed)

## Additional Resources

- [Firebase iOS Setup Documentation](https://firebase.google.com/docs/ios/setup)
- [FlutterFire Documentation](https://firebase.flutter.dev/)
- [Firebase Console](https://console.firebase.google.com/)

---

**Need Help?** Check the main `FIREBASE_SETUP.md` file for general Firebase setup instructions.

