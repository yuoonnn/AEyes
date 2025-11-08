@echo off
REM AEyes User App Setup Script for Windows
REM This script helps set up the development environment for the AEyes User App

echo 🚀 Setting up AEyes User App development environment...

REM Check if Flutter is installed
flutter --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Flutter is not installed. Please install Flutter first:
    echo    https://docs.flutter.dev/get-started/install
    pause
    exit /b 1
)

echo ✅ Flutter is installed

REM Check Flutter version
for /f "tokens=2" %%i in ('flutter --version ^| findstr "Flutter"') do set FLUTTER_VERSION=%%i
echo 📱 Flutter %FLUTTER_VERSION% detected

REM Run flutter doctor
echo 🔍 Running flutter doctor...
flutter doctor

REM Get dependencies
echo 📦 Installing dependencies...
flutter pub get

REM Check if google-services.json exists for Android
if not exist "android\app\google-services.json" (
    echo ⚠️  Warning: google-services.json not found in android\app\
    echo    Please download it from Firebase Console and place it in android\app\
)

REM Check if GoogleService-Info.plist exists for iOS
if not exist "ios\Runner\GoogleService-Info.plist" (
    echo ⚠️  Warning: GoogleService-Info.plist not found in ios\Runner\
    echo    Please download it from Firebase Console and place it in ios\Runner\
)

REM Check available devices
echo 📱 Checking available devices...
flutter devices

echo.
echo 🎉 Setup complete!
echo.
echo Next steps:
echo 1. Configure Firebase (see README.md for details)
echo 2. Run 'flutter run' to start the app
echo 3. For web: 'flutter run -d chrome'
echo 4. For Android: 'flutter run -d android'
echo 5. For iOS: 'flutter run -d ios' (macOS only)
echo.
echo 📚 For detailed instructions, see README.md
pause 