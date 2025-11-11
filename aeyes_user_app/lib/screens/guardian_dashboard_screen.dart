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
import '../theme/app_theme.dart';
import '../widgets/custom_textfield.dart';

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
  bool isEditingProfile = false;
  
  // Profile editing controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  
  // Linked users
  List<Map<String, dynamic>> linkedUsers = [];
  List<Map<String, dynamic>> pendingRequests = [];
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
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
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
      var profile = await _databaseService.getUserProfile();
      
      // If profile doesn't exist, create one (for guardians who logged in with Google/Facebook)
      if (profile == null) {
        await _databaseService.saveUserProfile(
          app_user.User(
            id: user.uid,
            name: user.displayName ?? user.email?.split('@')[0] ?? 'Guardian',
            email: user.email ?? '',
            phone: user.phoneNumber,
            role: 'guardian',
          ),
        );
        profile = await _databaseService.getUserProfile();
      }
      
      final guardianEmail = user.email ?? '';
      
      // Load linked users
      final users = await _databaseService.getLinkedUsersForGuardian(guardianEmail);
      
      // Load pending link requests
      final pending = await _databaseService.getPendingLinkRequests(guardianEmail);
      
      setState(() {
        guardianProfile = profile;
        linkedUsers = users;
        pendingRequests = pending;
        if (users.isNotEmpty) {
          selectedUserId = users.first['user_id'] as String;
          selectedUser = users.first;
          _startRealTimeListeners();
        }
        isLoading = false;
      });
      
      // Initialize profile editing controllers
      if (profile != null) {
        nameController.text = profile.name ?? '';
        phoneController.text = profile.phone ?? '';
        addressController.text = profile.address ?? '';
      }
    } catch (e) {
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _loadProfile(),
            ),
          ),
        );
      }
      
      setState(() => isLoading = false);
    }
  }

  Future<void> _approveRequest(String guardianId) async {
    try {
      await _databaseService.approveLinkRequest(guardianId);
      // Reload profile to refresh linked users
      await _loadProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link request approved!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
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
      // Error is handled silently - data will load via streams
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

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final l10n = AppLocalizations.of(context);
    setState(() => isLoading = true);
    
    try {
      // Update Firebase Auth display name
      await user.updateDisplayName(nameController.text.trim());
      
      // Save to Firestore
      await _databaseService.saveUserProfile(
        app_user.User(
          id: user.uid,
          name: nameController.text.trim(),
          email: user.email ?? '',
          phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
          address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
          role: 'guardian',
        ),
      );
      
      // Reload profile
      await _loadProfile();
      
      setState(() {
        isEditingProfile = false;
        isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n?.profileUpdatedSuccessfully ?? 'Profile updated successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    final l10n = AppLocalizations.of(context);
    if (timestamp == null) return l10n?.unknown ?? 'Unknown';
    try {
      final date = timestamp is Timestamp ? timestamp.toDate() : DateTime.parse(timestamp.toString());
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
      if (difference.inHours < 24) return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } catch (e) {
      return l10n?.unknown ?? 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final languageService = Provider.of<LanguageService>(context);
    final user = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.guardianDashboard ?? 'Guardian Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n?.refresh ?? 'Refresh',
            onPressed: () {
              setState(() => isLoading = true);
              _loadProfile();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: l10n?.logout ?? 'Logout',
            onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : linkedUsers.isEmpty
              ? SingleChildScrollView(
                  padding: AppTheme.paddingLG,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: AppTheme.spacingXXL),
                      Icon(Icons.person_off, size: 64, color: AppTheme.textSecondary),
                      SizedBox(height: AppTheme.spacingMD),
                      Text(
                        l10n?.noLinkedUsers ?? 'No linked users',
                        style: AppTheme.textStyleTitle.copyWith(
                          fontWeight: AppTheme.fontWeightBold,
                        ),
                      ),
                      SizedBox(height: AppTheme.spacingSM),
                      Text(
                        l10n?.usersNeedToLinkYou ?? 'Users need to link you as their guardian first',
                        style: AppTheme.textStyleBody.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: AppTheme.spacingXL),
                      // Show guardian email for linking
                      if (user?.email != null) ...[
                        Card(
                          color: AppTheme.primaryWithOpacity(0.1),
                          child: Padding(
                            padding: AppTheme.paddingMD,
                            child: Column(
                              children: [
                                Text(
                                  l10n?.yourGuardianEmail ?? 'Your Guardian Email:',
                                  style: AppTheme.textStyleCaption.copyWith(
                                    fontWeight: AppTheme.fontWeightBold,
                                  ),
                                ),
                                SizedBox(height: AppTheme.spacingSM),
                                SelectableText(
                                  user!.email!,
                                  style: AppTheme.textStyleBodyLarge.copyWith(
                                    fontWeight: AppTheme.fontWeightBold,
                                    color: AppTheme.success,
                                  ),
                                ),
                                SizedBox(height: AppTheme.spacingSM),
                                Text(
                                  l10n?.shareThisEmail ?? 'Share this email with users to link you as their guardian',
                                  style: AppTheme.textStyleCaption.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: AppTheme.spacingLG),
                      ],
                      // Show pending requests
                      if (pendingRequests.isNotEmpty) ...[
                        Text(
                          l10n?.pendingLinkRequests ?? 'Pending Link Requests',
                          style: AppTheme.textStyleBodyLarge.copyWith(
                            fontWeight: AppTheme.fontWeightBold,
                          ),
                        ),
                        SizedBox(height: AppTheme.spacingMD),
                        ...pendingRequests.map((request) => Card(
                          margin: EdgeInsets.only(bottom: AppTheme.spacingMD),
                          child: ListTile(
                            leading: const Icon(Icons.person_add, color: AppTheme.warning),
                            title: Text(request['name'] ?? (l10n?.unknownUser ?? 'Unknown User')),
                            subtitle: Text(request['email'] ?? ''),
                            trailing: ElevatedButton(
                              onPressed: () => _approveRequest(request['guardian_id'] as String),
                              style: AppTheme.primaryButtonStyle,
                              child: Text(l10n?.approve ?? 'Approve', style: const TextStyle(color: Colors.white)),
                            ),
                          ),
                        )),
                        SizedBox(height: AppTheme.spacingLG),
                      ],
                    ],
                  ),
                )
              : ListView(
                  padding: AppTheme.paddingLG,
                  children: [
                    Text(l10n?.welcomeGuardian ?? 'Welcome, Guardian!', style: AppTheme.textStyleHeadline2.copyWith(
                      fontWeight: AppTheme.fontWeightBold,
                    )),
                    SizedBox(height: AppTheme.spacingMD),
                    
                    // Pending Link Requests (show even when there are active users)
                    if (pendingRequests.isNotEmpty) ...[
                      Card(
                        color: AppTheme.warning.withOpacity(0.1),
                        child: Padding(
                          padding: AppTheme.paddingMD,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.person_add, color: AppTheme.warning),
                                  SizedBox(width: AppTheme.spacingSM),
                                  Expanded(
                                    child: Text(
                                      l10n?.pendingLinkRequests ?? 'Pending Link Requests',
                                      style: AppTheme.textStyleBodyLarge.copyWith(
                                        fontWeight: AppTheme.fontWeightBold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: AppTheme.spacingMD),
                              ...pendingRequests.map((request) => Card(
                                margin: EdgeInsets.only(bottom: AppTheme.spacingSM),
                                child: ListTile(
                                  title: Text(request['name'] ?? (l10n?.unknownUser ?? 'Unknown User')),
                                  subtitle: Text(request['email'] ?? ''),
                                  trailing: ElevatedButton(
                                    onPressed: () => _approveRequest(request['guardian_id'] as String),
                                    style: AppTheme.primaryButtonStyle,
                                    child: Text(l10n?.approve ?? 'Approve', style: const TextStyle(color: Colors.white)),
                                  ),
                                ),
                              )),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: AppTheme.spacingMD),
                    ],
                    
                    // User Selection
                    if (linkedUsers.length > 1)
                      Card(
                        elevation: AppTheme.elevationMedium,
                        shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadiusMD),
                        child: Padding(
                          padding: AppTheme.paddingMD,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n?.selectUser ?? 'Select User', style: AppTheme.textStyleBodyLarge.copyWith(
                                fontWeight: AppTheme.fontWeightBold,
                              )),
                              SizedBox(height: AppTheme.spacingSM),
                              DropdownButton<String>(
                                value: selectedUserId,
                                isExpanded: true,
                                items: linkedUsers.map((u) => DropdownMenuItem(
                                  value: u['user_id'] as String,
                                  child: Text(u['name'] as String? ?? u['email'] as String? ?? (l10n?.unknown ?? 'Unknown')),
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
                        elevation: AppTheme.elevationMedium,
                        shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadiusMD),
                        child: ListTile(
                          leading: const Icon(Icons.person, color: AppTheme.info),
                          title: Text(selectedUser?['name'] as String? ?? 'User'),
                          subtitle: Text(selectedUser?['email'] as String? ?? ''),
                        ),
                      ),
                    SizedBox(height: AppTheme.spacingLG),
                    
                    // Profile Section
                    Card(
                      elevation: AppTheme.elevationMedium,
                      shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadiusMD),
                      child: ExpansionTile(
                        leading: const Icon(Icons.person, size: 36, color: AppTheme.info),
                        title: Text(l10n?.profile ?? 'Profile'),
                        trailing: isEditingProfile
                            ? Wrap(
                                spacing: AppTheme.spacingXS,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.check, color: AppTheme.success),
                                    onPressed: _saveProfile,
                                    tooltip: l10n?.save ?? 'Save',
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.all(AppTheme.spacingXS),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: AppTheme.error),
                                    onPressed: () {
                                      setState(() {
                                        isEditingProfile = false;
                                        // Reset controllers
                                        if (guardianProfile != null) {
                                          nameController.text = guardianProfile!.name ?? '';
                                          phoneController.text = guardianProfile!.phone ?? '';
                                          addressController.text = guardianProfile!.address ?? '';
                                        }
                                      });
                                    },
                                    tooltip: l10n?.edit ?? 'Cancel',
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.all(AppTheme.spacingXS),
                                  ),
                                ],
                              )
                            : IconButton(
                                icon: const Icon(Icons.edit, color: AppTheme.primaryGreen),
                                onPressed: () => setState(() => isEditingProfile = true),
                                tooltip: l10n?.edit ?? 'Edit',
                              ),
                        children: [
                          Padding(
                            padding: AppTheme.paddingMD,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (isEditingProfile) ...[
                                  CustomTextField(
                                    hintText: l10n?.enterYourName ?? 'Enter your name',
                                    controller: nameController,
                                    enabled: true,
                                  ),
                                  SizedBox(height: AppTheme.spacingMD),
                                  _buildProfileItem(
                                    icon: Icons.email,
                                    label: l10n?.email ?? 'Email',
                                    value: guardianProfile?.email ?? user?.email ?? (l10n?.noEmail ?? 'No email'),
                                  ),
                                  SizedBox(height: AppTheme.spacingMD),
                                  CustomTextField(
                                    hintText: l10n?.enterYourPhoneNumber ?? 'Enter your phone number',
                                    controller: phoneController,
                                    enabled: true,
                                    keyboardType: TextInputType.phone,
                                  ),
                                  SizedBox(height: AppTheme.spacingMD),
                                  CustomTextField(
                                    hintText: l10n?.enterYourAddress ?? 'Enter your address',
                                    controller: addressController,
                                    enabled: true,
                                  ),
                                ] else ...[
                                  _buildProfileItem(
                                    icon: Icons.person,
                                    label: l10n?.name ?? 'Name',
                                    value: guardianProfile?.name ?? user?.displayName ?? user?.email?.split('@')[0] ?? 'Guardian',
                                  ),
                                  const Divider(),
                                  _buildProfileItem(
                                    icon: Icons.email,
                                    label: l10n?.email ?? 'Email',
                                    value: guardianProfile?.email ?? user?.email ?? (l10n?.noEmail ?? 'No email'),
                                  ),
                                  if (guardianProfile?.phone != null) ...[
                                    const Divider(),
                                    _buildProfileItem(
                                      icon: Icons.phone,
                                      label: l10n?.phone ?? 'Phone',
                                      value: guardianProfile!.phone!,
                                    ),
                                  ],
                                  if (guardianProfile?.address != null) ...[
                                    const Divider(),
                                    _buildProfileItem(
                                      icon: Icons.location_on,
                                      label: l10n?.address ?? 'Address',
                                      value: guardianProfile!.address!,
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: AppTheme.spacingLG),
                    
                    // Settings Section
                    Card(
                      elevation: AppTheme.elevationMedium,
                      shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadiusMD),
                      child: ExpansionTile(
                        leading: const Icon(Icons.settings, size: 36, color: AppTheme.primaryGreen),
                        title: const Text('Settings'),
                        children: [
                          Padding(
                            padding: AppTheme.paddingMD,
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
                                  activeColor: AppTheme.primaryGreen,
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
                    SizedBox(height: AppTheme.spacingLG),
                    
                    // Location Tracking
                    Card(
                      elevation: AppTheme.elevationMedium,
                      shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadiusMD),
                      child: ListTile(
                        leading: const Icon(Icons.location_on, size: 36, color: AppTheme.error),
                        title: Text(l10n?.locationTracking ?? 'Location Tracking'),
                        subtitle: userLocation != null
                            ? Text(l10n != null ? l10n!.lastUpdated(_formatTimestamp(userLocation!['timestamp'])) : 'Last updated: ${_formatTimestamp(userLocation!['timestamp'])}')
                            : Text(l10n?.noLocationDataAvailable ?? 'No location data available'),
                        trailing: IconButton(
                          icon: const Icon(Icons.map),
                          onPressed: () {
                            if (selectedUserId != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MapScreen(userId: selectedUserId!),
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
                                builder: (context) => MapScreen(userId: selectedUserId!),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    SizedBox(height: AppTheme.spacingLG),
                    
                    // Battery & Alerts
                    Card(
                      elevation: AppTheme.elevationMedium,
                      shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadiusMD),
                      child: ExpansionTile(
                        leading: const Icon(Icons.battery_alert, size: 36, color: AppTheme.warning),
                        title: Text(l10n != null ? l10n!.batteryAndAlerts(alerts.length) : 'Battery & Alerts (${alerts.length})'),
                        subtitle: deviceStatus != null && deviceStatus!['battery_level'] != null
                            ? Text(l10n != null ? l10n!.deviceBattery(deviceStatus!['battery_level'] as int) : 'Device Battery: ${deviceStatus!['battery_level']}%')
                            : Text(l10n?.noBatteryDataAvailable ?? 'No battery data available'),
                        children: [
                          // Battery Status
                          if (deviceStatus != null && deviceStatus!['battery_level'] != null)
                            Padding(
                              padding: AppTheme.paddingMD,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.battery_std,
                                    size: 32,
                                    color: (deviceStatus!['battery_level'] as int) < 20
                                        ? AppTheme.error
                                        : (deviceStatus!['battery_level'] as int) < 50
                                            ? AppTheme.warning
                                            : AppTheme.success,
                                  ),
                                  SizedBox(width: AppTheme.spacingMD),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Device Battery',
                                          style: AppTheme.textStyleBody.copyWith(
                                            fontWeight: AppTheme.fontWeightBold,
                                          ),
                                        ),
                                        Text(
                                          '${deviceStatus!['battery_level']}%',
                                          style: AppTheme.textStyleTitle.copyWith(
                                            fontWeight: AppTheme.fontWeightBold,
                                            color: (deviceStatus!['battery_level'] as int) < 20
                                                ? AppTheme.error
                                                : (deviceStatus!['battery_level'] as int) < 50
                                                    ? AppTheme.warning
                                                    : AppTheme.success,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (deviceStatus != null && deviceStatus!['battery_level'] != null && alerts.isNotEmpty)
                            const Divider(),
                          // Alerts
                          if (alerts.isEmpty)
                            Padding(
                              padding: AppTheme.paddingMD,
                              child: Text(l10n?.noActiveAlerts ?? 'No active alerts'),
                            )
                          else
                            ...alerts.map((alert) {
                              return ListTile(
                                leading: Icon(
                                  alert['severity'] == 'critical' ? Icons.error : Icons.info,
                                  color: alert['severity'] == 'critical' ? AppTheme.error : AppTheme.info,
                                ),
                                title: Text(alert['alert_type'] as String? ?? 'Alert'),
                                subtitle: Text(_formatTimestamp(alert['triggered_at'])),
                                trailing: IconButton(
                                  icon: const Icon(Icons.check),
                                  onPressed: () => _acknowledgeAlert(alert['alert_id'] as String),
                                  tooltip: l10n?.acknowledge ?? 'Acknowledge',
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                    SizedBox(height: AppTheme.spacingLG),
                    
                    // Communication
                    Card(
                      elevation: AppTheme.elevationMedium,
                      shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadiusMD),
                      child: ListTile(
                        leading: const Icon(Icons.message, size: 36, color: AppTheme.info),
                        title: Text(l10n?.communication ?? 'Communication'),
                        subtitle: Text(l10n?.sendMessageOrAlert ?? 'Send a message or alert to the user.'),
                        trailing: IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: _showSendMessageDialog,
                        ),
                        onTap: _showSendMessageDialog,
                      ),
                    ),
                    SizedBox(height: AppTheme.spacingXL),
                    Center(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.person),
                        label: Text(l10n?.logInAsUser ?? 'Log in as User'),
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
      padding: AppTheme.paddingVerticalSM,
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.textSecondary),
          SizedBox(width: AppTheme.spacingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTheme.textStyleCaption.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: AppTheme.fontWeightMedium,
                  ),
                ),
                SizedBox(height: AppTheme.spacingXS),
                Text(
                  value,
                  style: AppTheme.textStyleBodyLarge.copyWith(
                    fontWeight: AppTheme.fontWeightMedium,
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