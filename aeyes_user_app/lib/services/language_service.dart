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
    _locale = Locale(languageCode);
    notifyListeners();
  }

  Future<void> setLanguage(Locale locale) async {
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, locale.languageCode);
    notifyListeners();
  }

  // Language display names
  static const Map<String, String> languageNames = {
    'en': 'English',
    'tl': 'Tagalog',
    'ceb': 'Bisaya',
    'pam': 'Kapampangan',
  };

  static List<Locale> get supportedLocales => [
    const Locale('en'),
    const Locale('tl'),
    const Locale('ceb'),
    const Locale('pam'),
  ];
}

