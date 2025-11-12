import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import '../services/database_service.dart';
import '../models/user.dart' as app_user;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseService _databaseService = DatabaseService();

  // Add currentUserId getter
  String? get currentUserId => _auth.currentUser?.uid;

  // Login
  Future<String?> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // Register - UPDATED VERSION
  Future<String?> register(String name, String email, String password) async {
    try {
      // Create Firebase Auth user
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
      
      // Update display name
      await _auth.currentUser?.updateDisplayName(name);
      
      // ✅ CRITICAL: Create user profile in Firestore
      if (credential.user != null) {
        await _databaseService.saveUserProfile(app_user.User(
          id: credential.user!.uid, // ✅ ADD THIS - use the Firebase UID as ID
          email: email,
          name: name,
          role: 'user', // default role
          createdAt: DateTime.now(),
        ));
        
        print('✅ User profile created in Firestore for: $email');
      }
      
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // Google Sign-In - UPDATED VERSION
  Future<String?> signInWithGoogle() async {
    try {
      // Sign out from Google Sign-In first to force account selection
      final googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
      
      // Now sign in, which will prompt for account selection
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return 'Sign in aborted';
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      // ✅ ADD THIS: Create user profile if it doesn't exist
      if (userCredential.user != null && userCredential.additionalUserInfo?.isNewUser == true) {
        await _databaseService.saveUserProfile(app_user.User(
          id: userCredential.user!.uid, // ✅ ADD THIS
          email: userCredential.user!.email!,
          name: userCredential.user!.displayName ?? 'Google User',
          role: 'user',
          createdAt: DateTime.now(),
        ));
        print('✅ Google user profile created in Firestore');
      }
      
      return null;
    } on FirebaseAuthException catch (e) {
      // Handle account exists with different credential
      if (e.code == 'account-exists-with-different-credential') {
        // Get the email from the error
        final email = e.email;
        if (email != null) {
          // Get the list of sign-in methods for this email
          final methods = await _auth.fetchSignInMethodsForEmail(email);
          if (methods.isNotEmpty) {
            String providerName = methods.first;
            // Convert provider ID to user-friendly name
            if (providerName == 'password') {
              providerName = 'email/password';
            } else if (providerName == 'google.com') {
              providerName = 'Google';
            } else if (providerName == 'facebook.com') {
              providerName = 'Facebook';
            }
            return 'An account with this email already exists. Please sign in using $providerName instead.';
          }
        }
        return 'An account with this email already exists with a different sign-in method. Please use the original sign-in method.';
      }
      return e.message ?? e.code;
    } catch (e) {
      return e.toString();
    }
  }

  // Facebook Sign-In - UPDATED VERSION
  Future<String?> signInWithFacebook() async {
    try {
      final LoginResult result = await FacebookAuth.instance.login();
      if (result.status != LoginStatus.success) return 'Facebook sign-in failed';
      final OAuthCredential credential = FacebookAuthProvider.credential(result.accessToken!.token);
      
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      // ✅ ADD THIS: Create user profile if it doesn't exist
      if (userCredential.user != null && userCredential.additionalUserInfo?.isNewUser == true) {
        await _databaseService.saveUserProfile(app_user.User(
          id: userCredential.user!.uid, // ✅ ADD THIS
          email: userCredential.user!.email ?? 'facebook_user@example.com',
          name: userCredential.user!.displayName ?? 'Facebook User',
          role: 'user',
          createdAt: DateTime.now(),
        ));
        print('✅ Facebook user profile created in Firestore');
      }
      
      return null;
    } on FirebaseAuthException catch (e) {
      // Handle account exists with different credential
      if (e.code == 'account-exists-with-different-credential') {
        // Get the email from the error
        final email = e.email;
        if (email != null) {
          // Get the list of sign-in methods for this email
          final methods = await _auth.fetchSignInMethodsForEmail(email);
          if (methods.isNotEmpty) {
            String providerName = methods.first;
            // Convert provider ID to user-friendly name
            if (providerName == 'password') {
              providerName = 'email/password';
            } else if (providerName == 'google.com') {
              providerName = 'Google';
            } else if (providerName == 'facebook.com') {
              providerName = 'Facebook';
            }
            return 'An account with this email already exists. Please sign in using $providerName instead.';
          }
        }
        return 'An account with this email already exists with a different sign-in method. Please use the original sign-in method.';
      }
      return e.message ?? e.code;
    } catch (e) {
      return e.toString();
    }
  }

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
  }

  // Delete current account
  Future<String?> deleteCurrentAccount({bool isGuardian = false}) async {
    final user = _auth.currentUser;
    if (user == null) {
      return 'No authenticated user found.';
    }

    try {
      await _databaseService.deleteAccountData(isGuardian: isGuardian);
      await user.delete();
      await _auth.signOut();
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return 'Please sign in again, then try deleting your account.';
      }
      return e.message ?? e.code;
    } catch (e) {
      return e.toString();
    }
  }

  // Check and create profile if missing (call this after login)
  Future<void> ensureUserProfileExists() async {
    if (_auth.currentUser != null) {
      final existingProfile = await _databaseService.getUserProfile();
      if (existingProfile == null) {
        // Create profile if it doesn't exist
        await _databaseService.saveUserProfile(app_user.User(
          id: _auth.currentUser!.uid, // ✅ ADD THIS
          email: _auth.currentUser!.email!,
          name: _auth.currentUser!.displayName ?? 'User',
          role: 'user',
          createdAt: DateTime.now(),
        ));
        print('✅ Created missing user profile for existing user');
      }
    }
  }
}