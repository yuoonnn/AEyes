import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../services/bluetooth_service.dart';
import '../services/openai_service.dart';
import '../services/database_service.dart';
import '../services/battery_service.dart';
import '../widgets/main_scaffold.dart';
import '../theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../services/ai_state.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import '../services/sms_service.dart';
import '../services/gps_callout_service.dart';
import '../services/location_search_service.dart';
import 'predefined_messages_screen.dart';

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
  final DatabaseService _databaseService = DatabaseService();
  final BatteryService _batteryService = BatteryService();
  final SMSService _smsService = SMSService();
  GPSCalloutService? _gpsCalloutService;
  LocationSearchService? _locationSearchService;
  Timer? _locationUpdateTimer;
  Position? _currentPosition;
  int _unreadMessageCount = 0;
  int? _phoneBatteryLevel;
  int? _esp32BatteryLevel;
  static bool _locationTrackingStarted = false; // Track if location tracking has been started globally
  static Position? _globalCurrentPosition; // Shared position across all screen instances

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
          // Trigger SMS alert to guardians
          _showSMSAlertDialog();
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
      widget.speechService!.onSpeechResult = (String text) async {
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
          // Try location-related commands
          await _handleLocationVoiceCommand(text);
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

    // Listen for unread messages
    _listenForUnreadMessages();
    
    // Start battery monitoring
    _startBatteryMonitoring();
    
    // Initialize GPS callout service with periodic location updates (every 3 minutes)
    // Only start location tracking once globally, not every time screen is created
    if (!_locationTrackingStarted) {
      const mapboxApiKey = 'pk.eyJ1IjoiY2hyaXNzZWdncyIsImEiOiJjbWh4aW4wbGkwMXA4MnFzaHVjaGc3NDgwIn0.I51_0mt0LivtIciiYF9jSw'; // Add your Mapbox API key here
      if (widget.ttsService != null && mapboxApiKey != 'YOUR_MAPBOX_API_KEY' && mapboxApiKey.isNotEmpty) {
        _gpsCalloutService = GPSCalloutService(widget.ttsService!, mapboxApiKey: mapboxApiKey);
        _locationSearchService = LocationSearchService(
          mapboxApiKey: mapboxApiKey,
          ttsService: widget.ttsService!,
        );
        // Start periodic location updates with GPS callouts (every 3 minutes)
        _startPeriodicLocationUpdates();
        _locationTrackingStarted = true;
        print('✅ Location tracking started (once on app start)');
      } else if (widget.ttsService != null) {
        print('⚠️ Mapbox API key not set. GPS callouts disabled.');
      }
    } else {
      // If tracking already started, use the global position (no GPS call)
      if (_globalCurrentPosition != null) {
        setState(() {
          _currentPosition = _globalCurrentPosition;
        });
      }
    }
  }
  
  /// Check if a command is a location command (should NOT go to OpenAI)
  bool _isLocationCommand(String command) {
    final lowerCommand = command.toLowerCase().trim();
    return lowerCommand.contains('find ') ||
        lowerCommand.contains('where is ') ||
        lowerCommand.contains('nearby') ||
        lowerCommand.contains('around me') ||
        lowerCommand.contains('what\'s near') ||
        lowerCommand.contains('my location') ||
        lowerCommand.contains('where am i') ||
        lowerCommand.contains('current location');
  }
  
  /// Handle location-related voice commands
  Future<void> _handleLocationVoiceCommand(String command) async {
    if (_locationSearchService == null || _currentPosition == null) {
      if (widget.ttsService != null) {
        await widget.ttsService!.speak('Location services not available');
      }
      return;
    }
    
    final lowerCommand = command.toLowerCase().trim();
    
    // "What's around me?" or "Nearby places"
    if (lowerCommand.contains('around me') || 
        lowerCommand.contains('nearby') ||
        lowerCommand.contains('what\'s near')) {
      await _locationSearchService!.announceNearbyPlaces(
        position: _currentPosition!,
        limit: 3,
      );
    }
    // "Find nearby restaurants" or "Nearby pharmacy"
    else if (lowerCommand.contains('nearby restaurant')) {
      await _locationSearchService!.announceNearbyPlaces(
        position: _currentPosition!,
        category: 'restaurant',
        limit: 3,
      );
    }
    else if (lowerCommand.contains('nearby pharmacy') || lowerCommand.contains('nearby drugstore')) {
      await _locationSearchService!.announceNearbyPlaces(
        position: _currentPosition!,
        category: 'pharmacy',
        limit: 3,
      );
    }
    else if (lowerCommand.contains('nearby hospital') || lowerCommand.contains('nearby clinic')) {
      await _locationSearchService!.announceNearbyPlaces(
        position: _currentPosition!,
        category: 'hospital',
        limit: 3,
      );
    }
    else if (lowerCommand.contains('nearby store') || lowerCommand.contains('nearby shop')) {
      await _locationSearchService!.announceNearbyPlaces(
        position: _currentPosition!,
        category: 'store',
        limit: 3,
      );
    }
    // "Find [place name]" or "Where is [place]"
    else if (lowerCommand.startsWith('find ') || lowerCommand.startsWith('where is ')) {
      String query = lowerCommand
          .replaceFirst('find ', '')
          .replaceFirst('where is ', '')
          .trim();
      
      if (query.isNotEmpty) {
        await _locationSearchService!.searchAndAnnounce(query, _currentPosition);
      }
    }
    // "What's my location?" or "Where am I?"
    else if (lowerCommand.contains('my location') || 
             lowerCommand.contains('where am i') ||
             lowerCommand.contains('current location')) {
      final details = await _locationSearchService!.getLocationDetails(_currentPosition!);
      if (details != null && widget.ttsService != null) {
        final name = details['name'] as String? ?? 'Unknown location';
        final address = details['fullAddress'] as String? ?? '';
        await widget.ttsService!.speak('You are at $name. $address');
      }
    }
  }
  
  /// Start periodic location updates (every 3 minutes) with GPS callout
  /// This runs only once when the app starts, not on every navigation
  Future<void> _startPeriodicLocationUpdates() async {
    if (_gpsCalloutService == null) return;
    
    // Check location permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('Location permission denied - Periodic updates disabled');
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      print('Location permission denied forever - Periodic updates disabled');
      return;
    }
    
    // Get initial position once on app start and save it
    try {
      final initialPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      // Update global and local position
      _globalCurrentPosition = initialPosition;
      if (mounted) {
        setState(() {
          _currentPosition = initialPosition;
        });
      }
      
      // Save initial location to Firestore
      await _databaseService.saveLocation(
        latitude: initialPosition.latitude,
        longitude: initialPosition.longitude,
        accuracy: initialPosition.accuracy,
      );
      print('📍 Initial location saved to Firestore: ${initialPosition.latitude}, ${initialPosition.longitude}');
    } catch (e) {
      print('Error getting initial position: $e');
    }
    
    // Start GPS callout service (handles periodic updates internally - every 3 minutes)
    await _gpsCalloutService!.start();
    
    // Also save location to Firestore every 3 minutes (same interval)
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(const Duration(minutes: 3), (timer) async {
      // Check if widget is still mounted (screen might be disposed)
      // Since this is a global timer, we need to check differently
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        
        // Update global position (shared across all screen instances)
        _globalCurrentPosition = position;
        
        // Update current position (if screen is still mounted)
        if (mounted) {
          setState(() {
            _currentPosition = position;
          });
        }
        
        await _databaseService.saveLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
        );
        print('📍 Location saved to Firestore (every 3 min): ${position.latitude}, ${position.longitude}');
      } catch (e) {
        print('Error saving location: $e');
      }
    });
  }
  
  Future<void> _showSMSAlertDialog() async {
    try {
      // Get predefined messages
      final messages = await _smsService.getPredefinedMessages();
      
      if (messages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No predefined messages found. Please add messages in Settings.'),
            backgroundColor: AppTheme.warning,
          ),
        );
        return;
      }
      
      // Show dialog to select message
      final selectedMessage = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Send SMS Alert'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: messages.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(messages[index]),
                  onTap: () => Navigator.pop(context, messages[index]),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                // Navigate to edit messages screen
                Navigator.pop(context);
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PredefinedMessagesScreen(),
                  ),
                );
                if (result == true && mounted) {
                  _showSMSAlertDialog(); // Refresh dialog
                }
              },
              child: const Text('Edit Messages'),
            ),
          ],
        ),
      );
      
      if (selectedMessage != null && mounted) {
        // Send SMS to all guardians
        final results = await _smsService.sendSMSToAllGuardians(selectedMessage);
        
        if (mounted) {
          final successCount = results.values.where((v) => v).length;
          final totalCount = results.length;
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                totalCount > 0
                    ? 'SMS sent to $successCount of $totalCount guardians'
                    : 'No guardians with phone numbers found',
              ),
              backgroundColor: successCount > 0 ? AppTheme.success : AppTheme.warning,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending SMS: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
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

  @override
  void dispose() {
    _batteryService.dispose();
    _locationUpdateTimer?.cancel();
    _gpsCalloutService?.dispose();
    super.dispose();
  }

  /// Manually refresh location
  Future<void> _refreshLocation() async {
    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission denied'),
                backgroundColor: AppTheme.error,
              ),
            );
          }
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission denied forever. Please enable in settings.'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
        return;
      }
      
      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      // Update global and local position
      _globalCurrentPosition = position;
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
      
      // Save to Firestore
      await _databaseService.saveLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
      );
      
      // Trigger GPS callout if service is available
      if (_gpsCalloutService != null) {
        await _gpsCalloutService!.announceLocation(position);
      }
      
      print('📍 Location manually refreshed: ${position.latitude}, ${position.longitude}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location refreshed'),
            backgroundColor: AppTheme.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error refreshing location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing location: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Widget _buildLocationTrackingStatus() {
    // Check if location tracking is actually active
    final isActive = _locationTrackingStarted && _gpsCalloutService != null;
    
    return Card(
      elevation: AppTheme.elevationHigh,
      shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadiusLG),
      child: Padding(
        padding: AppTheme.paddingMD,
        child: Row(
          children: [
            Icon(
              isActive ? Icons.location_on : Icons.location_off,
              color: isActive ? AppTheme.success : AppTheme.error,
              size: 28,
            ),
            SizedBox(width: AppTheme.spacingMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isActive 
                        ? 'Location Updates: ACTIVE' 
                        : 'Location Updates: INACTIVE',
                    style: AppTheme.textStyleSubtitle.copyWith(
                      fontWeight: AppTheme.fontWeightBold,
                      color: isActive ? AppTheme.success : AppTheme.error,
                    ),
                  ),
                  SizedBox(height: AppTheme.spacingXS),
                  Text(
                    isActive
                        ? 'Location updates every 3 minutes with GPS callouts'
                        : _locationTrackingStarted
                            ? 'Initializing location services...'
                            : 'Mapbox API key not configured',
                    style: AppTheme.textStyleCaption,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshLocation,
              tooltip: 'Refresh Location',
              color: AppTheme.primaryGreen,
            ),
          ],
        ),
      ),
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