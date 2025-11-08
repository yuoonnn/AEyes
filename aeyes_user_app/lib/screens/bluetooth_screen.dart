import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as ble;
import '../services/bluetooth_service.dart';
import '../services/openai_service.dart';
import '../widgets/custom_button.dart';

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
  final BluetoothService _bluetoothService = BluetoothService();
  List<Map<String, dynamic>> devices = [];
  bool isScanning = false;
  String status = 'Tap scan to find devices';
  Map<String, dynamic>? connectedDevice;

  @override
  void initState() {
    super.initState();
    _setupBluetooth();
  }

  void _setupBluetooth() {
    // Set up image received callback
    _bluetoothService.onImageReceived = (imageBytes) async {
      // Handle received image data
      if (mounted) {
        // Process the image with OpenAI service if needed
        // await widget.openAIService.analyzeImage(imageBytes);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Received image data: ${imageBytes.length} bytes')),
        );
      }
    };
  }

  Future<void> _startScan() async {
    if (isScanning) return;

    setState(() {
      isScanning = true;
      devices.clear();
      status = 'Checking Bluetooth...';
    });

    try {
      // Check if Bluetooth is enabled
      final isEnabled = await _bluetoothService.isBluetoothEnabled();
      if (!isEnabled) {
        if (mounted) {
          setState(() {
            isScanning = false;
            status = 'Bluetooth is not enabled. Please enable Bluetooth in settings.';
          });
        }
        return;
      }

      setState(() {
        status = 'Scanning for BLE devices (15 seconds)...';
      });

      // Increased timeout to 15 seconds for better ESP32 detection
      final scanStream = _bluetoothService.scanForDevices(timeout: const Duration(seconds: 15));
      
      scanStream.listen(
        (List<ble.BluetoothDevice> foundDevices) {
          if (mounted) {
            setState(() {
              devices = foundDevices.map((device) {
                final name = device.platformName.isNotEmpty 
                    ? device.platformName 
                    : 'Unknown Device (${device.remoteId.toString().substring(0, 8)}...)';
                return {
                  'id': device.remoteId.toString(),
                  'name': name,
                  'device': device,
                };
              }).toList();
              status = 'Found ${devices.length} BLE device(s)';
            });
          }
        },
        onError: (error) {
          print('Scan error: $error');
          if (mounted) {
            setState(() {
              isScanning = false;
              status = 'Scan error: $error';
            });
          }
        },
        onDone: () {
          if (mounted) {
            setState(() {
              isScanning = false;
              if (devices.isEmpty) {
                status = 'No BLE devices found. Make sure ESP32 is powered on and advertising.';
              } else {
                status = 'Scan complete - Found ${devices.length} device(s)';
              }
            });
          }
        },
      );
    } catch (e) {
      print('Scan exception: $e');
      if (mounted) {
        setState(() {
          isScanning = false;
          status = 'Scan failed: $e';
        });
      }
    }
  }

  void _stopScan() {
    _bluetoothService.stopScan();
    setState(() {
      isScanning = false;
      status = 'Scan stopped';
    });
  }

  Future<void> _connectToDevice(ble.BluetoothDevice device) async {
    setState(() {
      status = 'Connecting to ${device.platformName}...';
    });

    final success = await _bluetoothService.connectToDevice(device);

    if (mounted) {
      setState(() {
        if (success) {
          status = 'Connected to ${device.platformName}';
          connectedDevice = {
            'id': device.remoteId.toString(),
            'name': device.platformName,
          };
        } else {
          status = 'Failed to connect to ${device.platformName}';
        }
      });
    }
  }

  Future<void> _disconnectDevice() async {
    setState(() {
      status = 'Disconnecting...';
    });

    await _bluetoothService.disconnectDevice();

    if (mounted) {
      setState(() {
        status = 'Disconnected';
        connectedDevice = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Devices'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status: $status',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (connectedDevice != null)
                      Text(
                        'Connected: ${connectedDevice!['name']}',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Scan Button
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    label: isScanning ? 'Scanning...' : 'Scan for Devices',
                    onPressed: isScanning ? _stopScan : _startScan,
                    color: isScanning ? Colors.orange : Theme.of(context).colorScheme.primary,
                    textColor: Colors.white,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Devices List
            Expanded(
              child: devices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.bluetooth_disabled, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            'No BLE devices found',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32.0),
                            child: Text(
                              'Make sure:\n• ESP32 is powered on\n• ESP32 is in BLE advertising mode\n• Bluetooth is enabled on your phone\n• Location permission is granted',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: devices.length,
                      itemBuilder: (context, index) {
                        final device = devices[index];
                        final bleDevice = device['device'] as ble.BluetoothDevice;
                        final isConnected = connectedDevice?['id'] == device['id'];
                        final deviceName = device['name'] ?? 'Unknown Device';
                        final isESP32 = deviceName.toLowerCase().contains('esp') || 
                                      deviceName.toLowerCase().contains('esp32');

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: isESP32 ? Colors.green.shade50 : null,
                          child: ListTile(
                            leading: Icon(
                              isESP32 ? Icons.memory : Icons.bluetooth,
                              color: isConnected ? Colors.green : (isESP32 ? Colors.green : Colors.grey),
                            ),
                            title: Row(
                              children: [
                                Expanded(child: Text(deviceName)),
                                if (isESP32)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'ESP32',
                                      style: TextStyle(color: Colors.white, fontSize: 10),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              'ID: ${device['id'].toString().substring(0, 17)}...',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: isConnected
                                ? IconButton(
                                    icon: const Icon(Icons.link_off, color: Colors.red),
                                    onPressed: _disconnectDevice,
                                    tooltip: 'Disconnect',
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.link, color: Colors.blue),
                                    onPressed: () => _connectToDevice(bleDevice),
                                    tooltip: 'Connect',
                                  ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bluetoothService.dispose();
    super.dispose();
  }
}