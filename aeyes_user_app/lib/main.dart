import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/bluetooth_screen.dart';
import 'screens/registration_screen.dart';
import 'screens/role_selection_screen.dart';
import 'screens/guardian_login_screen.dart';
import 'screens/guardian_dashboard_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// === Your services ===
import 'services/bluetooth_service.dart';
import 'services/openai_service.dart';

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

  runApp(
    MyApp(bluetoothService: bluetoothService, openAIService: openAIService),
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
        return MaterialApp(
          title: 'AEyes User App',
          debugShowCheckedModeBanner: false,
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
            '/guardian_dashboard': (context) => const GuardianDashboardScreen(),
          },
        );
      },
    );
  }
}
