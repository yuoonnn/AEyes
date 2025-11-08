# Quick Start Guide - AEyes User App

This is a quick start guide to get the AEyes User App running on your machine in 5 minutes.

## 🚀 Quick Setup (5 minutes)

### 1. Prerequisites Check
Make sure you have:
- ✅ Flutter SDK installed (version 3.8.1+)
- ✅ Git installed
- ✅ A code editor (VS Code, Android Studio, etc.)

### 2. Clone and Setup
```bash
# Clone the repository
git clone <your-github-repo-url>
cd aeyes_user_app

# Run the setup script (choose your OS)
# For macOS/Linux:
chmod +x setup.sh
./setup.sh

# For Windows:
setup.bat
```

### 3. Firebase Setup (Required)
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or use existing one
3. Add your apps (Android/iOS/Web) following the prompts
4. Download configuration files:
   - `google-services.json` → `android/app/`
   - `GoogleService-Info.plist` → `ios/Runner/` (macOS only)
   - Web config → Update `lib/main.dart`

### 4. Run the App
```bash
# Check available devices
flutter devices

# Run on your preferred platform
flutter run                    # Auto-detect device
flutter run -d chrome         # Web
flutter run -d android        # Android
flutter run -d ios            # iOS (macOS only)
```

## 🎯 What You'll See

The app has two main interfaces:

### User Interface:
- **Login/Registration**: Email, Google, Facebook sign-in
- **Home Screen**: Main navigation with bottom tabs
- **Bluetooth Screen**: Device scanning and connection
- **Profile Screen**: User settings and information
- **Settings Screen**: App preferences

### Guardian Interface:
- **Guardian Login**: Separate authentication
- **Dashboard**: Monitor users, location, alerts
- **Settings**: Guardian-specific preferences

## 🔧 Common Issues & Solutions

### "Flutter not found"
```bash
# Install Flutter first
# https://docs.flutter.dev/get-started/install
```

### "Dependencies not found"
```bash
flutter clean
flutter pub get
```

### "Firebase configuration error"
- Check that config files are in correct locations
- Verify Firebase project settings
- See `FIREBASE_SETUP.md` for detailed instructions

### "Build failed"
```bash
flutter clean
flutter pub get
flutter run
```

## 📱 Testing the App

### Test User Flow:
1. Open app → Role Selection
2. Choose "User" → Login/Register
3. Navigate through screens
4. Test Bluetooth functionality
5. Try settings and profile

### Test Guardian Flow:
1. Open app → Role Selection
2. Choose "Guardian" → Login
3. Explore dashboard features
4. Check monitoring sections

## 🛠 Development Tips

### Hot Reload:
- Save files to see changes instantly
- Press `r` in terminal for hot reload
- Press `R` for hot restart

### Debug Mode:
- Use `print()` statements for debugging
- Check console output in terminal
- Use Flutter Inspector in VS Code/Android Studio

### Testing:
```bash
# Run tests
flutter test

# Run specific test file
flutter test test/widget_test.dart
```

## 📚 Next Steps

1. **Read the full README.md** for detailed documentation
2. **Check FIREBASE_SETUP.md** for Firebase configuration
3. **Explore the codebase** to understand the structure
4. **Join team discussions** for project updates

## 🆘 Need Help?

1. Check the troubleshooting section in README.md
2. Look at FIREBASE_SETUP.md for Firebase issues
3. Search existing GitHub issues
4. Contact the development team

---

**Happy coding! 🎉**

Remember: The app requires Firebase configuration to work properly. Make sure you complete the Firebase setup before running the app. 