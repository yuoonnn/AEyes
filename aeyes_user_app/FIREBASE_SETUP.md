# Firebase Setup Guide for AEyes User App

This guide will help you set up Firebase for the AEyes User App project.

## Prerequisites

1. A Google account
2. Access to [Firebase Console](https://console.firebase.google.com/)

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project" or "Add project"
3. Enter project name: `AEyes User App` (or your preferred name)
4. Choose whether to enable Google Analytics (recommended)
5. Click "Create project"

## Step 2: Configure Authentication

1. In Firebase Console, go to "Authentication" → "Sign-in method"
2. Enable the following providers:
   - **Email/Password**: Enable
   - **Google**: Enable and configure
   - **Facebook**: Enable and configure (requires Facebook Developer account)

### Google Sign-in Setup:
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your Firebase project
3. Go to "APIs & Services" → "Credentials"
4. Create OAuth 2.0 Client ID for Android and iOS

### Facebook Sign-in Setup:
1. Go to [Facebook Developers](https://developers.facebook.com/)
2. Create a new app
3. Add Facebook Login product
4. Configure OAuth redirect URIs

## Step 3: Configure Firestore Database

1. In Firebase Console, go to "Firestore Database"
2. Click "Create database"
3. Choose "Start in test mode" (for development)
4. Select a location close to your users
5. Click "Done"

## Step 4: Add Android App

1. In Firebase Console, click the Android icon (</>) to add Android app
2. Enter package name: `com.example.aeyes_user_app`
3. Enter app nickname: `AEyes User App`
4. Click "Register app"
5. Download `google-services.json`
6. Place the file in `android/app/` directory

## Step 5: Add iOS App (macOS only)

1. In Firebase Console, click the iOS icon to add iOS app
2. Enter bundle ID: `com.example.aeyesUserApp`
3. Enter app nickname: `AEyes User App`
4. Click "Register app"
5. Download `GoogleService-Info.plist`
6. Place the file in `ios/Runner/` directory

## Step 6: Add Web App

1. In Firebase Console, click the web icon (</>) to add web app
2. Enter app nickname: `AEyes User App Web`
3. Click "Register app"
4. Copy the Firebase configuration object
5. Update `lib/main.dart` with your config:

```dart
// Replace with your actual Firebase config from Firebase Console
const firebaseOptions = FirebaseOptions(
  apiKey: "your-api-key-here",
  authDomain: "your-project-id.firebaseapp.com",
  projectId: "your-project-id",
  storageBucket: "your-project-id.appspot.com",
  messagingSenderId: "your-sender-id",
  appId: "your-app-id",
);
```

## Step 7: Security Rules (Optional)

### Firestore Security Rules:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow authenticated users to read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Allow guardians to read their ward's data
    match /guardians/{guardianId}/wards/{wardId} {
      allow read, write: if request.auth != null && request.auth.uid == guardianId;
    }
  }
}
```

## Step 8: Environment Variables (Optional)

For production, consider using environment variables for sensitive data:

1. Create `.env` file in project root:
```
FIREBASE_API_KEY=your-api-key
FIREBASE_PROJECT_ID=your-project-id
OPENAI_API_KEY=your-openai-key
```

2. Add `.env` to `.gitignore`
3. Use `flutter_dotenv` package to load environment variables

## Troubleshooting

### Common Issues:

1. **"google-services.json not found"**:
   - Ensure file is in `android/app/` directory
   - Check file name spelling
   - Verify file permissions

2. **"GoogleService-Info.plist not found"**:
   - Ensure file is in `ios/Runner/` directory
   - Check file name spelling
   - Verify file permissions

3. **Authentication errors**:
   - Verify Firebase project settings
   - Check API keys in configuration
   - Ensure authentication providers are enabled

4. **Web authentication issues**:
   - Check browser console for errors
   - Verify Firebase web configuration
   - Clear browser cache and cookies

5. **Build errors**:
   - Run `flutter clean`
   - Run `flutter pub get`
   - Check Firebase configuration syntax

### Platform-Specific Issues:

#### Android:
- Ensure `google-services.json` is properly placed
- Check that Google Play Services are installed on device/emulator
- Verify SHA-1 fingerprint in Firebase Console

#### iOS:
- Ensure `GoogleService-Info.plist` is properly placed
- Check that the file is added to Xcode project
- Verify bundle ID matches Firebase configuration

#### Web:
- Check browser console for JavaScript errors
- Verify Firebase web configuration
- Ensure HTTPS is used in production

## Testing Firebase Configuration

1. Run the app: `flutter run`
2. Try to register a new user
3. Try to sign in with existing user
4. Check Firebase Console to see if data is being created

## Production Considerations

1. **Security Rules**: Update Firestore security rules for production
2. **Authentication**: Configure proper authentication providers
3. **Environment Variables**: Use environment variables for sensitive data
4. **Monitoring**: Enable Firebase Analytics and Crashlytics
5. **Backup**: Set up regular database backups

## Support

If you encounter issues:

1. Check Firebase Console for error messages
2. Review Firebase documentation
3. Check Flutter Firebase plugin documentation
4. Contact the development team

---

**Note**: Keep your Firebase configuration files secure and never commit them to public repositories. Use environment variables for production deployments. 