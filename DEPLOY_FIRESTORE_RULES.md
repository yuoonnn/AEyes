# How to Deploy Firestore Rules to Firebase

## Steps to Deploy Firestore Rules

### Option 1: Using Firebase Console (Web UI)

1. **Go to Firebase Console**
   - Open your browser and go to [https://console.firebase.google.com/](https://console.firebase.google.com/)
   - Select your project: `aeyes-project`

2. **Navigate to Firestore Database**
   - In the left sidebar, click on **"Firestore Database"**
   - Click on the **"Rules"** tab at the top

3. **Update the Rules**
   - Copy the contents of `aeyes_user_app/firestore.rules`
   - Paste it into the rules editor in Firebase Console
   - Click **"Publish"** button

### Option 2: Using Firebase CLI

1. **Install Firebase CLI** (if not already installed)
   ```bash
   npm install -g firebase-tools
   ```

2. **Login to Firebase**
   ```bash
   firebase login
   ```

3. **Initialize Firebase** (if not already done)
   ```bash
   cd "aeyes_user_app"
   firebase init firestore
   ```

4. **Deploy the Rules**
   ```bash
   firebase deploy --only firestore:rules
   ```

### Option 3: Using FlutterFire CLI

1. **Install FlutterFire CLI**
   ```bash
   dart pub global activate flutterfire_cli
   ```

2. **Deploy Rules**
   ```bash
   cd "aeyes_user_app"
   flutterfire configure
   # Then manually deploy rules using Firebase CLI or Console
   ```

## Verify Rules Are Deployed

1. Go to Firebase Console → Firestore Database → Rules tab
2. Check that the rules match the content in `aeyes_user_app/firestore.rules`
3. The rules should allow:
   - Guardians to read guardians where `guardian_email` matches their email
   - Guardians to read user profiles, locations, devices, alerts, etc.
   - Users to read/write their own data

## Important Notes

- **Rules take effect immediately** after publishing
- **Test the rules** after deployment to ensure they work correctly
- If you see permission errors, check:
  1. Rules are deployed correctly
  2. User is authenticated
  3. Email addresses match (case-insensitive)
  4. Guardian documents exist in Firestore

## Troubleshooting

If guardians still can't see linked users:

1. **Check Firestore Console**:
   - Go to Firestore Database → Data tab
   - Check if `guardians` collection exists
   - Verify guardian documents have `guardian_email` field matching the guardian's email
   - Verify `relationship_status` is set to `'active'` for approved links

2. **Check Email Matching**:
   - Ensure emails are normalized to lowercase
   - Check for any extra spaces or characters
   - Verify the email in Firebase Auth matches the email in guardian documents

3. **Check Rules**:
   - Verify rules are deployed
   - Check browser console for permission errors
   - Test with Firebase Console's Rules Playground

