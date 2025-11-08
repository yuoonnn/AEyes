# Guardian-User Linking Fix Summary

## Problem
Guardians are getting "permission-denied" errors when trying to load their profile or access linked user data.

## Root Cause
The Firestore security rules need to be properly configured and deployed to allow:
1. Guardians to read their own profile
2. Guardians to query the guardians collection by email
3. Guardians to read linked user profiles

## Solution Applied

### 1. Updated Firestore Rules

The rules have been simplified and clarified:

**Users Collection:**
- Allows any authenticated user to read user profiles
- App logic ensures only linked users are accessed (by querying guardians collection first)
- Users can only create/update/delete their own profile

**Guardians Collection:**
- Users can read/write guardians where `user_id` matches their UID
- Guardians can read/update guardians where `guardian_email` matches their email
- This allows `.where()` queries to work correctly

### 2. Key Points About the Linking System

1. **Email Normalization**: All emails are normalized to lowercase for consistent matching
2. **Status Flow**: Guardian links start as `pending`, then become `active` when approved
3. **Query Flow**: 
   - Guardian queries `/guardians` collection by email and status
   - Gets `user_id` from matching guardian documents
   - Fetches user profiles from `/users/{userId}` for each linked user

## Next Steps

### 1. Deploy Firestore Rules

**CRITICAL**: The rules must be deployed to Firebase for them to take effect!

```bash
cd aeyes_user_app
firebase deploy --only firestore:rules
```

Or deploy through Firebase Console:
1. Go to Firebase Console → Firestore Database → Rules
2. Copy the rules from `firestore.rules`
3. Paste into the console
4. Click "Publish"

### 2. Verify the Rules Are Deployed

1. Check Firebase Console → Firestore → Rules tab
2. Verify the rules match what's in `firestore.rules`
3. Check the "Last published" timestamp

### 3. Test the Linking Flow

**As a User:**
1. Log in as a user
2. Go to Profile → Link Guardian
3. Enter guardian email: `guardian@test.com`
4. Enter guardian name: `Test Guardian`
5. Submit (creates pending request)

**As a Guardian:**
1. Log in as guardian with email `guardian@test.com`
2. Open Guardian Dashboard
3. Should see pending request
4. Click "Approve"
5. Should now see linked user

### 4. Debugging If Issues Persist

**Check Console Logs:**
- Look for email normalization: `Normalized email: ...`
- Check query results: `Found X active guardian links`
- Verify user IDs: `Found X user IDs to fetch`

**Check Firestore Console:**
1. Go to `/guardians` collection
2. Verify documents exist with correct:
   - `user_id`: Should match user's UID
   - `guardian_email`: Should be lowercase and match guardian's auth email
   - `relationship_status`: Should be `pending` or `active`

**Manual Query Test:**
In Firestore console, try:
```
Collection: guardians
Filter: guardian_email == "guardian@test.com"
Filter: relationship_status == "active"
```

## Common Issues

### Issue: "Permission denied" when loading profile
**Solution**: 
- Ensure rules are deployed
- Check that guardian is authenticated
- Verify guardian's UID matches the document ID in `/users` collection

### Issue: No pending requests found
**Possible Causes**:
1. Email mismatch (case sensitivity) - Check normalization
2. Rules not deployed - Deploy rules
3. Status not "pending" - Check `relationship_status` field

### Issue: No linked users after approval
**Possible Causes**:
1. Status not updated to "active" - Check `approveLinkRequest()` function
2. Email case mismatch - Verify normalization
3. Query failing - Check Firestore console manually

## Files Modified

1. `aeyes_user_app/firestore.rules` - Updated security rules
2. `GUARDIAN_LINKING_GUIDE.md` - Comprehensive guide (new)
3. `LINKING_FIX_SUMMARY.md` - This file (new)

## Testing Checklist

- [ ] Firestore rules deployed
- [ ] User can create guardian link request
- [ ] Guardian can see pending requests
- [ ] Guardian can approve requests
- [ ] Guardian can see linked users after approval
- [ ] Guardian can view linked user data (locations, devices, etc.)
- [ ] Email normalization works correctly
- [ ] No permission errors in console

