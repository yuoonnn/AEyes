#!/bin/bash

# AEyes User App Setup Script
# This script helps set up the development environment for the AEyes User App

echo "🚀 Setting up AEyes User App development environment..."

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed. Please install Flutter first:"
    echo "   https://docs.flutter.dev/get-started/install"
    exit 1
fi

echo "✅ Flutter is installed"

# Check Flutter version
FLUTTER_VERSION=$(flutter --version | grep -o "Flutter [0-9]\+\.[0-9]\+\.[0-9]\+" | head -1)
echo "📱 $FLUTTER_VERSION detected"

# Run flutter doctor
echo "🔍 Running flutter doctor..."
flutter doctor

# Get dependencies
echo "📦 Installing dependencies..."
flutter pub get

# Check if google-services.json exists for Android
if [ ! -f "android/app/google-services.json" ]; then
    echo "⚠️  Warning: google-services.json not found in android/app/"
    echo "   Please download it from Firebase Console and place it in android/app/"
fi

# Check if GoogleService-Info.plist exists for iOS
if [ ! -f "ios/Runner/GoogleService-Info.plist" ]; then
    echo "⚠️  Warning: GoogleService-Info.plist not found in ios/Runner/"
    echo "   Please download it from Firebase Console and place it in ios/Runner/"
fi

# Check available devices
echo "📱 Checking available devices..."
flutter devices

echo ""
echo "🎉 Setup complete!"
echo ""
echo "Next steps:"
echo "1. Configure Firebase (see README.md for details)"
echo "2. Run 'flutter run' to start the app"
echo "3. For web: 'flutter run -d chrome'"
echo "4. For Android: 'flutter run -d android'"
echo "5. For iOS: 'flutter run -d ios' (macOS only)"
echo ""
echo "📚 For detailed instructions, see README.md" 