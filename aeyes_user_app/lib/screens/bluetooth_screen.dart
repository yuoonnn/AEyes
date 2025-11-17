import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import '../widgets/custom_button.dart';
import '../services/bluetooth_service.dart';
import '../services/openai_service.dart';
import '../services/tts_service.dart';
import '../services/foreground_service.dart';
import '../widgets/main_scaffold.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../services/ai_state.dart';

class BluetoothScreen extends StatefulWidget {
  final AppBluetoothService bluetoothService; // Changed to AppBluetoothService
  final OpenAIService openAIService;
  final TTSService? ttsService;

  const BluetoothScreen({
    Key? key,
    required this.bluetoothService,
    required this.openAIService,
    this.ttsService,
  }) : super(key: key);

  @override
  State<BluetoothScreen> createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends State<BluetoothScreen> {
  late final AppBluetoothService
  _bluetoothService; // Changed to AppBluetoothService
  late final TTSService _ttsService;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  List<BluetoothDevice> devices = [];
  BluetoothDevice? connectedDevice;
  bool isScanning = false;
  String status = 'Disconnected';

  bool isBluetoothOn = true;
  bool hasPermission = true;

  // OpenAI & TTS state
  bool isProcessingImage = false;
  String? openAIResponse;
  bool isTTSPlaying = false;

  // Debug logs from BLE service
  final List<String> _logs = [];
  StreamSubscription<String>? _logSub;
  final int _maxLogs = 500;

  @override
  void initState() {
    super.initState();

    _bluetoothService = widget.bluetoothService;
    _ttsService = widget.ttsService ?? TTSService(); // Use provided TTS or create new if not provided

    // Seed UI with current connection state if already connected
    final existing = _bluetoothService.connectedDevice;
    if (existing != null) {
      connectedDevice = existing;
      status = 'Connected to ${existing.platformName}';
      _subscribeToConnection(existing);
    }

    // Subscribe to BLE logs
    _logSub = _bluetoothService.logs.listen((line) {
      if (!mounted) return;
      setState(() {
        _logs.add(line);
        if (_logs.length > _maxLogs) {
          _logs.removeRange(0, _logs.length - _maxLogs);
        }
      });
    });

    // Global image handler is registered at app start; UI reacts via AIState.

    _monitorBluetoothStatus();
    _requestPermissions();
  }

  /// Request necessary Bluetooth permissions
  Future<void> _requestPermissions() async {
    if (await Permission.bluetoothConnect.request().isGranted &&
        await Permission.bluetoothScan.request().isGranted) {
      setState(() {
        hasPermission = true;
      });
      // Start foreground service now that permissions are granted
      await ForegroundServiceController.startAfterPermissionsGranted();
    } else {
      setState(() {
        hasPermission = false;
      });
      _showBluetoothAlert(
        "Bluetooth permissions are required to connect to ESP32",
      );
    }
  }

  /// Monitor Bluetooth adapter state
  void _monitorBluetoothStatus() {
    FlutterBluePlus.adapterState.listen((state) {
      setState(() {
        isBluetoothOn = state == BluetoothAdapterState.on;
      });

      if (!isBluetoothOn) {
        _showBluetoothAlert(
          "Bluetooth is turned OFF. Please enable it to connect to ESP32.",
        );
      }
    });
  }

  void _showBluetoothAlert(String message) async {
    if (!mounted) return;

    await _ttsService.speak(message);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleStyle = theme.textTheme.titleLarge?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ) ??
        TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        );
    final contentStyle = theme.textTheme.bodyMedium?.copyWith(
          color: isDark ? Colors.grey[300] : Colors.black87,
        ) ??
        TextStyle(
          color: isDark ? Colors.grey[300] : Colors.black87,
          fontSize: 16,
        );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Bluetooth Notice",
          style: titleStyle,
        ),
        content: Text(
          message,
          style: contentStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
            ),
            child: Text(
              "OK",
              style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  /// Scan for BLE devices
  Future<void> _scanDevices() async {
    if (!isBluetoothOn || !hasPermission) {
      _showBluetoothAlert(
        "Please enable Bluetooth and grant permissions first",
      );
      return;
    }

    setState(() {
      isScanning = true;
      devices = [];
      status = 'Scanning for ESP32 devices...';
    });

    try {
      final scanStream = _bluetoothService.scanForDevices(
        timeout: const Duration(seconds: 10),
      );

      scanStream.listen(
        (List<BluetoothDevice> foundDevices) {
          if (mounted) {
            setState(() {
              devices = foundDevices;
              status = 'Found ${devices.length} devices';
            });
          }
        },
        onDone: () {
          if (mounted) {
            setState(() {
              isScanning = false;
              if (devices.isEmpty) {
                status = 'No BLE devices found';
              } else {
                status = 'Scan complete - Found ${devices.length} devices';
              }
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          isScanning = false;
          status = 'Scan failed: $e';
        });
      }
      _showBluetoothAlert("Scan failed: $e");
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    setState(() {
      status = 'Connecting to ${device.platformName}...';
    });

    final success = await _bluetoothService.connect(device);

    if (mounted) {
      setState(() {
        if (success) {
          connectedDevice = device;
          status = 'Connected to ${device.platformName}';
          _subscribeToConnection(device);
        } else {
          status = 'Failed to connect to ${device.platformName}';
          connectedDevice = null;
        }
      });
    }
  }

  Future<void> _disconnect() async {
    setState(() {
      status = 'Disconnecting...';
    });

    await _bluetoothService.disconnect();

    if (mounted) {
      setState(() {
        _connSub?.cancel();
        _connSub = null;
        connectedDevice = null;
        status = 'Disconnected';
        openAIResponse = null;
        isProcessingImage = false;
      });
    }
  }

  void _readAloud() async {
    if (openAIResponse == null) return;
    setState(() {
      isTTSPlaying = true;
    });
    await _ttsService.speak(openAIResponse!);
    if (mounted) {
      setState(() {
        isTTSPlaying = false;
      });
    }
  }

  Color _statusColor() {
    if (status.toLowerCase().contains('connected')) return Colors.green;
    if (status.toLowerCase().contains('scanning')) return Colors.blue;
    if (status.toLowerCase().contains('failed')) return Colors.red;
    return Colors.grey;
  }

  Widget _bluetoothBanner() {
    if (!hasPermission) {
      return _buildBanner(
        Icons.warning_amber,
        'Bluetooth permissions required. Please allow Bluetooth access in app settings.',
        Colors.orange,
      );
    }

    if (!isBluetoothOn) {
      return _buildBanner(
        Icons.bluetooth_disabled,
        'Bluetooth is OFF. Please turn it ON to connect to ESP32.',
        Colors.red,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildBanner(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      currentIndex: 2,
      child: PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          if (!didPop) {
            Navigator.pushReplacementNamed(context, '/home');
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Bluetooth - ESP32 Connection'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                tooltip: 'Open Logs',
                icon: const Icon(Icons.list_alt),
                onPressed: _openLogScreen,
              ),
            ],
          ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              _bluetoothBanner(),

              // Status Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ESP32 Connection Status',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _statusColor(),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(status)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Scan Button
              CustomButton(
                label: isScanning ? 'Scanning...' : 'Scan for ESP32 Devices',
                onPressed: isScanning ? () {} : _scanDevices,
                color: Theme.of(context).colorScheme.primary,
                textColor: Colors.white,
              ),

              const SizedBox(height: 16),

              // Devices List
              if (devices.isNotEmpty) ...[
                const Text(
                  'Found Devices:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ...devices.map(
                  (device) => Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: const Icon(Icons.memory, color: Colors.blue),
                      title: Text(
                        device.platformName.isNotEmpty
                            ? device.platformName
                            : 'Unknown ESP32',
                      ),
                      subtitle: Text(
                        'ID: ${device.remoteId.toString().substring(0, 8)}...',
                      ),
                      trailing: connectedDevice?.remoteId == device.remoteId
                          ? IconButton(
                              icon: const Icon(
                                Icons.link_off,
                                color: Colors.red,
                              ),
                              onPressed: _disconnect,
                            )
                          : IconButton(
                              icon: const Icon(Icons.link, color: Colors.green),
                              onPressed: () => _connectToDevice(device),
                            ),
                    ),
                  ),
                ),
              ],

              // Connection Info
              if (connectedDevice != null) ...[
                const SizedBox(height: 24),
                Card(
                  color: Colors.green.withOpacity(0.05),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '✅ Connected to ESP32',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Device: ${connectedDevice!.platformName}'),
                        Text('ID: ${connectedDevice!.remoteId}'),
                        const SizedBox(height: 16),
                        CustomButton(
                          label: 'Disconnect ESP32',
                          onPressed: _disconnect,
                          color: Colors.red,
                          textColor: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),

                // Image Processing Section
                const SizedBox(height: 24),
                _buildImageProcessingCard(),

                // Debug Log Section
                const SizedBox(height: 24),
                _buildLogCard(),
              ],
            ],
          ),
        ),
        ),
      ),
    );
  }

  void _openLogScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _LogScreen(
          bluetoothService: _bluetoothService,
          initialLines: List<String>.from(_logs),
        ),
      ),
    );
  }

  Widget _buildLogCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🧪 Debug Log (ESP32 ↔ App)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(8),
              ),
              child: _logs.isEmpty
                  ? const Text('No logs yet...')
                  : Scrollbar(
                      child: ListView.builder(
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          final line = _logs[index];
                          return Text(
                            line,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                CustomButton(
                  label: 'Clear Log',
                  onPressed: () {
                    setState(() {
                      _logs.clear();
                    });
                  },
                  color: Colors.grey,
                  textColor: Colors.white,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageProcessingCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📸 Live Image Processing',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            const Text('Waiting for images from ESP32 camera...'),
            const SizedBox(height: 16),

            // Reflect global AI analysis here
            Builder(
              builder: (context) {
                final ai = Provider.of<AIState>(context);
                final analysis = ai.lastAnalysis;
                if (analysis == null) {
                  return const SizedBox.shrink();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI Analysis:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Text(analysis),
                    ),
                    const SizedBox(height: 16),
                    CustomButton(
                      label: isTTSPlaying ? 'Reading...' : '🔊 Read Aloud',
                      onPressed: isTTSPlaying ? () {} : _readAloud,
                      color: Colors.blue,
                      textColor: Colors.white,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _subscribeToConnection(BluetoothDevice device) {
    _connSub?.cancel();
    _connSub = device.connectionState.listen((s) {
      if (!mounted) return;
      setState(() {
        if (s == BluetoothConnectionState.connected) {
          connectedDevice = device;
          status = 'Connected to ${device.platformName}';
        } else if (s == BluetoothConnectionState.disconnected) {
          connectedDevice = null;
          status = 'Disconnected';
        }
      });
    });
  }

  @override
  void dispose() {
    _logSub?.cancel();
    _connSub?.cancel();
    super.dispose();
  }
}

class _LogScreen extends StatefulWidget {
  final AppBluetoothService bluetoothService;
  final List<String> initialLines;

  const _LogScreen({
    Key? key,
    required this.bluetoothService,
    required this.initialLines,
  }) : super(key: key);

  @override
  State<_LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<_LogScreen> {
  final List<String> _lines = [];
  StreamSubscription<String>? _sub;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _lines.addAll(widget.initialLines);
    _sub = widget.bluetoothService.logs.listen((line) {
      if (!mounted) return;
      setState(() {
        _lines.add(line);
      });
      // Auto-scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Debug Log'),
        actions: [
          IconButton(
            tooltip: 'Copy All',
            icon: const Icon(Icons.copy),
            onPressed: () {
              final text = _lines.join('\n');
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Log copied to clipboard')),
              );
            },
          ),
          IconButton(
            tooltip: 'Clear',
            icon: const Icon(Icons.clear_all),
            onPressed: () {
              setState(() {
                _lines.clear();
              });
            },
          ),
        ],
      ),
      body: Container(
        color: Colors.black,
        child: ListView.builder(
          controller: _scrollController,
          itemCount: _lines.length,
          itemBuilder: (context, index) {
            final line = _lines[index];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                line,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
