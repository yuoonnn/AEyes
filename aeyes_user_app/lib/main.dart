import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:aeyes_user_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/bluetooth_screen.dart';
import 'screens/registration_screen.dart';
import 'screens/role_selection_screen.dart';
import 'screens/guardian_login_screen.dart';
import 'screens/guardian_dashboard_screen.dart';
import 'screens/guardian_registration_screen.dart';
import 'screens/map_screen.dart';
import 'screens/messages_screen.dart';
import 'screens/analysis_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';

// === Your services ===
import 'services/bluetooth_service.dart';
import 'services/openai_service.dart';
import 'services/language_service.dart';
import 'services/foreground_service.dart';
import 'services/notification_service.dart';
import 'services/latency_metrics_service.dart';
import 'services/ai_state.dart';
import 'services/tts_service.dart';
import 'services/speech_service.dart';
import 'services/database_service.dart';
import 'services/media_control_service.dart';
import 'services/sms_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'models/user.dart' as app_user;

// === Theme ===
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyAmlXAdNn73AOONhdd_2_-8psU2hFlYHJs",
        authDomain: "aeyes-project.firebaseapp.com",
        projectId: "aeyes-project",
        storageBucket: "aeyes-project.appspot.com",
        messagingSenderId: "821129436645",
        appId: "1:821129436645:web:d2922d6aa067a97127230c",
        measurementId: "G-20DH2K3GD5",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  // Initialize notification service first
  await NotificationService.initialize();

  // Initialize foreground service (but don't start it yet - will start after permissions are granted)
  await ForegroundServiceController.initialize();

  // Initialize your services here
  final bluetoothService =
      AppBluetoothService(); // Changed to AppBluetoothService
  // Read OpenAI API key from a secure runtime define (never commit keys)
  const openAiKey = String.fromEnvironment(
    'OPENAI_API_KEY',
    defaultValue:
        '',
  );
  final openAIService = OpenAIService(openAiKey);

  final languageService = LanguageService();
  final aiState = AIState();
  final ttsService = TTSService();
  final latencyService = LatencyMetricsService.instance;

  // Speech service - for recording audio when ESP32 button is pressed
  SpeechService? speechService;
  try {
    final service = SpeechService(openAIService: openAIService);
    await service.initialize();
    speechService = service;
    print('✅ Speech service initialized (audio recording ready)');
  } catch (e) {
    print('⚠️ Speech service initialization failed: $e');
    print('⚠️ Voice control will be disabled');
    speechService = null;
  }

  // Auto-connect to previously used device when detected nearby
  await bluetoothService.enableAutoConnect(true);

  // Initialize media control service
  await MediaControlService.initialize();
  final hasMediaPermission = await MediaControlService.hasPermission();
  if (!hasMediaPermission) {
    bluetoothService.log(
      '⚠️ Media controls need notification access. Open Settings > Notifications > Notification Access and enable AEyes.',
    );
  }

  // Store pending voice command from ESP32 to pair with next image
  String? _pendingVoiceCommand;
  DateTime? _voiceCommandTimestamp;

  // Handle voice commands from ESP32 - store for pairing with next image
  bluetoothService.onVoiceCommandText = (String command) {
    _pendingVoiceCommand = command.trim();
    _voiceCommandTimestamp = DateTime.now();
    bluetoothService.log(
      '🎤 Voice command stored: "$command" (waiting for image)',
    );
  };

  // Handle recording commands from ESP32 button
  bluetoothService.onRecordingCommand = (String command) async {
    if (speechService == null) {
      bluetoothService.log('❌ Speech service not available');
      return;
    }

    if (command == 'START_RECORDING') {
      bluetoothService.log('🎤 Starting recording (ESP32 button pressed)');
      // Provide TTS feedback for blind users
      try {
        await ttsService.stop(); // Stop any ongoing TTS first
        await ttsService.speak('Recording');
      } catch (e) {
        bluetoothService.log('⚠️ TTS feedback failed: $e');
      }
      await speechService.startRecording();
    } else if (command == 'STOP_RECORDING') {
      bluetoothService.log('🎤 Stopping recording (ESP32 button released)');
      final voiceText = await speechService.stopRecording();

      if (voiceText != null && voiceText.isNotEmpty) {
        // Store the voice command for pairing with next image
        _pendingVoiceCommand = voiceText.trim();
        _voiceCommandTimestamp = DateTime.now();
        bluetoothService.log(
          '🎤 Voice command recorded: "$voiceText" (waiting for image)',
        );

        // Tell ESP32 that transcription is complete and it can capture the image
        try {
          await bluetoothService.requestImageCapture();
          bluetoothService.log(
            '📸 Requested image capture after voice transcription',
          );
        } catch (e) {
          bluetoothService.log('❌ Failed to request image capture: $e');
        }
      } else {
        bluetoothService.log('⚠️ No voice text extracted from recording');
        // Still request image even if transcription failed
        try {
          await bluetoothService.requestImageCapture();
        } catch (e) {
          bluetoothService.log('❌ Failed to request image capture: $e');
        }
      }
    }
  };

  // Global function to send predefined alert with TTS feedback
  Future<void> _sendEmergencyAlertGlobal(TTSService? ttsService) async {
    try {
      final smsService = SMSService();
      // Get single predefined message
      final message = await smsService.getPredefinedMessage();

      if (message.isEmpty) {
        if (ttsService != null) {
          await ttsService.speak(
            'No predefined message found. Please set a message in Settings.',
          );
        }
        return;
      }

      // Send alert to all guardians automatically
      final results = await smsService.sendSMSToAllGuardians(message);

      // Remove summary from results for counting
      results.remove('_summary');
      final totalCount = results.length;

      if (totalCount == 0) {
        // No guardians at all
        if (ttsService != null) {
          await ttsService.speak('No guardians found');
        }
      } else {
        // Use TTS to announce success - simplified message for user
        if (ttsService != null) {
          await ttsService.speak('Alert sent');
        }
      }
    } catch (e) {
      print('Error sending predefined alert: $e');
      if (ttsService != null) {
        try {
          await ttsService.speak('Error sending alert');
        } catch (ttsError) {
          print('TTS error: $ttsError');
        }
      }
    }
  }

  // Global button press handler - works across all screens
  // This ensures TTS announcements work regardless of which screen is active
  bluetoothService.onButtonPressed = (String buttonData) async {
    bluetoothService.log('🎮 Button pressed: $buttonData');

    // Parse button data - format can be "buttonId" or "buttonId:event"
    final trimmed = buttonData.trim();
    String buttonId;
    String? event;

    if (trimmed.contains(':')) {
      final parts = trimmed.split(':');
      buttonId = parts[0].trim();
      event = parts.length > 1 ? parts[1].trim() : null;
    } else {
      buttonId = trimmed;
      event = null;
    }

    // Handle media control buttons (4, 5, 6) - route to media control service
    if (buttonId == '4' || buttonId == '5' || buttonId == '6') {
      MediaControlService.handleButtonEvent(buttonData);
      return;
    }

    // Handle other buttons with TTS announcements
    switch (buttonId) {
      case '0':
      case 'capture':
        // Trigger image capture/analysis
        latencyService.startCycle(
          triggerLabel: 'Button $buttonId${event != null ? ' ($event)' : ''}',
        );
        if (ttsService != null) {
          try {
            await ttsService.stop(); // Stop any ongoing TTS first
            await ttsService.speak('Capturing image');
          } catch (e) {
            print('⚠️ TTS feedback failed: $e');
          }
        }
        break;

      case '1':
      case 'help':
        // Button 1: Automatically send predefined alert to guardians
        // Only trigger on short press, not on long press (power on/off)
        if (event == null || event == 'POWER_SHORT') {
          await _sendEmergencyAlertGlobal(ttsService);
        } else if (event == 'POWER_LONG') {
          // Long press is for power on/off, don't trigger alert
          bluetoothService.log('Button 1 long press (power) - ignoring');
        }
        break;

      case '2':
        // Button 2: Capture / Auto-scan toggle
        if (event == 'CAPTURE') {
          // Short press: Request image capture
          latencyService.startCycle(
            triggerLabel: 'Button $buttonId ($event)',
          );
          if (ttsService != null) {
            try {
              await ttsService.stop(); // Stop any ongoing TTS first
              await ttsService.speak('Capturing image');
            } catch (e) {
              print('⚠️ TTS feedback failed: $e');
            }
          }
        } else if (event == 'AUTO_ON') {
          // Long press: Auto-capture enabled
          if (ttsService != null) {
            try {
              await ttsService.speak('Auto capture enabled');
            } catch (e) {
              print('⚠️ TTS feedback failed: $e');
            }
          }
        } else if (event == 'AUTO_OFF') {
          // Long press: Auto-capture disabled
          if (ttsService != null) {
            try {
              await ttsService.speak('Auto capture disabled');
            } catch (e) {
              print('⚠️ TTS feedback failed: $e');
            }
          }
        }
        break;

      default:
        bluetoothService.log('📱 Unhandled button: $buttonData');
    }
  };

  // Global handler: analyze incoming images with voice command if available
  bluetoothService.onImageReceived = (Uint8List bytes) async {
    bluetoothService.log(
      '🖼️ (global) onImageReceived (${bytes.length} bytes) → OpenAI',
    );
    latencyService.markImageReceived(byteLength: bytes.length);

    // Check if we have a recent voice command (within last 5 seconds)
    String? voicePrompt;
    if (_pendingVoiceCommand != null &&
        _voiceCommandTimestamp != null &&
        DateTime.now().difference(_voiceCommandTimestamp!).inSeconds < 5) {
      // Check if this is a location command (should NOT go to OpenAI)
      if (_pendingVoiceCommand != null) {
        final lowerCommand = _pendingVoiceCommand!.toLowerCase().trim();
        final isLocationCommand =
            lowerCommand.contains('find ') ||
            lowerCommand.contains('where is ') ||
            lowerCommand.contains('nearby') ||
            lowerCommand.contains('around me') ||
            lowerCommand.contains('what\'s near') ||
            lowerCommand.contains('my location') ||
            lowerCommand.contains('where am i') ||
            lowerCommand.contains('current location');

        if (isLocationCommand) {
          bluetoothService.log(
            '📍 Location command detected, skipping OpenAI image analysis: "$_pendingVoiceCommand"',
          );
          // Clear the command but don't use it for image analysis
          _pendingVoiceCommand = null;
          _voiceCommandTimestamp = null;
          // Location commands are handled by phone voice service, not OpenAI
          return;
        }
      }

      voicePrompt = _pendingVoiceCommand;
      bluetoothService.log('🎤 Using voice command as prompt: "$voicePrompt"');
      // Clear the pending command after using it
      _pendingVoiceCommand = null;
      _voiceCommandTimestamp = null;
    }

    try {
      final text = await openAIService.analyzeImage(bytes, prompt: voicePrompt);
      latencyService.markAnalysisComplete();
      aiState.setAnalysis(text);
      NotificationService.showSimple(
        id: 1001,
        title: 'AI Analysis',
        body: text.length > 100 ? '${text.substring(0, 100)}…' : text,
      );
      // Auto TTS the analysis
      try {
        await ttsService.stop();
        latencyService.markTtsStarted(ttsPreview: text);
        await ttsService.speak(text);
      } catch (_) {}
    } catch (e) {
      bluetoothService.log('❌ Global analysis error: $e');
      latencyService.cancelActive('openai_error');
    }
  };

  final app = MyApp(
    bluetoothService: bluetoothService,
    openAIService: openAIService,
    speechService: speechService,
    ttsService: ttsService,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: languageService),
        ChangeNotifierProvider.value(value: aiState),
      ],
      child: app,
    ),
  );

  // Start guardian message listener after app is initialized
  // This ensures it works even when app is in background
  Future.delayed(const Duration(seconds: 1), () {
    app.startGuardianMessageListener();
  });
}

/// Wrapper widget that checks authentication state and routes accordingly
/// This ensures users stay logged in after closing the app
class _AuthWrapper extends StatelessWidget {
  final AppBluetoothService bluetoothService;
  final OpenAIService openAIService;
  final SpeechService? speechService;
  final TTSService ttsService;

  const _AuthWrapper({
    required this.bluetoothService,
    required this.openAIService,
    this.speechService,
    required this.ttsService,
  });

  @override
  Widget build(BuildContext context) {
    // Listen to auth state changes - this automatically handles persistence
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/AEye Logo.png', height: 100),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('Loading...'),
                ],
              ),
            ),
          );
        }

        final user = snapshot.data;

        // No user logged in, show role selection
        if (user == null) {
          return const RoleSelectionScreen();
        }

        // User is logged in, check their role and show appropriate screen
        // Use a StatefulWidget to cache the profile check
        return _UserRoleChecker(
          userId: user.uid,
          bluetoothService: bluetoothService,
          openAIService: openAIService,
          speechService: speechService,
          ttsService: ttsService,
        );
      },
    );
  }
}

/// Widget that checks user role and displays appropriate screen
class _UserRoleChecker extends StatefulWidget {
  final String userId;
  final AppBluetoothService bluetoothService;
  final OpenAIService openAIService;
  final SpeechService? speechService;
  final TTSService ttsService;

  const _UserRoleChecker({
    required this.userId,
    required this.bluetoothService,
    required this.openAIService,
    this.speechService,
    required this.ttsService,
  });

  @override
  State<_UserRoleChecker> createState() => _UserRoleCheckerState();
}

class _UserRoleCheckerState extends State<_UserRoleChecker> {
  app_user.User? _cachedProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await DatabaseService().getUserProfile();
      if (mounted) {
        setState(() {
          _cachedProfile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user profile: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/AEye Logo.png', height: 100),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Loading profile...'),
            ],
          ),
        ),
      );
    }

    // Check if user is a guardian
    if (_cachedProfile != null && _cachedProfile!.role == 'guardian') {
      MyApp.of(context)?.startGuardianAlertListener();
      return const GuardianDashboardScreen();
    } else {
      // Regular user - show home screen
      return HomeScreen(
        bluetoothService: widget.bluetoothService,
        openAIService: widget.openAIService,
        speechService: widget.speechService,
        ttsService: widget.ttsService,
      );
    }
  }
}

class MyApp extends StatelessWidget {
  final AppBluetoothService bluetoothService; // Changed to AppBluetoothService
  final OpenAIService openAIService;
  final SpeechService? speechService; // Optional due to plugin compatibility
  final TTSService ttsService;

  static MyApp? _instance;

  MyApp({
    super.key,
    required this.bluetoothService,
    required this.openAIService,
    this.speechService, // Made optional
    required this.ttsService,
  }) {
    _instance = this;
  }

  /// Get the current MyApp instance (for accessing services from widgets)
  static MyApp? of(BuildContext context) {
    return _instance;
  }

  static DateTime? _lastMessageSeenAt;
  static StreamSubscription? _messageStreamSubscription;
  static bool _listenerInitialized = false;
  static StreamSubscription? _guardianAlertSubscription;
  static bool _guardianAlertListenerInitialized = false;
  static DateTime? _lastGuardianAlertAt;
  static final Set<String> _processedGuardianAlertIds = <String>{};

  /// Stop the guardian message listener (call this on logout)
  static void stopGuardianMessageListener() {
    _messageStreamSubscription?.cancel();
    _messageStreamSubscription = null;
    _listenerInitialized = false;
    _lastMessageSeenAt = null;
    print('🛑 Guardian message listener stopped');
  }

  /// Stop guardian alert listener (call when guardian logs out)
  static void stopGuardianAlertListener() {
    _guardianAlertSubscription?.cancel();
    _guardianAlertSubscription = null;
    _guardianAlertListenerInitialized = false;
    _lastGuardianAlertAt = null;
    _processedGuardianAlertIds.clear();
    print('🛑 Guardian alert listener stopped');
  }

  // Make this public so it can be called from main()
  void startGuardianMessageListener() {
    // Only initialize once to avoid multiple listeners
    if (_listenerInitialized && _messageStreamSubscription != null) {
      // Check if user is still authenticated, restart if needed
      final db = DatabaseService();
      if (db.currentUserId == null) {
        _messageStreamSubscription?.cancel();
        _messageStreamSubscription = null;
        _listenerInitialized = false;
      }
      return;
    }

    // Only start listener if user is authenticated
    final db = DatabaseService();
    if (db.currentUserId == null) {
      // User not authenticated, stop any existing listener
      _messageStreamSubscription?.cancel();
      _messageStreamSubscription = null;
      _listenerInitialized = false;
      return;
    }

    // Cancel existing listener if any
    _messageStreamSubscription?.cancel();

    // Listen to messages for local notifications and auto TTS
    try {
      _messageStreamSubscription = db.getMessagesStream().listen(
        (snapshot) {
          _handleNewGuardianMessages(snapshot);
        },
        onError: (error) {
          print('Error in message stream: $error');
          // If error is due to authentication, stop listening
          if (error.toString().contains('not authenticated')) {
            _messageStreamSubscription?.cancel();
            _messageStreamSubscription = null;
            _listenerInitialized = false;
          }
        },
      );

      _listenerInitialized = true;
      print('✅ Guardian message listener started');
    } catch (e) {
      print('Error starting message listener: $e');
      // If error is due to authentication, ignore
      if (e.toString().contains('not authenticated')) {
        _messageStreamSubscription?.cancel();
        _messageStreamSubscription = null;
        _listenerInitialized = false;
      }
    }
  }

  Future<void> startGuardianAlertListener() async {
    if (_guardianAlertListenerInitialized) {
      return;
    }

    final db = DatabaseService();
    List<String> guardianIds;

    try {
      guardianIds = await db.getGuardianLinkIdsForCurrentGuardian();
    } catch (e) {
      print('Error fetching guardian links: $e');
      return;
    }

    if (guardianIds.isEmpty) {
      return;
    }

    final guardianIdSet = guardianIds.toSet();
    _guardianAlertSubscription?.cancel();

    try {
      _guardianAlertSubscription = db.getGuardianMessagesStream().listen(
        (snapshot) {
          _handleGuardianAlerts(snapshot, guardianIdSet);
        },
        onError: (error) {
          print('Error in guardian alert stream: $error');
          stopGuardianAlertListener();
        },
      );

      _guardianAlertListenerInitialized = true;
      _lastGuardianAlertAt ??= DateTime.now();
      print('✅ Guardian alert listener started');
    } catch (e) {
      print('Error starting guardian alert listener: $e');
      stopGuardianAlertListener();
    }
  }

  /// Handle new guardian messages - works in foreground and background
  void _handleNewGuardianMessages(QuerySnapshot snapshot) {
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['direction'] == 'guardian_to_user') {
        final ts = data['created_at'];
        final createdAt = ts is Timestamp ? ts.toDate() : DateTime.now();

        // Only process new messages
        if (_lastMessageSeenAt == null ||
            createdAt.isAfter(_lastMessageSeenAt!)) {
          _lastMessageSeenAt = createdAt;
          final content = (data['content'] as String?) ?? 'New message';

          // Show notification (works in background)
          NotificationService.showSimple(
            id: 2001,
            title: 'Guardian message',
            body: content.length > 100
                ? '${content.substring(0, 100)}…'
                : content,
          );

          // Auto TTS: Automatically play the message via TTS
          // This will work even when app is in background
          _speakGuardianMessage(content);
        }
      }
    }
  }

  /// Speak guardian message via TTS - works in background
  void _speakGuardianMessage(String content) async {
    try {
      // Stop any current TTS first
      await ttsService.stop();

      // Wait a moment for any ongoing audio to stop
      await Future.delayed(const Duration(milliseconds: 300));

      // Speak the message - TTS works in background on Android
      final message = 'Message from guardian: $content';
      await ttsService.speak(message);
      print('🔊 Auto TTS: Playing guardian message (background capable)');
    } catch (e) {
      print('Error in auto TTS: $e');
      // Try again after a delay if it fails
      Future.delayed(const Duration(seconds: 2), () async {
        try {
          await ttsService.speak('Message from guardian: $content');
          print('🔊 Auto TTS: Retry successful');
        } catch (retryError) {
          print('Error in TTS retry: $retryError');
        }
      });
    }
  }

  void _handleGuardianAlerts(QuerySnapshot snapshot, Set<String> guardianIds) {
    if (guardianIds.isEmpty) return;

    for (final doc in snapshot.docs.reversed) {
      if (_processedGuardianAlertIds.contains(doc.id)) {
        continue;
      }

      final data = doc.data() as Map<String, dynamic>;
      final direction = data['direction'] as String? ?? '';
      if (direction != 'user_to_guardian') continue;

      final messageType = data['message_type'] as String? ?? 'text';
      if (messageType != 'alert') continue;

      final guardianId = data['guardian_id'] as String?;
      if (guardianId == null || !guardianIds.contains(guardianId)) continue;

      final ts = data['created_at'];
      final createdAt = ts is Timestamp ? ts.toDate() : DateTime.now();
      if (_lastGuardianAlertAt != null &&
          !createdAt.isAfter(_lastGuardianAlertAt!)) {
        continue;
      }

      _processedGuardianAlertIds.add(doc.id);
      if (_processedGuardianAlertIds.length > 200) {
        _processedGuardianAlertIds.clear();
      }

      _lastGuardianAlertAt = createdAt;

      final content =
          (data['content'] as String?) ?? 'Emergency alert received';
      NotificationService.showSimple(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: 'Emergency alert',
        body: content.length > 100 ? '${content.substring(0, 100)}…' : content,
      );
    }
  }

  // Global theme mode notifier
  static final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(
    ThemeMode.light,
  );

  /// Determine initial route based on authentication state
  /// This ensures users stay logged in after closing the app
  /// Returns a widget that handles async auth check
  Widget _getInitialRoute() {
    return _AuthWrapper(
      bluetoothService: bluetoothService,
      openAIService: openAIService,
      speechService: speechService,
      ttsService: ttsService,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, _) {
        return Consumer<LanguageService>(
          builder: (context, languageService, _) {
            final appLocale = languageService.locale;

            // Start guardian message listener to show notifications and TTS
            // This runs on every build to ensure it's active, but listener is only initialized once
            startGuardianMessageListener();

            return MaterialApp(
              title: 'AEyes User App',
              debugShowCheckedModeBanner: false,
              locale: appLocale,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('en'), Locale('tl')],
              localeResolutionCallback: (locale, supportedLocales) {
                // Always validate appLocale first - ensure it's supported
                final appLocaleCode = appLocale.languageCode;
                final isAppLocaleSupported = supportedLocales.any(
                  (l) => l.languageCode == appLocaleCode,
                );

                // If app locale is not supported (e.g., ceb or pam), use English
                if (!isAppLocaleSupported) {
                  return const Locale('en');
                }

                // If locale is null, use the validated app locale
                if (locale == null) {
                  return appLocale;
                }

                // Check if the locale is supported
                for (var supportedLocale in supportedLocales) {
                  if (supportedLocale.languageCode == locale.languageCode) {
                    return supportedLocale;
                  }
                }

                // Fallback to validated app locale
                return appLocale;
              },
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeMode,
              home: _getInitialRoute(),
              onGenerateRoute: (settings) {
                // Handle '/' route explicitly (for navigation from other screens)
                if (settings.name == '/') {
                  return MaterialPageRoute(
                    builder: (context) => _getInitialRoute(),
                  );
                }
                return null; // Let Flutter handle other routes
              },
              routes: {
                // Note: '/' route is handled by _AuthWrapper (home property) and onGenerateRoute
                '/login': (context) => const LoginScreen(),
                '/home': (context) => HomeScreen(
                  bluetoothService: bluetoothService,
                  openAIService: openAIService,
                  speechService: speechService,
                  ttsService: ttsService,
                ),
                '/analysis': (context) =>
                    AnalysisScreen(ttsService: ttsService),
                '/settings': (context) =>
                    SettingsScreen(ttsService: ttsService),
                '/profile': (context) => ProfileScreen(ttsService: ttsService),
                '/bluetooth': (context) => BluetoothScreen(
                  bluetoothService: bluetoothService,
                  openAIService: openAIService,
                  ttsService: ttsService,
                ),
                '/register': (context) => const RegistrationScreen(),
                '/guardian_login': (context) => const GuardianLoginScreen(),
                '/guardian_register': (context) =>
                    const GuardianRegistrationScreen(),
                '/guardian_dashboard': (context) =>
                    const GuardianDashboardScreen(),
                '/map': (context) {
                  final args = ModalRoute.of(context)?.settings.arguments;
                  final userId = args is String ? args : null;
                  if (userId == null) {
                    // Navigate back if no userId provided
                    Navigator.pop(context);
                    return const SizedBox.shrink();
                  }
                  return MapScreen(userId: userId);
                },
                '/messages': (context) => const MessagesScreen(),
              },
            );
          },
        );
      },
    );
  }
}
