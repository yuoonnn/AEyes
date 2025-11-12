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
import 'services/ai_state.dart';
import 'services/tts_service.dart';
import 'services/speech_service.dart';
import 'services/database_service.dart';
import 'services/media_control_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  // Start lightweight foreground service on Android to keep BLE alive
  await ForegroundServiceController.initialize();
  await ForegroundServiceController.startIfNeeded();
  await NotificationService.initialize();

  // Initialize your services here
  final bluetoothService =
      AppBluetoothService(); // Changed to AppBluetoothService
  // Read OpenAI API key from a secure runtime define (never commit keys)
  const openAiKey = String.fromEnvironment('OPENAI_API_KEY', defaultValue: '');
  final openAIService = OpenAIService(openAiKey);

  final languageService = LanguageService();
  final aiState = AIState();
  final ttsService = TTSService();

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

  // Handle button press events from ESP32 - route media controls
  bluetoothService.onButtonPressed = (String buttonData) {
    bluetoothService.log('🎮 Button pressed: $buttonData');

    // Check if this is a media control button (buttons 4, 5, or 6)
    if (buttonData.contains(':')) {
      final parts = buttonData.split(':');
      if (parts.length >= 2) {
        final buttonId = parts[0];

        // Buttons 4, 5, 6 are media controls
        if (buttonId == '4' || buttonId == '5' || buttonId == '6') {
          MediaControlService.handleButtonEvent(buttonData);
        } else {
          bluetoothService.log('📱 Non-media button: $buttonData');
        }
      }
    }
  };

  // Global handler: analyze incoming images with voice command if available
  bluetoothService.onImageReceived = (Uint8List bytes) async {
    bluetoothService.log(
      '🖼️ (global) onImageReceived (${bytes.length} bytes) → OpenAI',
    );

    // Check if we have a recent voice command (within last 5 seconds)
    String? voicePrompt;
    if (_pendingVoiceCommand != null &&
        _voiceCommandTimestamp != null &&
        DateTime.now().difference(_voiceCommandTimestamp!).inSeconds < 5) {
      voicePrompt = _pendingVoiceCommand;
      bluetoothService.log('🎤 Using voice command as prompt: "$voicePrompt"');
      // Clear the pending command after using it
      _pendingVoiceCommand = null;
      _voiceCommandTimestamp = null;
    }

    try {
      final text = await openAIService.analyzeImage(bytes, prompt: voicePrompt);
      aiState.setAnalysis(text);
      NotificationService.showSimple(
        id: 1001,
        title: 'AI Analysis',
        body: text.length > 100 ? '${text.substring(0, 100)}…' : text,
      );
      // Auto TTS the analysis
      try {
        await ttsService.stop();
        await ttsService.speak(text);
      } catch (_) {}
    } catch (e) {
      bluetoothService.log('❌ Global analysis error: $e');
    }
  };

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: languageService),
        ChangeNotifierProvider.value(value: aiState),
      ],
      child: MyApp(
        bluetoothService: bluetoothService,
        openAIService: openAIService,
        speechService: speechService,
        ttsService: ttsService,
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final AppBluetoothService bluetoothService; // Changed to AppBluetoothService
  final OpenAIService openAIService;
  final SpeechService? speechService; // Optional due to plugin compatibility
  final TTSService ttsService;

  const MyApp({
    super.key,
    required this.bluetoothService,
    required this.openAIService,
    this.speechService, // Made optional
    required this.ttsService,
  });

  static DateTime? _lastMessageSeenAt;

  void _startGuardianMessageListener() {
    // Listen to messages for local notifications
    final db = DatabaseService();
    try {
      db.getMessagesStream().listen((snapshot) {
        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['direction'] == 'guardian_to_user') {
            final ts = data['created_at'];
            final createdAt = ts is Timestamp ? ts.toDate() : DateTime.now();
            if (_lastMessageSeenAt == null ||
                createdAt.isAfter(_lastMessageSeenAt!)) {
              _lastMessageSeenAt = createdAt;
              final content = (data['content'] as String?) ?? 'New message';
              NotificationService.showSimple(
                id: 2001,
                title: 'Guardian message',
                body: content.length > 100
                    ? '${content.substring(0, 100)}…'
                    : content,
              );
            }
          }
        }
      });
    } catch (_) {
      // ignore
    }
  }

  // Global theme mode notifier
  static final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(
    ThemeMode.light,
  );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, _) {
        return Consumer<LanguageService>(
          builder: (context, languageService, _) {
            final appLocale = languageService.locale;

            // Start guardian message listener to show notifications
            _startGuardianMessageListener();

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
              initialRoute: '/',
              routes: {
                '/': (context) => const RoleSelectionScreen(),
                '/login': (context) => const LoginScreen(),
                '/home': (context) => HomeScreen(
                  bluetoothService: bluetoothService,
                  openAIService: openAIService,
                  speechService: speechService,
                  ttsService: ttsService,
                ),
                '/analysis': (context) => const AnalysisScreen(),
                '/settings': (context) => const SettingsScreen(),
                '/profile': (context) => const ProfileScreen(),
                '/bluetooth': (context) => BluetoothScreen(
                  bluetoothService: bluetoothService,
                  openAIService: openAIService,
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
