class Settings {
  final String settingsId;
  final String userId;
  final String ttsLanguage; // Language code (en, tl, ceb, pam)
  final double ttsRate; // 0.0 to 1.0
  final String ttsVoice;
  final int audioVolume; // 0 to 100 (TTS Volume)
  final int beepVolume; // 0 to 100 (Beep Volume for bone conduction speaker)
  final double hazardConfidenceThreshold; // 0.0 to 1.0
  final String detectionMode; // 'hazard', 'ocr', 'currency', 'navigation'
  final String verbosityLevel; // 'minimal', 'normal', 'detailed'
  final bool emergencyContactsEnabled;
  final bool locationSharingEnabled;
  final DateTime? updatedAt;

  Settings({
    required this.settingsId,
    required this.userId,
    this.ttsLanguage = 'en',
    this.ttsRate = 0.5,
    this.ttsVoice = 'default',
    this.audioVolume = 50,
    this.beepVolume = 50,
    this.hazardConfidenceThreshold = 0.7,
    this.detectionMode = 'hazard',
    this.verbosityLevel = 'normal',
    this.emergencyContactsEnabled = true,
    this.locationSharingEnabled = true,
    this.updatedAt,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'settings_id': settingsId,
      'user_id': userId,
      'tts_language': ttsLanguage,
      'tts_rate': ttsRate,
      'tts_voice': ttsVoice,
      'audio_volume': audioVolume,
      'beep_volume': beepVolume,
      'hazard_confidence_threshold': hazardConfidenceThreshold,
      'detection_mode': detectionMode,
      'verbosity_level': verbosityLevel,
      'emergency_contacts_enabled': emergencyContactsEnabled,
      'location_sharing_enabled': locationSharingEnabled,
      'updated_at': updatedAt,
    };
  }

  // Create from Firestore document
  factory Settings.fromMap(Map<String, dynamic> map) {
    return Settings(
      settingsId: map['settings_id'] ?? '',
      userId: map['user_id'] ?? '',
      ttsLanguage: map['tts_language'] ?? 'en',
      ttsRate: (map['tts_rate'] ?? 0.5).toDouble(),
      ttsVoice: map['tts_voice'] ?? 'default',
      audioVolume: map['audio_volume'] ?? 50,
      beepVolume: map['beep_volume'] ?? 50,
      hazardConfidenceThreshold: (map['hazard_confidence_threshold'] ?? 0.7).toDouble(),
      detectionMode: map['detection_mode'] ?? 'hazard',
      verbosityLevel: map['verbosity_level'] ?? 'normal',
      emergencyContactsEnabled: map['emergency_contacts_enabled'] ?? true,
      locationSharingEnabled: map['location_sharing_enabled'] ?? true,
      updatedAt: map['updated_at']?.toDate(),
    );
  }

  // Copy with method for updates
  Settings copyWith({
    String? ttsLanguage,
    double? ttsRate,
    String? ttsVoice,
    int? audioVolume,
    int? beepVolume,
    double? hazardConfidenceThreshold,
    String? detectionMode,
    String? verbosityLevel,
    bool? emergencyContactsEnabled,
    bool? locationSharingEnabled,
  }) {
    return Settings(
      settingsId: settingsId,
      userId: userId,
      ttsLanguage: ttsLanguage ?? this.ttsLanguage,
      ttsRate: ttsRate ?? this.ttsRate,
      ttsVoice: ttsVoice ?? this.ttsVoice,
      audioVolume: audioVolume ?? this.audioVolume,
      beepVolume: beepVolume ?? this.beepVolume,
      hazardConfidenceThreshold: hazardConfidenceThreshold ?? this.hazardConfidenceThreshold,
      detectionMode: detectionMode ?? this.detectionMode,
      verbosityLevel: verbosityLevel ?? this.verbosityLevel,
      emergencyContactsEnabled: emergencyContactsEnabled ?? this.emergencyContactsEnabled,
      locationSharingEnabled: locationSharingEnabled ?? this.locationSharingEnabled,
      updatedAt: DateTime.now(),
    );
  }
} 