// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:aeyes_user_app/main.dart';
import 'package:aeyes_user_app/services/bluetooth_service.dart';
import 'package:aeyes_user_app/services/openai_service.dart';
import 'package:aeyes_user_app/services/language_service.dart';
import 'package:aeyes_user_app/services/tts_service.dart';

void main() {
  testWidgets('App starts and shows role selection screen', (WidgetTester tester) async {
    // Create mock services
    final bluetoothService = AppBluetoothService();
    final openAIService = OpenAIService("");
    final languageService = LanguageService();
    final ttsService = TTSService();

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: languageService,
        child: MyApp(
          bluetoothService: bluetoothService,
          openAIService: openAIService,
          speechService: null, // Optional for tests
          ttsService: ttsService,
        ),
      ),
    );

    // Wait for the app to initialize
    await tester.pumpAndSettle();

    // Verify that the role selection screen is shown
    expect(find.text('Who are you?'), findsOneWidget);
    expect(find.text('User'), findsOneWidget);
    expect(find.text('Guardian'), findsOneWidget);
  });
}
