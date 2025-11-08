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
      status = 'Scanning for devices...';
    });

    try {
      final scanStream = _bluetoothService.scanForDevices(timeout: const Duration(seconds: 10));
      
      scanStream.listen((List<ble.BluetoothDevice> foundDevices) {
        if (mounted) {
          setState(() {
            devices = foundDevices.map((device) {
              return {
                'id': device.remoteId.toString(),
                'name': device.platformName.isNotEmpty ? device.platformName : 'Unknown Device',
                'device': device,
              };
            }).toList();
            status = 'Found ${devices.length} devices';
          });
        }
      }, onDone: () {
        if (mounted) {
          setState(() {
            isScanning = false;
            if (devices.isEmpty) {
              status = 'No devices found';
            } else {
              status = 'Scan complete - Found ${devices.length} devices';
            }
          });
        }
      });
    } catch (e) {
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
                  ? const Center(
                      child: Text(
                        'No devices found\nTap scan to search for Bluetooth devices',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: devices.length,
                      itemBuilder: (context, index) {
                        final device = devices[index];
                        final bleDevice = device['device'] as ble.BluetoothDevice;
                        final isConnected = connectedDevice?['id'] == device['id'];

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: Icon(
                              Icons.bluetooth,
                              color: isConnected ? Colors.green : Colors.grey,
                            ),
                            title: Text(device['name'] ?? 'Unknown Device'),
                            subtitle: Text(device['id']),
                            trailing: isConnected
                                ? IconButton(
                                    icon: const Icon(Icons.link_off, color: Colors.red),
                                    onPressed: _disconnectDevice,
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.link, color: Colors.blue),
                                    onPressed: () => _connectToDevice(bleDevice),
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