# Firestore Database Setup Guide

## ✅ What's Been Set Up

### 1. Database Service (`lib/services/database_service.dart`)
A comprehensive service that handles all Firestore operations:
- **User Operations**: Save/load user profiles
- **Settings Operations**: Save/load user settings
- **Device Operations**: Save/load device information, battery levels
- **Location Operations**: Save user locations
- **Detection Events**: Log AI detection events (hazards, OCR, currency)
- **Guardian Operations**: Link and manage guardians
- **Messages**: Send/receive messages between users and guardians
- **Emergency Alerts**: Create and manage emergency alerts

### 2. Updated Models
- **User Model** (`lib/models/user.dart`): Matches ERD with all fields
- **Settings Model** (`lib/models/settings.dart`): Complete settings structure

### 3. Integrated Screens
- **Profile Screen**: Now saves/loads from Firestore (including address!)
- **Settings Screen**: Now saves/loads from Firestore

### 4. Security Rules
Created `firestore.rules` file with proper access control:
- Users can only access their own data
- Guardians can access linked user data
- Proper authentication checks

## 🔧 Next Steps

### 1. Deploy Firestore Security Rules

You need to deploy the security rules to Firebase:

**Option A: Using Firebase CLI**
```bash
# Install Firebase CLI if not already installed
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase in your project (if not done)
cd "D:\Program Project\AEyes Project\aeyes_user_app"
firebase init firestore

# Deploy rules
firebase deploy --only firestore:rules
```

**Option B: Using Firebase Console**
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `aeyes-project`
3. Go to **Firestore Database** → **Rules**
4. Copy the contents of `firestore.rules`
5. Paste into the rules editor
6. Click **Publish**

### 2. Test the Database

1. **Test Profile Save**:
   - Go to Profile screen
   - Edit your profile (add address, phone)
   - Click Save
   - Check Firebase Console → Firestore → `users` collection

2. **Test Settings Save**:
   - Go to Settings screen
   - Change volume, language, etc.
   - Click Save Settings
   - Check Firebase Console → Firestore → `settings` collection

### 3. Database Collections Structure

Your Firestore will have these collections:

```
users/
  {userId}/
    - user_id, email, name, phone, address, role, created_at, updated_at

settings/
  {userId}/
    - settings_id, user_id, tts_language, tts_rate, audio_volume, etc.

devices/
  {deviceId}/
    - device_id, user_id, device_name, ble_mac_address, battery_level, etc.

locations/
  {locationId}/
    - location_id, user_id, latitude, longitude, timestamp, etc.

detection_events/
  {eventId}/
    - event_id, user_id, event_type, confidence, detected_label, etc.

guardians/
  {guardianId}/
    - guardian_id, user_id, guardian_email, guardian_name, etc.

messages/
  {messageId}/
    - message_id, user_id, guardian_id, message_type, content, etc.

emergency_alerts/
  {alertId}/
    - alert_id, user_id, alert_type, severity, triggered_at, etc.
```

## 📝 Usage Examples

### Save User Profile
```dart
final dbService = DatabaseService();
await dbService.saveUserProfile(
  User(
    id: userId,
    name: 'John Doe',
    email: 'john@example.com',
    phone: '+1234567890',
    address: '123 Main St',
  ),
);
```

### Save Settings
```dart
final dbService = DatabaseService();
await dbService.saveSettings(
  Settings(
    settingsId: userId,
    userId: userId,
    ttsLanguage: 'en',
    audioVolume: 75,
    emergencyContactsEnabled: true,
  ),
);
```

### Log Detection Event
```dart
await dbService.logDetectionEvent(
  eventType: 'hazard',
  confidence: 0.85,
  detectedLabel: 'Obstacle ahead',
  deviceId: deviceId,
);
```

### Get User Devices
```dart
final devices = await dbService.getUserDevices();
// Returns list of device maps
```

## 🔒 Security Notes

- All security rules are set to require authentication
- Users can only access their own data
- Guardians can access messages but not all user data
- Make sure to deploy the rules before using in production!

## 🚀 Ready to Use!

The database is now fully integrated. Your app will:
- ✅ Save user profiles to Firestore
- ✅ Save settings to Firestore
- ✅ Persist data across app restarts
- ✅ Support all entities from your ERD

Test it out and let me know if you need any adjustments!

