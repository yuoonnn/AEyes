import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/bluetooth_service.dart';
import '../services/openai_service.dart';
import '../services/background_location_service.dart';
import '../services/database_service.dart';
import '../services/battery_service.dart';
import '../widgets/main_scaffold.dart';
import '../theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../services/ai_state.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';

class HomeScreen extends StatefulWidget {
  final AppBluetoothService bluetoothService;
  final OpenAIService openAIService;
  final SpeechService? speechService;
  final TTSService? ttsService;

  const HomeScreen({
    Key? key,
    required this.bluetoothService,
    required this.openAIService,
    this.speechService,
    this.ttsService,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  double _opacity = 0.0;
  String analysisResult = "Waiting for image...";
  final BackgroundLocationService _backgroundLocationService = BackgroundLocationService();
  final DatabaseService _databaseService = DatabaseService();
  final BatteryService _batteryService = BatteryService();
  int _unreadMessageCount = 0;
  int? _phoneBatteryLevel;
  int? _esp32BatteryLevel;

  @override
  void initState() {
    super.initState();

    // Fade-in animation
    Future.delayed(const Duration(milliseconds: 200), () {
      setState(() => _opacity = 1.0);
    });

    // Image handling is global; don't override callbacks here.

    // Hook into button press events from ESP32
    widget.bluetoothService.onButtonPressed = (String buttonData) {
      if (!mounted) return;
      
      // Handle button press - buttonData could be "0", "1", "2" or action strings like "capture", "help"
      print('Button pressed: $buttonData');
      
      // Example: Handle different button actions
      switch (buttonData.trim()) {
        case '0':
        case 'capture':
          // Trigger image capture/analysis
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Capture button pressed')),
          );
          break;
        case '1':
        case 'help':
          // Trigger help/emergency
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Help button pressed')),
          );
          break;
        case '2':
        case 'settings':
          // Navigate to settings
          Navigator.pushNamed(context, '/settings');
          break;
        default:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Button $buttonData pressed')),
          );
      }
    };

    // Voice commands from ESP32 are now handled globally in main.dart
    // They are automatically paired with the next image capture
    // No need to handle them here anymore

    // Hook into raw voice command audio (if ESP32 sends audio instead of text)
    widget.bluetoothService.onVoiceCommandReceived = (Uint8List audioData) {
      if (!mounted) return;
      
      print('Voice command audio received: ${audioData.length} bytes');
      // Here you could process the audio data with a speech-to-text service
      // For now, just log it
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Voice audio received: ${audioData.length} bytes')),
      );
    };

    // Set up phone voice control (if speech service is available)
    if (widget.speechService != null) {
      widget.speechService!.onSpeechResult = (String text) {
        if (!mounted) return;
        
        print('Voice command from phone: $text');
        final lowerCommand = text.toLowerCase().trim();
        
        // Process voice commands
        if (lowerCommand.contains('help') || lowerCommand.contains('emergency')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Emergency command detected'),
              backgroundColor: Colors.red,
            ),
          );
        } else if (lowerCommand.contains('capture') || lowerCommand.contains('analyze') || lowerCommand.contains('take picture')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Capture command received')),
          );
        } else if (lowerCommand.contains('settings')) {
          Navigator.pushNamed(context, '/settings');
        } else if (lowerCommand.contains('home')) {
          // Already on home, do nothing
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Voice command: $text')),
          );
        }
      };
      
      widget.speechService!.onError = (String error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voice error: $error'),
            backgroundColor: Colors.orange,
          ),
        );
      };
    }

    // Start background location tracking
    _startLocationTracking();
    
    // Listen for unread messages
    _listenForUnreadMessages();
    
    // Start battery monitoring
    _startBatteryMonitoring();
  }
  
  Future<void> _startBatteryMonitoring() async {
    // Start phone battery monitoring
    await _batteryService.startMonitoringPhoneBattery();
    
    // Get initial battery levels immediately
    setState(() {
      _phoneBatteryLevel = _batteryService.phoneBatteryLevel;
      _esp32BatteryLevel = _batteryService.esp32BatteryLevel;
    });
    
    // Listen for phone battery updates
    _batteryService.phoneBatteryStream.listen((level) {
      if (mounted) {
        setState(() {
          _phoneBatteryLevel = level;
        });
      }
    });
    
    // Listen for ESP32 battery updates
    _batteryService.esp32BatteryStream.listen((level) {
      if (mounted) {
        setState(() {
          _esp32BatteryLevel = level;
        });
      }
    });
    
    // Check if ESP32 is connected and start monitoring
    if (widget.bluetoothService.isConnected) {
      final device = widget.bluetoothService.connectedDevice;
      if (device != null) {
        await _batteryService.startMonitoringESP32Battery(device);
        // Update ESP32 battery after starting monitoring
        if (mounted) {
          setState(() {
            _esp32BatteryLevel = _batteryService.esp32BatteryLevel;
          });
        }
      }
    }
  }
  
  void _listenForUnreadMessages() {
    try {
      _databaseService.getMessagesStream().listen((snapshot) {
        if (mounted) {
          final unreadCount = snapshot.docs
              .where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                if (data['direction'] != 'guardian_to_user') return false;
                // Handle both bool and int (0/1) for is_read
                final isReadValue = data['is_read'];
                final isRead = isReadValue is bool 
                    ? isReadValue 
                    : (isReadValue is int ? isReadValue != 0 : false);
                return !isRead;
              })
              .length;
          setState(() {
            _unreadMessageCount = unreadCount;
          });
        }
      });
    } catch (e) {
      print('Error listening for messages: $e');
    }
  }

  Future<void> _startLocationTracking() async {
    // Only start tracking if user is logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final started = await _backgroundLocationService.startTracking();
      
      if (started && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Location sharing started with guardians'),
            backgroundColor: AppTheme.success,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Location sharing failed - check permissions'),
            backgroundColor: AppTheme.warning,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _batteryService.dispose();
    // Stop location tracking when screen is disposed
    _backgroundLocationService.stopTracking();
    _backgroundLocationService.dispose(); // Dispose the ValueNotifier
    super.dispose();
  }

  Widget _buildLocationTrackingStatus() {
  return ValueListenableBuilder<bool>(
    valueListenable: _backgroundLocationService.isTracking,
    builder: (context, isTracking, child) {
      return Card(
        elevation: AppTheme.elevationHigh,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadiusLG),
        child: Padding(
          padding: AppTheme.paddingMD,
          child: Row(
            children: [
              Icon(
                isTracking ? Icons.location_on : Icons.location_off,
                color: isTracking ? AppTheme.success : AppTheme.error,
                size: 28,
              ),
              SizedBox(width: AppTheme.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isTracking ? 'Location Sharing: ACTIVE' : 'Location Sharing: INACTIVE',
                      style: AppTheme.textStyleSubtitle.copyWith(
                        fontWeight: AppTheme.fontWeightBold,
                        color: isTracking ? AppTheme.success : AppTheme.error,
                      ),
                    ),
                    SizedBox(height: AppTheme.spacingXS),
                    Text(
                      isTracking 
                          ? 'Your location is being shared with guardians' 
                          : 'Tap to start sharing location with guardians',
                      style: AppTheme.textStyleCaption,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _startLocationTracking,
                tooltip: 'Retry Location Tracking',
              ),
            ],
          ),
        ),
      );
    },
  );
}

  Widget _buildBatteryStatus() {
    return Card(
      elevation: AppTheme.elevationHigh,
      shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadiusLG),
      child: Padding(
        padding: AppTheme.paddingMD,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.battery_std, size: 28, color: AppTheme.primaryGreen),
                SizedBox(width: AppTheme.spacingMD),
                Text(
                  'Battery Status',
                  style: AppTheme.textStyleTitle.copyWith(
                    fontWeight: AppTheme.fontWeightBold,
                  ),
                ),
              ],
            ),
            SizedBox(height: AppTheme.spacingMD),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBatteryIndicator('Phone', _phoneBatteryLevel, Icons.smartphone),
                if (_esp32BatteryLevel != null)
                  _buildBatteryIndicator('Eyeglass', _esp32BatteryLevel, Icons.visibility),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatteryIndicator(String label, int? level, IconData icon) {
    Color batteryColor = AppTheme.success;
    if (level != null) {
      if (level < 20) {
        batteryColor = AppTheme.error;
      } else if (level < 50) {
        batteryColor = AppTheme.warning;
      }
    }
    
    return Column(
      children: [
        Icon(icon, size: 32, color: batteryColor),
        SizedBox(height: AppTheme.spacingSM),
        Text(
          label,
          style: AppTheme.textStyleCaption.copyWith(
            fontWeight: AppTheme.fontWeightBold,
          ),
        ),
        SizedBox(height: AppTheme.spacingXS),
        Text(
          level != null ? '$level%' : 'N/A',
          style: AppTheme.textStyleSubtitle.copyWith(
            fontSize: AppTheme.fontSizeXXL,
            fontWeight: AppTheme.fontWeightBold,
            color: batteryColor,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      currentIndex: 0,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Image.asset('assets/AEye Logo.png', height: 32),
              SizedBox(width: AppTheme.spacingMD),
              Text(
                'AEyes Dashboard',
                style: AppTheme.textStyleTitle.copyWith(
                  fontWeight: AppTheme.fontWeightBold,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context,
                '/',
                (route) => false,
              ),
            ),
          ],
        ),
        body: AnimatedOpacity(
          opacity: _opacity,
          duration: const Duration(milliseconds: 800),
          child: SingleChildScrollView(
            padding: AppTheme.paddingLG,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Text(
                  'Welcome back!',
                  style: AppTheme.textStyleHeadline2.copyWith(
                    fontWeight: AppTheme.fontWeightBold,
                  ),
                ),
                SizedBox(height: AppTheme.spacingSM),
                Text(
                  "Here's your quick access dashboard.",
                  style: AppTheme.textStyleBodyLarge.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                SizedBox(height: AppTheme.spacingXL),
                Card(
                  elevation: AppTheme.elevationXHigh,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppTheme.borderRadiusLG,
                  ),
                  color: AppTheme.primaryWithOpacity(0.08),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.accentGreen,
                      child: const Icon(
                        Icons.account_circle,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      FirebaseAuth.instance.currentUser?.displayName ?? 
                      FirebaseAuth.instance.currentUser?.email?.split('@')[0] ?? 
                      'User',
                      style: AppTheme.textStyleTitle.copyWith(
                        fontWeight: AppTheme.fontWeightBold,
                      ),
                    ),
                    subtitle: Text(
                      FirebaseAuth.instance.currentUser?.email ?? 'No email',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, color: AppTheme.primaryGreen),
                      onPressed: () => Navigator.pushNamed(context, '/profile'),
                      tooltip: 'Edit Profile',
                    ),
                  ),
                ),
                SizedBox(height: AppTheme.spacingXL),

                // Location Tracking Status
                _buildLocationTrackingStatus(),
                SizedBox(height: AppTheme.spacingMD),
                
                // Battery Status
                _buildBatteryStatus(),
                SizedBox(height: AppTheme.spacingMD),

                // Latest AI Analysis (replaces Hazard Guidance)
                Consumer<AIState>(builder: (context, ai, _) {
                  final analysis = ai.lastAnalysis;
                  return Card(
                  elevation: AppTheme.elevationHigh,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppTheme.borderRadiusLG,
                  ),
                  child: Padding(
                    padding: AppTheme.paddingMD,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.analytics_outlined,
                              color: AppTheme.primaryGreen,
                              size: 28,
                            ),
                            SizedBox(width: AppTheme.spacingSM),
                            Expanded(
                              child: Text(
                                'Latest AI Analysis',
                                style: AppTheme.textStyleTitle.copyWith(
                                  fontWeight: AppTheme.fontWeightBold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pushReplacementNamed(context, '/analysis'),
                              child: const Text('Open'),
                            ),
                          ],
                        ),
                        SizedBox(height: AppTheme.spacingMD),
                        Text(
                          analysis ?? 'Waiting for image...',
                          style: AppTheme.textStyleBodyLarge,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
                }),

                SizedBox(height: AppTheme.spacingXL),
                // Single quick action: Messages (others are in navbar)
                Card(
                  elevation: AppTheme.elevationHigh,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppTheme.borderRadiusLG,
                  ),
                  child: ListTile(
                    onTap: () => Navigator.pushNamed(context, '/messages'),
                    leading: const Icon(Icons.message, color: AppTheme.primaryGreen),
                    title: const Text('Messages'),
                    trailing: _unreadMessageCount > 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.error,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _unreadMessageCount > 9 ? '9+' : '$_unreadMessageCount',
                              style: AppTheme.textStyleCaption.copyWith(color: Colors.white),
                            ),
                          )
                        : const Icon(Icons.chevron_right),
                  ),
                ),
                SizedBox(height: AppTheme.spacingXL),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedQuickActionCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AnimatedQuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  State<_AnimatedQuickActionCard> createState() =>
      _AnimatedQuickActionCardState();
}

class _AnimatedQuickActionCardState extends State<_AnimatedQuickActionCard>
    with SingleTickerProviderStateMixin {
  double _scale = 1.0;

  void _onTapDown(TapDownDetails details) {
    setState(() => _scale = 0.95);
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _scale = 1.0);
  }

  void _onTapCancel() {
    setState(() => _scale = 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        child: Card(
          color: widget.color.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: AppTheme.borderRadiusLG,
          ),
          elevation: AppTheme.elevationLow,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 40, color: widget.color),
                SizedBox(height: AppTheme.spacingMD),
                Text(
                  widget.label,
                  style: AppTheme.textStyleBodyLarge.copyWith(
                    fontWeight: AppTheme.fontWeightBold,
                    color: widget.color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}