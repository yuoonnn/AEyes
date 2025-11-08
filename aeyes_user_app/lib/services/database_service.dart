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
    return app_settings.Settings(
      settingsId: data['settings_id'] ?? currentUserId!,
      userId: data['user_id'] ?? currentUserId!,
      ttsLanguage: data['tts_language'] ?? 'en',
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
  }) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    
    final deviceId = _firestore.collection('devices').doc().id;
    await _firestore.collection('devices').doc(deviceId).set({
      'device_id': deviceId,
      'user_id': currentUserId,
      'device_name': deviceName,
      'ble_mac_address': bleMacAddress,
      'device_type': 'smart_glasses',
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
    
    final guardianId = _firestore.collection('guardians').doc().id;
    await _firestore.collection('guardians').doc(guardianId).set({
      'guardian_id': guardianId,
      'user_id': currentUserId,
      'guardian_email': guardianEmail,
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
}

