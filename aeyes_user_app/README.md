# AEyes User App

A Flutter app for visually impaired users with guardian monitoring, Bluetooth communication, AI image processing, and text-to-speech.

## 🚀 Quick Start (For Teammates)

### 1. Install Flutter
- Download from: https://docs.flutter.dev/get-started/install
- Run `flutter doctor` to verify installation

### 2. Get the Project
```bash
git clone <your-github-repo-url>
cd aeyes_user_app
```

### 3. Install Dependencies
```bash
flutter pub get
```

### 4. Run the App
```bash
flutter run
```

That's it! The app should start and you can explore the features.

## 🔑 Test Login Credentials

### For Guardian Login:
- **Email**: `guardian@example.com`
- **Password**: `password123`

### For User Login:
- You can register a new account, or use Google/Facebook sign-in
- Or use any email/password combination (Firebase will create the account)

## 📱 What to Test

### User Interface:
- **Role Selection** → Choose "User"
- **Login/Register** → Try email or Google sign-in
- **Home Screen** → Navigate with bottom tabs
- **Bluetooth** → Simulate device connection
- **Settings** → Check preferences

### Guardian Interface:
- **Role Selection** → Choose "Guardian"
- **Login** → Use the credentials above
- **Dashboard** → View monitoring features
- **Alerts** → Check notification system

## 🔧 If Something Goes Wrong

```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

## 📚 More Details

- **Firebase Setup**: See `FIREBASE_SETUP.md` if you need to configure Firebase
- **Full Documentation**: Check the detailed guides if you need more info

---

**Note**: The app uses mock data for demonstration. Real Firebase setup is only needed for full development.
