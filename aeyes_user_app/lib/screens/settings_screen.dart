import 'package:flutter/material.dart';
import '../widgets/custom_button.dart';
import '../models/settings.dart';
import '../main.dart';
import '../widgets/main_scaffold.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final List<String> languages = ['English', 'Spanish', 'French'];
  String selectedLanguage = 'English';
  double volume = 0.5;
  double beepVolume = 0.5;
  bool notificationsEnabled = true;
  bool isDarkMode = false;
  String? successMessage;
  double bass = 5;
  double mid = 5;
  double treble = 5;

  void _saveSettings() {
    setState(() {
      successMessage = 'Settings saved!';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      currentIndex: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Language', style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButton<String>(
                      value: selectedLanguage,
                      items: languages.map((lang) => DropdownMenuItem(
                        value: lang,
                        child: Text(lang),
                      )).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedLanguage = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    const Text('Volume', style: TextStyle(fontWeight: FontWeight.bold)),
                    Slider(
                      value: volume,
                      min: 0,
                      max: 1,
                      divisions: 10,
                      label: (volume * 100).toInt().toString(),
                      onChanged: (val) {
                        setState(() {
                          volume = val;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    const Text('Beep Volume (Bone Conduction)'),
                    Slider(
                      value: beepVolume,
                      min: 0,
                      max: 1,
                      divisions: 10,
                      label: (beepVolume * 100).toInt().toString(),
                      onChanged: (val) {
                        setState(() {
                          beepVolume = val;
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
                        Switch(
                          value: notificationsEnabled,
                          onChanged: (val) {
                            setState(() {
                              notificationsEnabled = val;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.bold)),
                        Switch(
                          value: isDarkMode,
                          onChanged: (val) {
                            setState(() {
                              isDarkMode = val;
                            });
                            // Update global theme
                            MyApp.themeModeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text('Equalizer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 12),
                    const Text('Bass'),
                    Slider(
                      value: bass,
                      min: 0,
                      max: 10,
                      divisions: 10,
                      label: bass.toInt().toString(),
                      onChanged: (val) {
                        setState(() {
                          bass = val;
                        });
                      },
                    ),
                    const Text('Mid'),
                    Slider(
                      value: mid,
                      min: 0,
                      max: 10,
                      divisions: 10,
                      label: mid.toInt().toString(),
                      onChanged: (val) {
                        setState(() {
                          mid = val;
                        });
                      },
                    ),
                    const Text('Treble'),
                    Slider(
                      value: treble,
                      min: 0,
                      max: 10,
                      divisions: 10,
                      label: treble.toInt().toString(),
                      onChanged: (val) {
                        setState(() {
                          treble = val;
                        });
                      },
                    ),
                    const SizedBox(height: 32),
                    Center(
                      child: CustomButton(
                        label: 'Save',
                        onPressed: _saveSettings,
                      ),
                    ),
                    if (successMessage != null) ...[
                      const SizedBox(height: 16),
                      Center(child: Text(successMessage!, style: TextStyle(color: Colors.green))),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 