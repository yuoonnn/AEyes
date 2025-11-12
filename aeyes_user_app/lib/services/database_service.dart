import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user.dart' as app_user;
import '../models/settings.dart' as app_settings;

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // ========== USER OPERATIONS ==========
  
  /// Create or update user profile in Firestore
  Future<void> saveUserProfile(app_user.User user) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    
    await _firestore.collection('users').doc(currentUserId).set({
      'user_id': currentUserId,
      'email': user.email,
      'name': user.name,
      'phone': user.phone ?? '',
      'address': user.address ?? '',
      'role': user.role ?? 'user',
      'created_at': user.createdAt ?? FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Get user profile from Firestore
  Future<app_user.User?> getUserProfile() async {
    if (currentUserId == null) return null;
    
    final doc = await _firestore.collection('users').doc(currentUserId).get();
    if (!doc.exists) return null;
    
    final data = doc.data()!;
    return app_user.User.fromMap(data, currentUserId!);
  }

  /// Delete the current user's account data from Firestore
  Future<void> deleteAccountData({bool isGuardian = false}) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('User not authenticated');

    final email = _auth.currentUser?.email?.trim().toLowerCase();

    Future<void> deleteDocIfExists(DocumentReference ref) async {
      try {
        await ref.delete();
      } on FirebaseException catch (e) {
        if (e.code != 'not-found') rethrow;
      }
    }

    // Delete primary documents
    await deleteDocIfExists(_firestore.collection('users').doc(uid));
    await deleteDocIfExists(_firestore.collection('settings').doc(uid));

    // Delete collections tied to the user ID
    await _deleteQueryBatch(
      _firestore.collection('devices').where('user_id', isEqualTo: uid),
    );
    await _deleteQueryBatch(
      _firestore.collection('locations').where('user_id', isEqualTo: uid),
    );
    await _deleteQueryBatch(
      _firestore.collection('detection_events').where('user_id', isEqualTo: uid),
    );
    await _deleteQueryBatch(
      _firestore.collection('emergency_alerts').where('user_id', isEqualTo: uid),
    );
    await _deleteQueryBatch(
      _firestore.collection('messages').where('user_id', isEqualTo: uid),
    );
    await _deleteQueryBatch(
      _firestore.collection('guardians').where('user_id', isEqualTo: uid),
    );

    // Additional cleanup for guardians: remove records where they are the guardian
    if (isGuardian && email != null && email.isNotEmpty) {
      final guardianLinks = await _firestore
          .collection('guardians')
          .where('guardian_email', isEqualTo: email)
          .get();

      for (final doc in guardianLinks.docs) {
        await _deleteQueryBatch(
          _firestore.collection('messages').where('guardian_id', isEqualTo: doc.id),
        );
        await deleteDocIfExists(doc.reference);
      }
    }
  }

  // ========== SETTINGS OPERATIONS ==========
  
  /// Save user settings to Firestore
  Future<void> saveSettings(app_settings.Settings settings) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    
    await _firestore.collection('settings').doc(currentUserId).set({
      'settings_id': currentUserId,
      'user_id': currentUserId,
      'tts_language': settings.ttsLanguage,
      'tts_rate': settings.ttsRate,
      'tts_voice': settings.ttsVoice,
      'audio_volume': settings.audioVolume,
      'beep_volume': settings.beepVolume,
      'hazard_confidence_threshold': settings.hazardConfidenceThreshold,
      'detection_mode': settings.detectionMode,
      'verbosity_level': settings.verbosityLevel,
      'emergency_contacts_enabled': settings.emergencyContactsEnabled,
      'location_sharing_enabled': settings.locationSharingEnabled,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Get user settings from Firestore
  Future<app_settings.Settings?> getSettings() async {
    if (currentUserId == null) return null;
    
    final doc = await _firestore.collection('settings').doc(currentUserId).get();
    if (!doc.exists) return null;
    
    final data = doc.data()!;
    // Validate ttsLanguage - if it's ceb or pam (removed languages), use 'en'
    final savedLanguage = data['tts_language'] ?? 'en';
    final validLanguage = (savedLanguage == 'en' || savedLanguage == 'tl') 
        ? savedLanguage 
        : 'en';
    
    return app_settings.Settings(
      settingsId: data['settings_id'] ?? currentUserId!,
      userId: data['user_id'] ?? currentUserId!,
      ttsLanguage: validLanguage,
      ttsRate: data['tts_rate'] ?? 0.5,
      ttsVoice: data['tts_voice'] ?? 'default',
      audioVolume: data['audio_volume'] ?? 50,
      beepVolume: data['beep_volume'] ?? 50,
      hazardConfidenceThreshold: (data['hazard_confidence_threshold'] ?? 0.7).toDouble(),
      detectionMode: data['detection_mode'] ?? 'hazard',
      verbosityLevel: data['verbosity_level'] ?? 'normal',
      emergencyContactsEnabled: data['emergency_contacts_enabled'] ?? true,
      locationSharingEnabled: data['location_sharing_enabled'] ?? true,
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate(),
    );
  }

  // ========== DEVICE OPERATIONS ==========
  
  /// Save device information
  Future<void> saveDevice({
    required String deviceName,
    required String bleMacAddress,
    int? batteryLevel,
    String? firmwareVersion,
    String? deviceType,
  }) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    
    final deviceId = _firestore.collection('devices').doc().id;
    await _firestore.collection('devices').doc(deviceId).set({
      'device_id': deviceId,
      'user_id': currentUserId,
      'device_name': deviceName,
      'ble_mac_address': bleMacAddress,
      'device_type': deviceType ?? 'smart_glasses',
      'battery_level': batteryLevel,
      'firmware_version': firmwareVersion,
      'last_seen': FieldValue.serverTimestamp(),
      'paired_at': FieldValue.serverTimestamp(),
    });
  }

  /// Get user's devices
  Future<List<Map<String, dynamic>>> getUserDevices() async {
    if (currentUserId == null) return [];
    
    final snapshot = await _firestore
        .collection('devices')
        .where('user_id', isEqualTo: currentUserId)
        .get();
    
    return snapshot.docs.map((doc) => {
      'device_id': doc.id,
      ...doc.data(),
    }).toList();
  }

  /// Update device battery level
  Future<void> updateDeviceBattery(String deviceId, int batteryLevel) async {
    await _firestore.collection('devices').doc(deviceId).update({
      'battery_level': batteryLevel,
      'last_seen': FieldValue.serverTimestamp(),
    });
  }

  // ========== LOCATION OPERATIONS ==========
  
  /// Save user location
  Future<void> saveLocation({
    required double latitude,
    required double longitude,
    double? accuracy,
    String? address,
    String? landmark,
  }) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    
    final locationId = _firestore.collection('locations').doc().id;
    await _firestore.collection('locations').doc(locationId).set({
      'location_id': locationId,
      'user_id': currentUserId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'altitude': 0.0,
      'address': address,
      'landmark': landmark,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // ========== DETECTION EVENT OPERATIONS ==========
  
  /// Log a detection event (hazard, OCR, currency, etc.)
  Future<void> logDetectionEvent({
    required String eventType,
    required double confidence,
    String? detectedLabel,
    String? detectedValue,
    String? imageReference,
    String? locationId,
    String? deviceId,
  }) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    
    final eventId = _firestore.collection('detection_events').doc().id;
    await _firestore.collection('detection_events').doc(eventId).set({
      'event_id': eventId,
      'user_id': currentUserId,
      'device_id': deviceId,
      'event_type': eventType, // 'hazard', 'ocr', 'currency', 'scene_narration'
      'confidence': confidence,
      'detected_label': detectedLabel,
      'detected_value': detectedValue,
      'image_reference': imageReference,
      'location_id': locationId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // ========== GUARDIAN OPERATIONS ==========
  
  /// Link a guardian to the current user
  Future<void> linkGuardian({
    required String guardianEmail,
    required String guardianName,
    String? phone,
    String relationshipStatus = 'pending',
  }) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    
    // Normalize email to lowercase for consistent matching
    final normalizedEmail = guardianEmail.trim().toLowerCase();
    
    final guardianId = _firestore.collection('guardians').doc().id;
    await _firestore.collection('guardians').doc(guardianId).set({
      'guardian_id': guardianId,
      'user_id': currentUserId,
      'guardian_email': normalizedEmail, // Store normalized email
      'guardian_name': guardianName,
      'phone': phone,
      'relationship_status': relationshipStatus,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  /// Get guardians for current user
  Future<List<Map<String, dynamic>>> getGuardians() async {
    if (currentUserId == null) return [];
    
    final snapshot = await _firestore
        .collection('guardians')
        .where('user_id', isEqualTo: currentUserId)
        .get();
    
    return snapshot.docs.map((doc) => {
      'guardian_id': doc.id,
      ...doc.data(),
    }).toList();
  }

  /// Get users linked to a guardian (by guardian email)
  Future<List<Map<String, dynamic>>> getLinkedUsersForGuardian(String guardianEmail) async {
    if (guardianEmail.isEmpty) {
      print('Guardian email is empty');
      return [];
    }
    
    // Normalize email to lowercase for consistent matching
    final normalizedEmail = guardianEmail.trim().toLowerCase();
    print('=== Searching for linked users ===');
    print('Guardian email: $guardianEmail');
    print('Normalized email: $normalizedEmail');
    
    try {
      final snapshot = await _firestore
          .collection('guardians')
          .where('guardian_email', isEqualTo: normalizedEmail)
          .where('relationship_status', isEqualTo: 'active')
          .get();
      
      print('Query result: Found ${snapshot.docs.length} active guardian links');
      
      if (snapshot.docs.isEmpty) {
        print('No active links found for this guardian');
        return [];
      }
      
      // Get user IDs
      final userIds = snapshot.docs.map((doc) {
        final data = doc.data();
        final userId = data['user_id'] as String?;
        if (userId == null) {
          print('⚠️ Guardian document ${doc.id} has no user_id');
        }
        return userId;
      }).where((id) => id != null).cast<String>().toList();
      
      print('Found ${userIds.length} user IDs to fetch');
      
      // Get user profiles
      final users = <Map<String, dynamic>>[];
      for (final userId in userIds) {
        try {
          final userDoc = await _firestore.collection('users').doc(userId).get();
          if (userDoc.exists) {
            users.add({
              'user_id': userId,
              ...userDoc.data()!,
            });
            print('✓ Added linked user: ${userDoc.data()?['name'] ?? userId}');
          } else {
            print('⚠️ User document not found for userId: $userId');
          }
        } catch (e) {
          print('Error fetching user $userId: $e');
        }
      }
      
      print('=== Returning ${users.length} linked users ===');
      return users;
    } catch (e, stackTrace) {
      print('❌ ERROR in getLinkedUsersForGuardian: $e');
      print('Stack trace: $stackTrace');
      print('This might be a Firestore rules issue. Make sure rules are deployed.');
      rethrow;
    }
  }

  /// Get pending link requests for a guardian
  Future<List<Map<String, dynamic>>> getPendingLinkRequests(String guardianEmail) async {
    if (guardianEmail.isEmpty) {
      print('Guardian email is empty');
      return [];
    }
    
    // Normalize email to lowercase for consistent matching
    final normalizedEmail = guardianEmail.trim().toLowerCase();
    print('=== Searching for pending requests ===');
    print('Guardian email: $guardianEmail');
    print('Normalized email: $normalizedEmail');
    
    try {
      // First try with normalized email (for new records)
      print('Querying guardians collection with normalized email...');
      var snapshot = await _firestore
          .collection('guardians')
          .where('guardian_email', isEqualTo: normalizedEmail)
          .where('relationship_status', isEqualTo: 'pending')
          .get();
      
      print('Query result: Found ${snapshot.docs.length} pending requests with normalized email');
      
      // If no results, try fetching all pending and filtering manually
      // (for old records that might have mixed case email)
      List<QueryDocumentSnapshot> matchingDocs = snapshot.docs;
      
      if (matchingDocs.isEmpty) {
        print('No results with normalized email, trying alternative query...');
        try {
          // Try querying all pending first
          final allPending = await _firestore
              .collection('guardians')
              .where('relationship_status', isEqualTo: 'pending')
              .get();
          
          print('Found ${allPending.docs.length} total pending requests in database');
          
          // Debug: Print all pending emails
          for (final doc in allPending.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final email = data['guardian_email'] as String?;
            print('  - Pending request email: $email (normalized: ${email?.trim().toLowerCase()})');
          }
          
          // Filter by email (case-insensitive)
          matchingDocs = allPending.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final email = data['guardian_email'] as String?;
            if (email == null) return false;
            final emailNormalized = email.trim().toLowerCase();
            final matches = emailNormalized == normalizedEmail;
            if (matches) {
              print('✓ Found matching request! Email: $email, Guardian ID: ${doc.id}');
            }
            return matches;
          }).toList();
          
          print('Filtered to ${matchingDocs.length} matching requests');
        } catch (e) {
          print('Error in alternative query: $e');
          // If query fails, try to read individual documents
          // This is a fallback if rules don't allow queries
          print('Attempting to read guardians collection directly...');
        }
      }
      
      if (matchingDocs.isEmpty) {
        print('⚠️ No matching pending requests found');
        print('Possible reasons:');
        print('  1. Firestore rules not deployed');
        print('  2. Email mismatch (check case sensitivity)');
        print('  3. No pending requests exist for this email');
        return [];
      }
      
      // Get user IDs and link info
      final requests = <Map<String, dynamic>>[];
      for (final doc in matchingDocs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          final userId = data['user_id'] as String?;
          
          if (userId == null) {
            print('⚠️ Guardian document ${doc.id} has no user_id');
            continue;
          }
          
          print('Fetching user profile for userId: $userId');
          final userDoc = await _firestore.collection('users').doc(userId).get();
          
          if (userDoc.exists) {
            requests.add({
              'guardian_id': doc.id,
              'user_id': userId,
              'guardian_name': data['guardian_name'] ?? 'Unknown',
              'created_at': data['created_at'],
              ...userDoc.data()!,
            });
            print('✓ Added request for user: ${userDoc.data()?['name'] ?? userId}');
          } else {
            print('⚠️ User document not found for userId: $userId');
          }
        } catch (e) {
          print('Error processing guardian document ${doc.id}: $e');
        }
      }
      
      print('=== Returning ${requests.length} valid pending requests ===');
      return requests;
    } catch (e, stackTrace) {
      print('❌ ERROR in getPendingLinkRequests: $e');
      print('Stack trace: $stackTrace');
      print('This might be a Firestore rules issue. Make sure rules are deployed.');
      rethrow;
    }
  }

  /// Approve a pending link request
  Future<void> approveLinkRequest(String guardianId) async {
    await _firestore.collection('guardians').doc(guardianId).update({
      'relationship_status': 'active',
      'approved_at': FieldValue.serverTimestamp(),
    });
  }

  /// Delete/unlink a guardian
  Future<void> deleteGuardian(String guardianId) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    
    // Verify the guardian belongs to the current user before deleting
    final doc = await _firestore.collection('guardians').doc(guardianId).get();
    if (!doc.exists) {
      throw Exception('Guardian link not found');
    }
    
    final data = doc.data()!;
    if (data['user_id'] != currentUserId) {
      throw Exception('You can only delete your own guardian links');
    }
    
    await _firestore.collection('guardians').doc(guardianId).delete();
  }

  /// Get latest location for a user
  Future<Map<String, dynamic>?> getLatestUserLocation(String userId) async {
    final snapshot = await _firestore
        .collection('locations')
        .where('user_id', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();
    
    if (snapshot.docs.isEmpty) return null;
    
    return {
      'location_id': snapshot.docs.first.id,
      ...snapshot.docs.first.data(),
    };
  }

  /// Get latest location stream for a user (real-time)
  Stream<DocumentSnapshot?> getLatestUserLocationStream(String userId) {
    return _firestore
        .collection('locations')
        .where('user_id', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty ? snapshot.docs.first : null);
  }

  /// Get alerts for a user
  Future<List<Map<String, dynamic>>> getUserAlerts(String userId) async {
    final snapshot = await _firestore
        .collection('emergency_alerts')
        .where('user_id', isEqualTo: userId)
        .orderBy('triggered_at', descending: true)
        .limit(10)
        .get();
    
    return snapshot.docs.map((doc) => {
      'alert_id': doc.id,
      ...doc.data(),
    }).toList();
  }

  /// Get alerts stream for a user (real-time)
  Stream<QuerySnapshot> getUserAlertsStream(String userId) {
    return _firestore
        .collection('emergency_alerts')
        .where('user_id', isEqualTo: userId)
        .where('guardian_notified', isEqualTo: false)
        .orderBy('triggered_at', descending: true)
        .limit(10)
        .snapshots();
  }

  /// Acknowledge an alert
  Future<void> acknowledgeAlert(String alertId) async {
    await _firestore.collection('emergency_alerts').doc(alertId).update({
      'guardian_notified': true,
      'resolved_at': FieldValue.serverTimestamp(),
    });
  }

  /// Get device status for a user
  Future<Map<String, dynamic>?> getUserDeviceStatus(String userId) async {
    final snapshot = await _firestore
        .collection('devices')
        .where('user_id', isEqualTo: userId)
        .limit(1)
        .get();
    
    if (snapshot.docs.isEmpty) return null;
    
    return {
      'device_id': snapshot.docs.first.id,
      ...snapshot.docs.first.data(),
    };
  }

  /// Get device status stream for a user (real-time)
  Stream<DocumentSnapshot?> getUserDeviceStatusStream(String userId) {
    return _firestore
        .collection('devices')
        .where('user_id', isEqualTo: userId)
        .limit(1)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty ? snapshot.docs.first : null);
  }

  /// Get latest detection event for a user
  Future<Map<String, dynamic>?> getLatestDetectionEvent(String userId) async {
    final snapshot = await _firestore
        .collection('detection_events')
        .where('user_id', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();
    
    if (snapshot.docs.isEmpty) return null;
    
    return {
      'event_id': snapshot.docs.first.id,
      ...snapshot.docs.first.data(),
    };
  }

  /// Send message from guardian to user
  Future<void> sendMessageToUser({
    required String userId,
    required String messageType,
    required String content,
  }) async {
    if (currentUserId == null) throw Exception('Guardian not authenticated');
    
    // Find guardian ID by email
    final user = _auth.currentUser;
    if (user?.email == null) throw Exception('Guardian email not found');
    
    // Normalize email to lowercase for consistent matching
    final normalizedEmail = user!.email!.trim().toLowerCase();
    
    final guardiansSnapshot = await _firestore
        .collection('guardians')
        .where('guardian_email', isEqualTo: normalizedEmail)
        .where('user_id', isEqualTo: userId)
        .limit(1)
        .get();
    
    if (guardiansSnapshot.docs.isEmpty) {
      throw Exception('Guardian not linked to this user');
    }
    
    final guardianId = guardiansSnapshot.docs.first.id;
    
    final messageId = _firestore.collection('messages').doc().id;
    await _firestore.collection('messages').doc(messageId).set({
      'message_id': messageId,
      'user_id': userId,
      'guardian_id': guardianId,
      'message_type': messageType,
      'content': content,
      'direction': 'guardian_to_user',
      'is_read': false,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  // ========== MESSAGE OPERATIONS ==========
  
  /// Send a message between user and guardian
  Future<void> sendMessage({
    required String guardianId,
    required String messageType,
    required String content,
    required String direction,
  }) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    
    final messageId = _firestore.collection('messages').doc().id;
    await _firestore.collection('messages').doc(messageId).set({
      'message_id': messageId,
      'user_id': currentUserId,
      'guardian_id': guardianId,
      'message_type': messageType, // 'voice', 'text', 'alert'
      'content': content,
      'direction': direction, // 'guardian_to_user', 'user_to_guardian'
      'is_read': false,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  /// Get messages for current user
  Stream<QuerySnapshot> getMessagesStream() {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }
    
    return _firestore
        .collection('messages')
        .where('user_id', isEqualTo: currentUserId)
        .orderBy('created_at', descending: true)
        .limit(50)
        .snapshots();
  }

  /// Mark a message as read
  Future<void> markMessageAsRead(String messageId) async {
    await _firestore
        .collection('messages')
        .doc(messageId)
        .update({'is_read': true});
  }

  // ========== EMERGENCY ALERT OPERATIONS ==========
  
  /// Create an emergency alert
  Future<void> createEmergencyAlert({
    required String alertType,
    required String severity,
    String? locationId,
  }) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    
    final alertId = _firestore.collection('emergency_alerts').doc().id;
    await _firestore.collection('emergency_alerts').doc(alertId).set({
      'alert_id': alertId,
      'user_id': currentUserId,
      'alert_type': alertType, // 'manual', 'battery_low', 'device_disconnect'
      'severity': severity, // 'low', 'medium', 'high', 'critical'
      'location_id': locationId,
      'sms_sent': false,
      'guardian_notified': false,
      'triggered_at': FieldValue.serverTimestamp(),
    });
  }

  /// Helper to delete query results in batches to avoid timeouts
  Future<void> _deleteQueryBatch(Query query, {int batchSize = 50}) async {
    QuerySnapshot snapshot;
    do {
      snapshot = await query.limit(batchSize).get();
      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } while (snapshot.docs.length == batchSize);
  }
}

