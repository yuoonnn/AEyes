import 'package:flutter/material.dart';
import 'package:aeyes_user_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../widgets/custom_button.dart';
import '../models/settings.dart';
import '../main.dart';
import '../widgets/main_scaffold.dart';
import '../services/button_sound_service.dart';
import '../services/language_service.dart';
import '../services/database_service.dart';
import '../services/tts_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'predefined_messages_screen.dart';

class SettingsScreen extends StatefulWidget {
  final TTSService? ttsService;
  
  const SettingsScreen({Key? key, this.ttsService}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String getSelectedLanguageName(Locale locale) {
    return LanguageService.languageNames[locale.languageCode] ?? 'English';
  }

  final DatabaseService _databaseService = DatabaseService();
  double volume = 0.5;
  double beepVolume = 0.5;
  bool notificationsEnabled = true;
  bool isDarkMode = false;
  String? successMessage;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final settings = await _databaseService.getSettings();
      if (settings != null) {
        final loadedVolume = settings.beepVolume / 100.0;
        setState(() {
          volume = settings.audioVolume / 100.0; // Convert 0-100 to 0.0-1.0
          beepVolume = loadedVolume; // Convert 0-100 to 0.0-1.0
          notificationsEnabled = settings.emergencyContactsEnabled;
          isDarkMode = Theme.of(context).brightness == Brightness.dark;
          isLoading = false;
        });
        ButtonSoundService().setVolume(loadedVolume);
        // Apply TTS volume from settings
        final ttsService = MyApp.of(context)?.ttsService;
        if (ttsService != null) {
          await ttsService.setVolume(volume);
        }
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    final l10n = AppLocalizations.of(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final languageService = Provider.of<LanguageService>(
        context,
        listen: false,
      );
      final currentLanguage = languageService.locale.languageCode;

      final settings = Settings(
        settingsId: user.uid,
        userId: user.uid,
        ttsLanguage: currentLanguage,
        audioVolume: (volume * 100).toInt(), // TTS Volume: 0-100
        beepVolume: (beepVolume * 100).toInt(), // Beep Volume: 0-100
        emergencyContactsEnabled: notificationsEnabled,
        locationSharingEnabled: true, // Default
      );

      await _databaseService.saveSettings(settings);
      ButtonSoundService().setVolume(beepVolume);
      // Apply TTS volume when saving settings
      final ttsService = MyApp.of(context)?.ttsService;
      if (ttsService != null) {
        await ttsService.setVolume(volume);
      }

      setState(() {
        successMessage = l10n?.settingsSaved ?? 'Settings saved';
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n?.settingsSaved ?? 'Settings saved')),
      );
    } catch (e) {
      setState(() {
        isLoading = false;
        successMessage = 'Error: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final languageService = Provider.of<LanguageService>(context);
    final green = const Color(0xFF388E3C);
    final greenAccent = const Color(0xFF66BB6A);

    return MainScaffold(
      currentIndex: 4,
      child: PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          if (!didPop) {
            Navigator.pushReplacementNamed(context, '/home');
          }
        },
        child: Scaffold(
          appBar: AppBar(title: Text(l10n?.settings ?? 'Settings'), elevation: 0),
        body: ListView(
          padding: const EdgeInsets.all(20.0),
          children: [
            // Language Section
            _buildSectionCard(
              context: context,
              title: l10n?.languageAndRegion ?? 'Language & Region',
              icon: Icons.language,
              color: green,
              children: [
                _buildSettingItem(
                  context: context,
                  leading: Icons.translate,
                  title: l10n?.language ?? 'Language',
                  trailing: DropdownButton<Locale>(
                    value: languageService.locale,
                    items: LanguageService.supportedLocales
                        .map(
                          (locale) => DropdownMenuItem(
                            value: locale,
                            child: Text(
                              LanguageService.languageNames[locale
                                      .languageCode] ??
                                  locale.languageCode,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (locale) {
                      if (locale != null) {
                        languageService.setLanguage(locale);
                      }
                    },
                    underline: Container(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Audio Settings Section
            _buildSectionCard(
              context: context,
              title: l10n?.audioSettings ?? 'Audio Settings',
              icon: Icons.volume_up,
              color: greenAccent,
              children: [
                _buildSettingItem(
                  context: context,
                  leading: Icons.volume_up,
                  title: l10n?.ttsVolume ?? 'TTS Volume',
                  subtitle: '${(volume * 100).toInt()}%',
                  trailing: SizedBox(
                    width: 150,
                    child: Slider(
                      value: volume,
                      min: 0,
                      max: 1,
                      divisions: 10,
                      activeColor: greenAccent,
                      onChanged: (val) async {
                        setState(() {
                          volume = val;
                        });
                        // Apply TTS volume immediately when slider changes
                        final ttsService = MyApp.of(context)?.ttsService;
                        if (ttsService != null) {
                          await ttsService.setVolume(val);
                        }
                      },
                    ),
                  ),
                ),
                const Divider(height: 32),
                _buildSettingItem(
                  context: context,
                  leading: Icons.hearing,
                  title: l10n?.beepVolume ?? 'Beep Volume',
                  subtitle:
                      l10n?.boneConductionSpeaker ?? 'Bone Conduction Speaker',
                  trailing: SizedBox(
                    width: 150,
                    child: Slider(
                      value: beepVolume,
                      min: 0,
                      max: 1,
                      divisions: 10,
                      activeColor: greenAccent,
                      onChanged: (val) {
                        setState(() {
                          beepVolume = val;
                        });
                        ButtonSoundService().setVolume(val);
                      },
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // App Preferences Section
            _buildSectionCard(
              context: context,
              title: l10n?.appPreferences ?? 'App Preferences',
              icon: Icons.tune,
              color: green,
              children: [
                _buildSettingItem(
                  context: context,
                  leading: Icons.notifications,
                  title: l10n?.notifications ?? 'Notifications',
                  subtitle:
                      l10n?.enablePushNotifications ??
                      'Enable push notifications',
                  trailing: Switch(
                    value: notificationsEnabled,
                    activeColor: green,
                    onChanged: (val) {
                      setState(() {
                        notificationsEnabled = val;
                      });
                    },
                  ),
                ),
                const Divider(height: 32),
                _buildSettingItem(
                  context: context,
                  leading: isDarkMode ? Icons.dark_mode : Icons.light_mode,
                  title: l10n?.darkMode ?? 'Dark Mode',
                  subtitle:
                      l10n?.switchBetweenThemes ??
                      'Switch between light and dark theme',
                  trailing: Switch(
                    value: isDarkMode,
                    activeColor: green,
                    onChanged: (val) {
                      setState(() {
                        isDarkMode = val;
                      });
                      // Update global theme
                      MyApp.themeModeNotifier.value = val
                          ? ThemeMode.dark
                          : ThemeMode.light;
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // SMS Settings Section
            _buildSectionCard(
              context: context,
              title: 'SMS Settings',
              icon: Icons.message,
              color: green,
              children: [
                _buildSettingItem(
                  context: context,
                  leading: Icons.message,
                  title: 'Predefined SMS Messages',
                  subtitle: 'Edit messages for Button 1 alerts',
                  trailing: IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 16),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PredefinedMessagesScreen(),
                        ),
                      );
                    },
                    tooltip: 'Edit Messages',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Save Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: CustomButton(
                label: isLoading
                    ? 'Saving...'
                    : (l10n?.saveSettings ?? 'Save Settings'),
                onPressed: isLoading ? () {} : () => _saveSettings(),
                color: green,
                textColor: Colors.white,
              ),
            ),

            if (successMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8.0),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        successMessage!,
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required BuildContext context,
    required IconData leading,
    required String title,
    String? subtitle,
    required Widget trailing,
  }) {
    return Row(
      children: [
        Icon(leading, size: 24, color: Colors.grey.shade600),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
        ),
        trailing,
      ],
    );
  }
}
