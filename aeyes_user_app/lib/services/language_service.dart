import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService extends ChangeNotifier {
  static const String _languageKey = 'selected_language';
  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  LanguageService() {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(_languageKey) ?? 'en';
    
    // Validate that the saved language is still supported
    // If user previously had ceb or pam, fallback to English
    final supportedCodes = supportedLocales.map((l) => l.languageCode).toList();
    final validCode = supportedCodes.contains(languageCode) ? languageCode : 'en';
    
    _locale = Locale(validCode);
    
    // If we had to change the language, save the corrected value
    if (validCode != languageCode) {
      await prefs.setString(_languageKey, validCode);
    }
    
    notifyListeners();
  }

  Future<void> setLanguage(Locale locale) async {
    // Validate that the locale is supported
    final supportedCodes = supportedLocales.map((l) => l.languageCode).toList();
    if (!supportedCodes.contains(locale.languageCode)) {
      // If invalid locale (like ceb or pam), use English instead
      _locale = const Locale('en');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, 'en');
      notifyListeners();
      return;
    }
    
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, locale.languageCode);
    notifyListeners();
  }

  // Language display names
  static const Map<String, String> languageNames = {
    'en': 'English',
    'tl': 'Tagalog',
  };

  static List<Locale> get supportedLocales => [
    const Locale('en'),
    const Locale('tl'),
  ];
}

