import 'package:flutter/material.dart';
import '../widgets/custom_button.dart';
import '../services/bluetooth_service.dart';
import '../services/openai_service.dart';
import '../services/tts_service.dart';
import '../widgets/main_scaffold.dart';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as flutter_blue;
import 'package:permission_handler/permission_handler.dart';

class BluetoothScreen extends StatefulWidget {
  final BluetoothService bluetoothService;
  final OpenAIService openAIService;

  const BluetoothScreen({
    Key? key,
    required this.bluetoothService,
    required this.openAIService,
  }) : super(key: key);

  @override
  State<BluetoothScreen> createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends State<BluetoothScreen> {
  late final BluetoothService _bluetoothService;
  late final OpenAIService _openAIService;
  final TTSService _ttsService = TTSService();

  List<String> devices = [];
  String? connectedDevice;
  bool isScanning = false;
  String status = 'Disconnected';

  bool isBluetoothOn = true;
  bool hasPermission = true;

  // OpenAI & TTS state
  bool isProcessingImage = false;
  String? openAIResponse;
  bool isTTSPlaying = false;

  @override
  void initState() {
    super.initState();

    _bluetoothService = widget.bluetoothService;
    _openAIService = widget.openAIService;

    // 🔗 Listen for incoming images from ESP32
    _bluetoothService.onImageReceived = (Uint8List imageBytes) async {
      setState(() {
        isProcessingImage = true;
        openAIResponse = null;
      });

      try {
        final response = await _openAIService.analyzeImage(imageBytes);
        setState(() {
          openAIResponse = response;
        });
      } catch (e) {
        setState(() {
          openAIResponse = "Error: $e";
        });
      } finally {
        setState(() {
          isProcessingImage = false;
        });
      }
    };

    _monitorBluetoothStatus();
  }

  /// 🔍 Monitors Bluetooth state & permission changes
  void _monitorBluetoothStatus() {
    flutter_blue.FlutterBluePlus.adapterState.listen((state) async {
      final scanStatus = await Permission.bluetoothScan.status;
      final connectStatus = await Permission.bluetoothConnect.status;
      final locationStatus = await Permission.location.status;
      
      final hasAllPermissions = scanStatus.isGranted && 
                                connectStatus.isGranted && 
                                locationStatus.isGranted;
      
      setState(() {
        isBluetoothOn = state == flutter_blue.BluetoothAdapterState.on;
        hasPermission = hasAllPermissions;
      });

      if (!isBluetoothOn) {
        _showBluetoothAlert("Bluetooth is turned OFF. Please enable it.");
      } else if (!hasAllPermissions) {
        _requestBluetoothPermissions();
      }
    });
  }

  /// Request Bluetooth permissions
  Future<void> _requestBluetoothPermissions() async {
    final scanStatus = await Permission.bluetoothScan.request();
    final connectStatus = await Permission.bluetoothConnect.request();
    final locationStatus = await Permission.location.request();
    
    setState(() {
      hasPermission = scanStatus.isGranted && 
                     connectStatus.isGranted && 
                     locationStatus.isGranted;
    });
    
    if (!hasPermission) {
      _showBluetoothAlert("Bluetooth permissions are required. Please grant them in app settings.");
    }
  }

  /// 🔔 Alert + optional TTS
  void _showBluetoothAlert(String message) async {
    await _ttsService.speak(message);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Bluetooth Notice"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  /// ⚙️ Try scanning (BluetoothService already checks internally)
  Future<void> _scanDevices() async {
    // Check and request permissions first
    if (!hasPermission) {
      await _requestBluetoothPermissions();
      if (!hasPermission) {
        _showBluetoothAlert("Bluetooth permissions are required to scan for devices.");
        return;
      }
    }

    if (!isBluetoothOn) {
      _showBluetoothAlert("Please turn on Bluetooth first.");
      return;
    }

    setState(() {
      isScanning = true;
      devices = [];
      status = 'Scanning...';
    });

    try {
      final foundDevices = await _bluetoothService.scanForDevices();
      setState(() {
        devices = foundDevices;
        status = foundDevices.isEmpty ? 'No devices found' : 'Scan complete';
      });
    } catch (e) {
      setState(() {
        status = 'Error: ${e.toString()}';
      });
      _showBluetoothAlert(status);
    } finally {
      setState(() {
        isScanning = false;
      });
    }
  }

  Future<void> _connectToDevice(String device) async {
    setState(() {
      status = 'Connecting to $device...';
    });
    try {
      final success = await _bluetoothService.connect(device);
      setState(() {
        connectedDevice = success ? device : null;
        status = success ? 'Connected to $device' : 'Connection failed';
      });
    } catch (e) {
      setState(() => status = "Connection error: $e");
      _showBluetoothAlert(status);
    }
  }

  Future<void> _disconnect() async {
    setState(() {
      status = 'Disconnecting...';
    });
    await _bluetoothService.disconnect();
    setState(() {
      connectedDevice = null;
      status = 'Disconnected';
      openAIResponse = null;
      isProcessingImage = false;
    });
  }

  Future<void> _readAloud() async {
    if (openAIResponse == null) return;
    setState(() {
      isTTSPlaying = true;
    });
    await _ttsService.speak(openAIResponse!);
    setState(() {
      isTTSPlaying = false;
    });
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
        Icons.warning,
        'Bluetooth permission not granted. Tap to grant permissions.',
        Colors.orange,
        onTap: _requestBluetoothPermissions,
      );
    }

    if (!isBluetoothOn) {
      return _buildBanner(
        Icons.bluetooth_disabled,
        'Bluetooth is OFF. Please turn it ON.',
        Colors.red,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildBanner(IconData icon, String text, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
            if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(Icons.touch_app, color: color, size: 20),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      currentIndex: 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bluetooth'),
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
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              _bluetoothBanner(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Device Connection',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      Chip(
                        label: Text(
                          status,
                          overflow: TextOverflow.ellipsis,
                        ),
                        backgroundColor: _statusColor().withOpacity(0.1),
                        labelStyle: TextStyle(color: _statusColor()),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CustomButton(
                label: isScanning ? 'Scanning...' : 'Scan for Devices',
                onPressed: isScanning ? () {} : _scanDevices,
              ),
              const SizedBox(height: 16),
              const Text(
                'Available Devices:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (devices.isEmpty)
                Center(
                  child: Column(
                    children: [
                      const Icon(Icons.bluetooth_disabled, size: 48, color: Colors.grey),
                      const SizedBox(height: 8),
                      const Text('No devices found.'),
                      const SizedBox(height: 4),
                      Text(
                        'Make sure your ESP32 is powered on and in pairing mode.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                ...devices.map(
                  (device) => Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      leading: Icon(
                        device.toLowerCase().contains('esp') || 
                        device.toLowerCase().contains('ble')
                            ? Icons.sensors
                            : Icons.devices,
                        color: connectedDevice == device
                            ? Colors.green
                            : Colors.blueGrey,
                      ),
                      title: Text(
                        device,
                        style: TextStyle(
                          fontWeight: connectedDevice == device 
                              ? FontWeight.bold 
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: connectedDevice == device
                          ? const Text('Connected', style: TextStyle(color: Colors.green))
                          : null,
                      trailing: connectedDevice == device
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : ElevatedButton(
                              onPressed: () => _connectToDevice(device),
                              child: const Text('Connect'),
                            ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              if (connectedDevice != null) ...[
                CustomButton(label: 'Disconnect', onPressed: _disconnect),
                const SizedBox(height: 24),
                const Divider(height: 32, thickness: 1.2),
                const Text(
                  'Live Image Processing',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 12),
                _buildImageProcessingCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageProcessingCard() {
    return Card(
      color: Colors.blueGrey.withOpacity(0.04),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          switchInCurve: Curves.easeIn,
          switchOutCurve: Curves.easeOut,
          child: isProcessingImage
              ? Row(
                  key: const ValueKey('processing'),
                  children: const [
                    CircularProgressIndicator(),
                    SizedBox(width: 16),
                    Text('Processing with OpenAI...'),
                  ],
                )
              : openAIResponse != null
              ? Column(
                  key: const ValueKey('response'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'OpenAI Response:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(openAIResponse!),
                    ),
                    const SizedBox(height: 16),
                    CustomButton(
                      label: isTTSPlaying ? 'Reading...' : 'Read Aloud',
                      onPressed: isTTSPlaying ? () {} : _readAloud,
                    ),
                  ],
                )
              : const Text(
                  'Waiting for image from hardware...',
                  key: ValueKey('waiting'),
                ),
        ),
      ),
    );
  }
}

