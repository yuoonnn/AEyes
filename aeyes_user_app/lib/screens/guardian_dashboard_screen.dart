import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aeyes_user_app/l10n/app_localizations.dart';
import '../services/language_service.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../main.dart';
import '../models/user.dart' as app_user;
import 'map_screen.dart';
import 'guardian_messages_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_textfield.dart';

class GuardianDashboardScreen extends StatefulWidget {
  const GuardianDashboardScreen({Key? key}) : super(key: key);

  @override
  State<GuardianDashboardScreen> createState() =>
      _GuardianDashboardScreenState();
}

class _GuardianDashboardScreenState extends State<GuardianDashboardScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();
  bool isLoading = true;
  app_user.User? guardianProfile;
  bool isDarkMode = false;
  bool isEditingProfile = false;
  bool isDeletingAccount = false;

  // Profile editing controllers
  final TextEditingController nameController = TextEditingController();

  // Linked users
  List<Map<String, dynamic>> linkedUsers = [];
  List<Map<String, dynamic>> pendingRequests = [];
  String? selectedUserId;
  Map<String, dynamic>? selectedUser;

  // Real-time data
  Map<String, dynamic>? userLocation;
  Map<String, dynamic>? deviceStatus;
  Map<String, dynamic>? latestDetection;

  // Stream subscriptions
  StreamSubscription<DocumentSnapshot?>? _locationSubscription;
  StreamSubscription<DocumentSnapshot?>? _deviceSubscription;

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
    nameController.dispose();
    super.dispose();
  }

  Future<void> _confirmDeleteAccount() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleStyle =
        theme.textTheme.titleLarge?.copyWith(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.bold,
        ) ??
        TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        );
    final contentStyle =
        theme.textTheme.bodyMedium?.copyWith(
          color: isDark ? Colors.grey[300] : Colors.black87,
        ) ??
        TextStyle(
          color: isDark ? Colors.grey[300] : Colors.black87,
          fontSize: 16,
        );
    final cancelColor = isDark ? Colors.grey[200] : Colors.grey[700];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Guardian Account', style: titleStyle),
        content: Text(
          'Deleting your guardian account will remove your profile, linked users, pending requests, and messages. This action cannot be undone.\n\nAre you sure you want to proceed?',
          style: contentStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: cancelColor),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteAccount();
    }
  }

  Future<void> _deleteAccount() async {
    setState(() {
      isDeletingAccount = true;
    });

    final result = await _authService.deleteCurrentAccount(isGuardian: true);

    if (!mounted) return;

    setState(() {
      isDeletingAccount = false;
    });

    if (result != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your guardian account has been deleted.'),
        ),
      );
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
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
      final users = await _databaseService.getLinkedUsersForGuardian(
        guardianEmail,
      );

      // Load pending link requests
      final pending = await _databaseService.getPendingLinkRequests(
        guardianEmail,
      );

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
        nameController.text = profile.name;
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Link request approved!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _unlinkUser(String userId) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleStyle =
        theme.textTheme.titleLarge?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ) ??
        TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        );
    final contentStyle =
        theme.textTheme.bodyMedium?.copyWith(
          color: isDark ? Colors.grey[300] : Colors.black87,
        ) ??
        TextStyle(
          color: isDark ? Colors.grey[300] : Colors.black87,
          fontSize: 16,
        );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Unlink User', style: titleStyle),
        content: Text(
          'Are you sure you want to unlink this user? You will no longer receive their alerts and messages.',
          style: contentStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Unlink', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => isLoading = true);
    try {
      await _databaseService.unlinkUserAsGuardian(userId);
      // Reload profile to refresh linked users
      await _loadProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User unlinked successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error unlinking user: $e')));
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _startRealTimeListeners() {
    if (selectedUserId == null) return;

    // Location stream
    _locationSubscription?.cancel();
    _locationSubscription = _databaseService
        .getLatestUserLocationStream(selectedUserId!)
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
    _deviceSubscription = _databaseService
        .getUserDeviceStatusStream(selectedUserId!)
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

    // Load initial data
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (selectedUserId == null) return;

    try {
      final location = await _databaseService.getLatestUserLocation(
        selectedUserId!,
      );
      final device = await _databaseService.getUserDeviceStatus(
        selectedUserId!,
      );
      final detection = await _databaseService.getLatestDetectionEvent(
        selectedUserId!,
      );

      if (mounted) {
        setState(() {
          userLocation = location;
          deviceStatus = device;
          latestDetection = detection;
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

  Future<void> _showSendMessageDialog() async {
    if (selectedUserId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No user selected')));
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
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Message sent')));
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
          phone: guardianProfile?.phone,
          address: guardianProfile?.address,
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
            content: Text(
              l10n?.profileUpdatedSuccessfully ??
                  'Profile updated successfully!',
            ),
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
      final date = timestamp is Timestamp
          ? timestamp.toDate()
          : DateTime.parse(timestamp.toString());
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
      if (difference.inHours < 24)
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } catch (e) {
      return l10n?.unknown ?? 'Unknown';
    }
  }

  Widget _buildGuidanceManualCard() {
    final steps = [
      {
        'title': 'Enable critical permissions',
        'description':
            'Guide the user to open phone settings and confirm the AEyes app has location, microphone, notification, and Bluetooth permissions enabled.',
      },
      {
        'title': 'Verify background location',
        'description':
            'Ensure location access is set to “Allow all the time” so guardians can monitor the user even when the app runs in the background.',
      },
      {
        'title': 'Pair the ESP32 eyeglass',
        'description':
            'Have the user power on the ESP32, open the app’s Bluetooth screen, start a scan, and tap the device name to pair. Confirm auto-reconnect is working by turning the device off and on.',
      },
      {
        'title': 'Check microphone capture',
        'description':
            'Coach the user to press the headset voice button, speak a sample command, and release to confirm OpenAI analysis and speech playback respond correctly.',
      },
      {
        'title': 'Confirm notification delivery',
        'description':
            'Send a test message from the guardian dashboard and make sure the user hears or sees the alert. Adjust notification settings if nothing arrives.',
      },
    ];

    return Card(
      elevation: AppTheme.elevationMedium,
      shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadiusMD),
      child: Padding(
        padding: AppTheme.paddingMD,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.menu_book_outlined,
                  color: AppTheme.primaryGreen,
                ),
                SizedBox(width: AppTheme.spacingSM),
                Expanded(
                  child: Text(
                    'Guardian Guidance Manual',
                    style: AppTheme.textStyleBodyLarge.copyWith(
                      fontWeight: AppTheme.fontWeightBold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: AppTheme.spacingMD),
            ...steps.map(
              (step) => Padding(
                padding: EdgeInsets.only(bottom: AppTheme.spacingSM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step['title'] ?? '',
                      style: AppTheme.textStyleBody.copyWith(
                        fontWeight: AppTheme.fontWeightBold,
                      ),
                    ),
                    SizedBox(height: AppTheme.spacingXS),
                    Text(
                      step['description'] ?? '',
                      style: AppTheme.textStyleBody.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final languageService = Provider.of<LanguageService>(context);
    final user = FirebaseAuth.instance.currentUser;
    final int? batteryLevel = deviceStatus != null
        ? deviceStatus!['battery_level'] as int?
        : null;
    final dynamic batteryTimestamp = deviceStatus != null
        ? (deviceStatus!['last_seen'] ?? deviceStatus!['updated_at'])
        : null;
    final String? batteryUpdatedLabel = batteryTimestamp != null
        ? (l10n?.lastUpdated(_formatTimestamp(batteryTimestamp)) ??
              'Last updated: ${_formatTimestamp(batteryTimestamp)}')
        : null;

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
            onPressed: () async {
              // Actually log out the user
              await _authService.logout();
              // Stop guardian message listener
              MyApp.stopGuardianMessageListener();
              MyApp.stopGuardianAlertListener();
              // Navigate to role selection
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                  (route) => false,
                );
              }
            },
          ),
          if (isDeletingAccount)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'More options',
              onSelected: (value) {
                if (value == 'delete_account') {
                  _confirmDeleteAccount();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'delete_account',
                  child: Row(
                    children: const [
                      Icon(Icons.delete_forever, color: Colors.red),
                      SizedBox(width: 12),
                      Text(
                        'Delete Account',
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
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
                  Icon(
                    Icons.person_off,
                    size: 64,
                    color: AppTheme.textSecondary,
                  ),
                  SizedBox(height: AppTheme.spacingMD),
                  Text(
                    l10n?.noLinkedUsers ?? 'No linked users',
                    style: AppTheme.textStyleTitle.copyWith(
                      fontWeight: AppTheme.fontWeightBold,
                    ),
                  ),
                  SizedBox(height: AppTheme.spacingSM),
                  Text(
                    l10n?.usersNeedToLinkYou ??
                        'Users need to link you as their guardian first',
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
                              l10n?.shareThisEmail ??
                                  'Share this email with users to link you as their guardian',
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
                    ...pendingRequests.map(
                      (request) => Card(
                        margin: EdgeInsets.only(bottom: AppTheme.spacingMD),
                        child: ListTile(
                          leading: const Icon(
                            Icons.person_add,
                            color: AppTheme.warning,
                          ),
                          title: Text(
                            request['name'] ??
                                (l10n?.unknownUser ?? 'Unknown User'),
                          ),
                          subtitle: Text(request['email'] ?? ''),
                          trailing: ElevatedButton(
                            onPressed: () => _approveRequest(
                              request['guardian_id'] as String,
                            ),
                            style: AppTheme.primaryButtonStyle,
                            child: Text(
                              l10n?.approve ?? 'Approve',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: AppTheme.spacingLG),
                  ],
                ],
              ),
            )
          : ListView(
              padding: AppTheme.paddingLG,
              children: [
                Text(
                  l10n?.welcomeGuardian ?? 'Welcome, Guardian!',
                  style: AppTheme.textStyleHeadline2.copyWith(
                    fontWeight: AppTheme.fontWeightBold,
                  ),
                ),
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
                              const Icon(
                                Icons.person_add,
                                color: AppTheme.warning,
                              ),
                              SizedBox(width: AppTheme.spacingSM),
                              Expanded(
                                child: Text(
                                  l10n?.pendingLinkRequests ??
                                      'Pending Link Requests',
                                  style: AppTheme.textStyleBodyLarge.copyWith(
                                    fontWeight: AppTheme.fontWeightBold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: AppTheme.spacingMD),
                          ...pendingRequests.map(
                            (request) => Card(
                              margin: EdgeInsets.only(
                                bottom: AppTheme.spacingSM,
                              ),
                              child: ListTile(
                                title: Text(
                                  request['name'] ??
                                      (l10n?.unknownUser ?? 'Unknown User'),
                                ),
                                subtitle: Text(request['email'] ?? ''),
                                trailing: ElevatedButton(
                                  onPressed: () => _approveRequest(
                                    request['guardian_id'] as String,
                                  ),
                                  style: AppTheme.primaryButtonStyle,
                                  child: Text(
                                    l10n?.approve ?? 'Approve',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                          ),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: AppTheme.borderRadiusMD,
                    ),
                    child: Padding(
                      padding: AppTheme.paddingMD,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  l10n?.selectUser ?? 'Select User',
                                  style: AppTheme.textStyleBodyLarge.copyWith(
                                    fontWeight: AppTheme.fontWeightBold,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.link_off,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  if (selectedUserId != null) {
                                    _unlinkUser(selectedUserId!);
                                  }
                                },
                                tooltip: 'Unlink Selected User',
                              ),
                            ],
                          ),
                          SizedBox(height: AppTheme.spacingSM),
                          DropdownButton<String>(
                            value: selectedUserId,
                            isExpanded: true,
                            items: linkedUsers
                                .map(
                                  (u) => DropdownMenuItem(
                                    value: u['user_id'] as String,
                                    child: Text(
                                      u['name'] as String? ??
                                          u['email'] as String? ??
                                          (l10n?.unknown ?? 'Unknown'),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (userId) {
                              if (userId != null) {
                                setState(() {
                                  selectedUserId = userId;
                                  selectedUser = linkedUsers.firstWhere(
                                    (u) => u['user_id'] == userId,
                                  );
                                  userLocation = null;
                                  deviceStatus = null;
                                  latestDetection = null;
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
                    shape: RoundedRectangleBorder(
                      borderRadius: AppTheme.borderRadiusMD,
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.person, color: AppTheme.info),
                      title: Text(selectedUser?['name'] as String? ?? 'User'),
                      subtitle: Text(selectedUser?['email'] as String? ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.link_off, color: Colors.red),
                        onPressed: () => _unlinkUser(
                          selectedUser?['user_id'] as String? ?? '',
                        ),
                        tooltip: 'Unlink User',
                      ),
                    ),
                  ),
                SizedBox(height: AppTheme.spacingLG),

                // Profile Section
                Card(
                  elevation: AppTheme.elevationMedium,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppTheme.borderRadiusMD,
                  ),
                  child: ExpansionTile(
                    leading: const Icon(
                      Icons.person,
                      size: 36,
                      color: AppTheme.info,
                    ),
                    title: Text(l10n?.profile ?? 'Profile'),
                    trailing: isEditingProfile
                        ? Wrap(
                            spacing: AppTheme.spacingXS,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.check,
                                  color: AppTheme.success,
                                ),
                                onPressed: _saveProfile,
                                tooltip: l10n?.save ?? 'Save',
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.all(AppTheme.spacingXS),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: AppTheme.error,
                                ),
                                onPressed: () {
                                  setState(() {
                                    isEditingProfile = false;
                                    // Reset controllers
                                    if (guardianProfile != null) {
                                      final profile = guardianProfile!;
                                      nameController.text = profile.name;
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
                            icon: const Icon(
                              Icons.edit,
                              color: AppTheme.primaryGreen,
                            ),
                            onPressed: () =>
                                setState(() => isEditingProfile = true),
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
                                hintText:
                                    l10n?.enterYourName ?? 'Enter your name',
                                controller: nameController,
                                enabled: true,
                              ),
                              SizedBox(height: AppTheme.spacingMD),
                              _buildProfileItem(
                                icon: Icons.email,
                                label: l10n?.email ?? 'Email',
                                value:
                                    guardianProfile?.email ??
                                    user?.email ??
                                    (l10n?.noEmail ?? 'No email'),
                              ),
                            ] else ...[
                              _buildProfileItem(
                                icon: Icons.person,
                                label: l10n?.name ?? 'Name',
                                value:
                                    guardianProfile?.name ??
                                    user?.displayName ??
                                    user?.email?.split('@')[0] ??
                                    'Guardian',
                              ),
                              const Divider(),
                              _buildProfileItem(
                                icon: Icons.email,
                                label: l10n?.email ?? 'Email',
                                value:
                                    guardianProfile?.email ??
                                    user?.email ??
                                    (l10n?.noEmail ?? 'No email'),
                              ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: AppTheme.borderRadiusMD,
                  ),
                  child: ExpansionTile(
                    leading: const Icon(
                      Icons.settings,
                      size: 36,
                      color: AppTheme.primaryGreen,
                    ),
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
                                LanguageService.languageNames[languageService
                                        .locale
                                        .languageCode] ??
                                    'English',
                              ),
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
                            const Divider(),
                            SwitchListTile(
                              secondary: Icon(
                                isDarkMode ? Icons.dark_mode : Icons.light_mode,
                              ),
                              title: const Text('Dark Mode'),
                              subtitle: const Text(
                                'Switch between light and dark theme',
                              ),
                              value: isDarkMode,
                              activeColor: AppTheme.primaryGreen,
                              onChanged: (val) {
                                setState(() {
                                  isDarkMode = val;
                                });
                                MyApp.themeModeNotifier.value = val
                                    ? ThemeMode.dark
                                    : ThemeMode.light;
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
                  shape: RoundedRectangleBorder(
                    borderRadius: AppTheme.borderRadiusMD,
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.location_on,
                      size: 36,
                      color: AppTheme.error,
                    ),
                    title: Text(l10n?.locationTracking ?? 'Location Tracking'),
                    subtitle: userLocation != null
                        ? Text(
                            l10n?.lastUpdated(
                                  _formatTimestamp(userLocation!['timestamp']),
                                ) ??
                                'Last updated: ${_formatTimestamp(userLocation!['timestamp'])}',
                          )
                        : Text(
                            l10n?.noLocationDataAvailable ??
                                'No location data available',
                          ),
                    trailing: IconButton(
                      icon: const Icon(Icons.map),
                      onPressed: () {
                        if (selectedUserId != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  MapScreen(userId: selectedUserId!),
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
                            builder: (context) =>
                                MapScreen(userId: selectedUserId!),
                          ),
                        );
                      }
                    },
                  ),
                ),
                SizedBox(height: AppTheme.spacingLG),

                // Device Battery
                Card(
                  elevation: AppTheme.elevationMedium,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppTheme.borderRadiusMD,
                  ),
                  child: Padding(
                    padding: AppTheme.paddingMD,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.battery_std,
                          size: 36,
                          color: AppTheme.warning,
                        ),
                        SizedBox(width: AppTheme.spacingMD),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Device Battery',
                                style: AppTheme.textStyleBodyLarge.copyWith(
                                  fontWeight: AppTheme.fontWeightBold,
                                ),
                              ),
                              SizedBox(height: AppTheme.spacingXS),
                              if (batteryLevel != null)
                                Text(
                                  l10n?.deviceBattery(batteryLevel) ??
                                      'Device Battery: $batteryLevel%',
                                  style: AppTheme.textStyleTitle.copyWith(
                                    fontWeight: AppTheme.fontWeightBold,
                                    color: batteryLevel < 20
                                        ? AppTheme.error
                                        : batteryLevel < 50
                                        ? AppTheme.warning
                                        : AppTheme.success,
                                  ),
                                )
                              else
                                Text(
                                  l10n?.noBatteryDataAvailable ??
                                      'No battery data available',
                                  style: AppTheme.textStyleBody.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              if (batteryUpdatedLabel != null)
                                Padding(
                                  padding: EdgeInsets.only(
                                    top: AppTheme.spacingXS,
                                  ),
                                  child: Text(
                                    batteryUpdatedLabel,
                                    style: AppTheme.textStyleCaption.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: AppTheme.spacingLG),

                // Guidance Manual
                _buildGuidanceManualCard(),
                SizedBox(height: AppTheme.spacingLG),

                // Message Inbox (SMS Alerts from Users)
                Card(
                  elevation: AppTheme.elevationMedium,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppTheme.borderRadiusMD,
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.inbox,
                      size: 36,
                      color: AppTheme.warning,
                    ),
                    title: const Text('Message Inbox'),
                    subtitle: const Text(
                      'View SMS alerts and messages from users.',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, size: 16),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const GuardianMessagesScreen(),
                          ),
                        );
                      },
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const GuardianMessagesScreen(),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: AppTheme.spacingLG),

                // Communication
                Card(
                  elevation: AppTheme.elevationMedium,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppTheme.borderRadiusMD,
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.message,
                      size: 36,
                      color: AppTheme.info,
                    ),
                    title: Text(l10n?.communication ?? 'Communication'),
                    subtitle: Text(
                      l10n?.sendMessageOrAlert ??
                          'Send a message or alert to the user.',
                    ),
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
                    onPressed: () => Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/',
                      (route) => false,
                    ),
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
