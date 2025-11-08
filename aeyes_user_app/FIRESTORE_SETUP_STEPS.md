# Firestore Database Setup - Step by Step Guide

## Step 1: Create Firestore Database in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **`aeyes-project`**
3. In the left sidebar, click **"Firestore Database"**
4. Click **"Create database"** button

### Choose Database Mode:
- Select **"Start in test mode"** (for development)
  - ⚠️ **Important**: We'll add security rules next, so this is temporary
- Click **"Next"**

### Choose Location:
- Select a location closest to your users (e.g., `asia-southeast1` for Philippines)
- Click **"Enable"**

## Step 2: Deploy Security Rules

### Option A: Using Firebase Console (Easiest)

1. In Firebase Console, go to **Firestore Database** → **Rules** tab
2. You'll see default test mode rules:
   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /{document=**} {
         allow read, write: if request.time < timestamp.date(2025, 1, 1);
       }
     }
   }
   ```
3. **Delete** the default rules
4. **Copy** the entire contents of `firestore.rules` file from your project
5. **Paste** into the rules editor
6. Click **"Publish"** button
7. Wait for confirmation: "Rules published successfully"

### Option B: Using Firebase CLI (Advanced)

```bash
# Install Firebase CLI (if not installed)
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase in your project
cd "D:\Program Project\AEyes Project\aeyes_user_app"
firebase init firestore

# Deploy rules
firebase deploy --only firestore:rules
```

## Step 3: Verify Database is Ready

1. In Firebase Console → **Firestore Database** → **Data** tab
2. You should see an empty database (no collections yet)
3. Collections will be created automatically when your app saves data:
   - `users`
   - `settings`
   - `devices`
   - `locations`
   - `detection_events`
   - `guardians`
   - `messages`
   - `emergency_alerts`

## Step 4: Test the Connection

### Test 1: Save Profile
1. Run your app
2. Login
3. Go to **Profile** screen
4. Edit your profile (add address/phone)
5. Click **Save**
6. Go to Firebase Console → Firestore → **Data** tab
7. You should see:
   - Collection: `users`
   - Document with your user ID
   - Fields: `user_id`, `email`, `name`, `phone`, `address`, etc.

### Test 2: Save Settings
1. Go to **Settings** screen
2. Change volume settings
3. Click **Save Settings**
4. Check Firestore → `settings` collection
5. You should see your settings document

## Step 5: Verify Security Rules

1. Go to **Firestore Database** → **Rules** tab
2. Verify your rules are deployed (should match `firestore.rules` file)
3. Rules should enforce:
   - ✅ Users can only access their own data
   - ✅ Authentication required
   - ✅ Proper access control for guardians

## Troubleshooting

### "Permission denied" errors
- **Cause**: Security rules not deployed or incorrect
- **Fix**: Deploy `firestore.rules` again

### "Collection doesn't exist" warnings
- **Cause**: Normal - collections are created automatically
- **Fix**: No action needed, collections will appear when data is saved

### Can't see data in console
- **Cause**: Data might not be saved yet
- **Fix**: 
  1. Check app logs for errors
  2. Make sure user is authenticated
  3. Try saving profile/settings again

### Rules not updating
- **Cause**: Browser cache or deployment delay
- **Fix**: 
  1. Wait 1-2 minutes
  2. Refresh Firebase Console
  3. Check rules tab again

## Security Rules Overview

Your rules enforce:
- ✅ **Authentication required** for all operations
- ✅ **Users can only access their own data**
- ✅ **Guardians can access linked user messages**
- ✅ **Proper read/write permissions**

## Next Steps

Once Firestore is set up:
1. ✅ Test saving profile data
2. ✅ Test saving settings
3. ✅ Verify data appears in Firebase Console
4. ✅ Test loading data on app restart

## Quick Checklist

- [ ] Firestore database created
- [ ] Security rules deployed
- [ ] Test profile save works
- [ ] Test settings save works
- [ ] Data visible in Firebase Console
- [ ] No permission errors in app

---

**Note**: The security rules file (`firestore.rules`) is already created in your project. Just copy and paste it into Firebase Console!

