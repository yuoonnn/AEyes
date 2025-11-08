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
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// === Your services ===
import 'services/bluetooth_service.dart';
import 'services/openai_service.dart';
import 'services/language_service.dart';

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

  // Initialize your services here
  final bluetoothService = BluetoothService();
  final openAIService = OpenAIService(
    "", // TODO: replace with env var
  );

  final languageService = LanguageService();

  runApp(
    ChangeNotifierProvider.value(
      value: languageService,
      child: MyApp(bluetoothService: bluetoothService, openAIService: openAIService),
    ),
  );
}

class MyApp extends StatelessWidget {
  final BluetoothService bluetoothService;
  final OpenAIService openAIService;

  const MyApp({
    super.key,
    required this.bluetoothService,
    required this.openAIService,
  });

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
              supportedLocales: const [
                Locale('en'),
                Locale('tl'),
              ],
              localeResolutionCallback: (locale, supportedLocales) {
                // Always validate appLocale first - ensure it's supported
                final appLocaleCode = appLocale.languageCode;
                final isAppLocaleSupported = supportedLocales.any(
                  (l) => l.languageCode == appLocaleCode
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
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
                brightness: Brightness.light,
              ),
              darkTheme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.deepPurple,
                  brightness: Brightness.dark,
                ),
                brightness: Brightness.dark,
              ),
              themeMode: themeMode,
              initialRoute: '/',
              routes: {
                '/': (context) => const RoleSelectionScreen(),
                '/login': (context) => const LoginScreen(),
                '/home': (context) => HomeScreen(
                  bluetoothService: bluetoothService,
                  openAIService: openAIService,
                ),
                '/settings': (context) => const SettingsScreen(),
                '/profile': (context) => const ProfileScreen(),
                '/bluetooth': (context) => BluetoothScreen(
                  bluetoothService: bluetoothService,
                  openAIService: openAIService,
                ),
                '/register': (context) => const RegistrationScreen(),
                '/guardian_login': (context) => const GuardianLoginScreen(),
                '/guardian_register': (context) => const GuardianRegistrationScreen(),
                '/guardian_dashboard': (context) => const GuardianDashboardScreen(),
                '/map': (context) {
                  final args = ModalRoute.of(context)?.settings.arguments;
                  final userId = args is String ? args : null;
                  return MapScreen(userId: userId);
                },
              },
            );
          },
        );
      },
    );
  }
}
