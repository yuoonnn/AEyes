import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aeyes_user_app/l10n/app_localizations.dart';
import '../services/language_service.dart';
import '../services/database_service.dart';
import '../main.dart';
import '../models/user.dart' as app_user;
import 'map_screen.dart';

class GuardianDashboardScreen extends StatefulWidget {
  const GuardianDashboardScreen({Key? key}) : super(key: key);

  @override
  State<GuardianDashboardScreen> createState() => _GuardianDashboardScreenState();
}

class _GuardianDashboardScreenState extends State<GuardianDashboardScreen> {
  final DatabaseService _databaseService = DatabaseService();
  bool isLoading = true;
  app_user.User? guardianProfile;
  bool isDarkMode = false;
  
  // Linked users
  List<Map<String, dynamic>> linkedUsers = [];
  String? selectedUserId;
  Map<String, dynamic>? selectedUser;
  
  // Real-time data
  Map<String, dynamic>? userLocation;
  Map<String, dynamic>? deviceStatus;
  Map<String, dynamic>? latestDetection;
  List<Map<String, dynamic>> alerts = [];
  
  // Stream subscriptions
  StreamSubscription<DocumentSnapshot?>? _locationSubscription;
  StreamSubscription<DocumentSnapshot?>? _deviceSubscription;
  StreamSubscription<QuerySnapshot>? _alertsSubscription;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadThemeMode();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _deviceSubscription?.cancel();
    _alertsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      // Load guardian profile
      final profile = await _databaseService.getUserProfile();
      
      // Load linked users
      final users = await _databaseService.getLinkedUsersForGuardian(user.email ?? '');
      
      setState(() {
        guardianProfile = profile;
        linkedUsers = users;
        if (users.isNotEmpty) {
          selectedUserId = users.first['user_id'] as String;
          selectedUser = users.first;
          _startRealTimeListeners();
        }
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  void _startRealTimeListeners() {
    if (selectedUserId == null) return;
    
    // Location stream
    _locationSubscription?.cancel();
    _locationSubscription = _databaseService.getLatestUserLocationStream(selectedUserId!)
        .listen((snapshot) {
      if (snapshot != null && mounted) {
        setState(() {
          userLocation = {
            'location_id': snapshot.id,
            ...snapshot.data() as Map<String, dynamic>,
          };
        });
      }
    });

    // Device status stream
    _deviceSubscription?.cancel();
    _deviceSubscription = _databaseService.getUserDeviceStatusStream(selectedUserId!)
        .listen((snapshot) {
      if (snapshot != null && mounted) {
        setState(() {
          deviceStatus = {
            'device_id': snapshot.id,
            ...snapshot.data() as Map<String, dynamic>,
          };
        });
      }
    });

    // Alerts stream
    _alertsSubscription?.cancel();
    _alertsSubscription = _databaseService.getUserAlertsStream(selectedUserId!)
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          alerts = snapshot.docs.map((doc) => {
            'alert_id': doc.id,
            ...doc.data() as Map<String, dynamic>,
          }).toList();
        });
      }
    });

    // Load initial data
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (selectedUserId == null) return;
    
    try {
      final location = await _databaseService.getLatestUserLocation(selectedUserId!);
      final device = await _databaseService.getUserDeviceStatus(selectedUserId!);
      final detection = await _databaseService.getLatestDetectionEvent(selectedUserId!);
      final alertsList = await _databaseService.getUserAlerts(selectedUserId!);
      
      if (mounted) {
        setState(() {
          userLocation = location;
          deviceStatus = device;
          latestDetection = detection;
          alerts = alertsList;
        });
      }
    } catch (e) {
      print('Error loading initial data: $e');
    }
  }

  void _loadThemeMode() {
    if (mounted) {
      setState(() {
        isDarkMode = Theme.of(context).brightness == Brightness.dark;
      });
    }
  }

  Future<void> _acknowledgeAlert(String alertId) async {
    try {
      await _databaseService.acknowledgeAlert(alertId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alert acknowledged')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _showSendMessageDialog() async {
    if (selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No user selected')),
      );
      return;
    }

    final messageController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Message'),
        content: TextField(
          controller: messageController,
          decoration: const InputDecoration(
            hintText: 'Enter your message',
            border: OutlineInputBorder(),
          ),
          maxLines: 4,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (messageController.text.trim().isEmpty) return;
              
              try {
                await _databaseService.sendMessageToUser(
                  userId: selectedUserId!,
                  messageType: 'text',
                  content: messageController.text.trim(),
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Message sent')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      final date = timestamp is Timestamp ? timestamp.toDate() : DateTime.parse(timestamp.toString());
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
      if (difference.inHours < 24) return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } catch (e) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final languageService = Provider.of<LanguageService>(context);
    final user = FirebaseAuth.instance.currentUser;
    final green = const Color(0xFF388E3C);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guardian Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : linkedUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_off, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      const Text(
                        'No linked users',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Users need to link you as their guardian first',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(24.0),
                  children: [
                    const Text('Welcome, Guardian!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    
                    // User Selection
                    if (linkedUsers.length > 1)
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Select User', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              DropdownButton<String>(
                                value: selectedUserId,
                                isExpanded: true,
                                items: linkedUsers.map((u) => DropdownMenuItem(
                                  value: u['user_id'] as String,
                                  child: Text(u['name'] as String? ?? u['email'] as String? ?? 'Unknown'),
                                )).toList(),
                                onChanged: (userId) {
                                  if (userId != null) {
                                    setState(() {
                                      selectedUserId = userId;
                                      selectedUser = linkedUsers.firstWhere((u) => u['user_id'] == userId);
                                      userLocation = null;
                                      deviceStatus = null;
                                      latestDetection = null;
                                      alerts = [];
                                    });
                                    _startRealTimeListeners();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (linkedUsers.length == 1)
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: const Icon(Icons.person, color: Colors.blue),
                          title: Text(selectedUser?['name'] as String? ?? 'User'),
                          subtitle: Text(selectedUser?['email'] as String? ?? ''),
                        ),
                      ),
                    const SizedBox(height: 24),
                    
                    // Profile Section
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ExpansionTile(
                        leading: const Icon(Icons.person, size: 36, color: Colors.blue),
                        title: const Text('Profile'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildProfileItem(
                                  icon: Icons.person,
                                  label: 'Name',
                                  value: guardianProfile?.name ?? user?.displayName ?? user?.email?.split('@')[0] ?? 'Guardian',
                                ),
                                const Divider(),
                                _buildProfileItem(
                                  icon: Icons.email,
                                  label: 'Email',
                                  value: guardianProfile?.email ?? user?.email ?? 'No email',
                                ),
                                if (guardianProfile?.phone != null) ...[
                                  const Divider(),
                                  _buildProfileItem(
                                    icon: Icons.phone,
                                    label: 'Phone',
                                    value: guardianProfile!.phone!,
                                  ),
                                ],
                                if (guardianProfile?.address != null) ...[
                                  const Divider(),
                                  _buildProfileItem(
                                    icon: Icons.location_on,
                                    label: 'Address',
                                    value: guardianProfile!.address!,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Settings Section
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ExpansionTile(
                        leading: const Icon(Icons.settings, size: 36, color: Colors.deepPurple),
                        title: const Text('Settings'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.language),
                                  title: const Text('Language'),
                                  subtitle: Text(
                                    LanguageService.languageNames[languageService.locale.languageCode] ?? 'English',
                                  ),
                                  trailing: DropdownButton<Locale>(
                                    value: languageService.locale,
                                    items: LanguageService.supportedLocales.map((locale) => DropdownMenuItem(
                                      value: locale,
                                      child: Text(LanguageService.languageNames[locale.languageCode] ?? locale.languageCode),
                                    )).toList(),
                                    onChanged: (locale) {
                                      if (locale != null) {
                                        languageService.setLanguage(locale);
                                      }
                                    },
                                    underline: Container(),
                                  ),
                                ),
                                const Divider(),
                                SwitchListTile(
                                  secondary: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode),
                                  title: const Text('Dark Mode'),
                                  subtitle: const Text('Switch between light and dark theme'),
                                  value: isDarkMode,
                                  activeColor: green,
                                  onChanged: (val) {
                                    setState(() {
                                      isDarkMode = val;
                                    });
                                    MyApp.themeModeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // User Monitoring
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: const Icon(Icons.visibility, size: 36, color: Colors.blue),
                        title: const Text('User Monitoring'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('Status: ${deviceStatus != null ? "Online" : "Offline"}'),
                            if (deviceStatus != null && deviceStatus!['battery_level'] != null)
                              Text('Battery: ${deviceStatus!['battery_level']}%'),
                            if (latestDetection != null) ...[
                              Text('Last activity: ${_formatTimestamp(latestDetection!['timestamp'])}'),
                              if (latestDetection!['detected_label'] != null)
                                Text('Last detection: ${latestDetection!['detected_label']}'),
                            ] else
                              const Text('Last activity: No recent activity'),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Location Tracking
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: const Icon(Icons.location_on, size: 36, color: Colors.red),
                        title: const Text('Location Tracking'),
                        subtitle: userLocation != null
                            ? Text('Last updated: ${_formatTimestamp(userLocation!['timestamp'])}')
                            : const Text('No location data available'),
                        trailing: IconButton(
                          icon: const Icon(Icons.map),
                          onPressed: () {
                            if (selectedUserId != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MapScreen(userId: selectedUserId),
                                ),
                              );
                            }
                          },
                        ),
                        onTap: () {
                          if (selectedUserId != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MapScreen(userId: selectedUserId),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Notifications & Alerts
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ExpansionTile(
                        leading: const Icon(Icons.warning, size: 36, color: Colors.orange),
                        title: Text('Notifications & Alerts (${alerts.length})'),
                        children: alerts.isEmpty
                            ? [
                                const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text('No active alerts'),
                                ),
                              ]
                            : alerts.map((alert) {
                                return ListTile(
                                  leading: Icon(
                                    alert['severity'] == 'critical' ? Icons.error : Icons.info,
                                    color: alert['severity'] == 'critical' ? Colors.red : Colors.blue,
                                  ),
                                  title: Text(alert['alert_type'] as String? ?? 'Alert'),
                                  subtitle: Text(_formatTimestamp(alert['triggered_at'])),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.check),
                                    onPressed: () => _acknowledgeAlert(alert['alert_id'] as String),
                                    tooltip: 'Acknowledge',
                                  ),
                                );
                              }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Communication
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: const Icon(Icons.message, size: 36, color: Colors.teal),
                        title: const Text('Communication'),
                        subtitle: const Text('Send a message or alert to the user.'),
                        trailing: IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: _showSendMessageDialog,
                        ),
                        onTap: _showSendMessageDialog,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Center(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.person),
                        label: const Text('Log in as User'),
                        onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildProfileItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
