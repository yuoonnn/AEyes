import 'package:flutter/material.dart';
import '../widgets/custom_button.dart';
import '../services/bluetooth_service.dart';
import '../services/openai_service.dart';
import '../services/tts_service.dart';
import '../widgets/main_scaffold.dart';

class BluetoothScreen extends StatefulWidget {
  const BluetoothScreen({Key? key}) : super(key: key);

  @override
  State<BluetoothScreen> createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends State<BluetoothScreen> {
  final BluetoothService _bluetoothService = BluetoothService();
  final OpenAIService _openAIService = OpenAIService();
  final TTSService _ttsService = TTSService();
  List<String> devices = [];
  String? connectedDevice;
  bool isScanning = false;
  String status = 'Disconnected';

  // OpenAI & TTS state
  bool isProcessingImage = false;
  String? openAIResponse;
  bool isTTSPlaying = false;

  Future<void> _scanDevices() async {
    setState(() {
      isScanning = true;
      devices = [];
      status = 'Scanning...';
    });
    final foundDevices = await _bluetoothService.scanForDevices();
    setState(() {
      devices = foundDevices;
      isScanning = false;
      status = 'Scan complete';
    });
  }

  Future<void> _connectToDevice(String device) async {
    setState(() {
      status = 'Connecting to $device...';
    });
    final success = await _bluetoothService.connect(device);
    setState(() {
      connectedDevice = success ? device : null;
      status = success ? 'Connected to $device' : 'Connection failed';
    });
    if (success) {
      // Simulate receiving image from hardware after connection
      _receiveImageFromHardware();
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

  Future<void> _receiveImageFromHardware() async {
    setState(() {
      isProcessingImage = true;
      openAIResponse = null;
    });
    // Simulate a delay for receiving image
    await Future.delayed(const Duration(seconds: 2));
    // Automatically send to OpenAI
    final response = await _openAIService.processImage('mock_image_data');
    setState(() {
      openAIResponse = response;
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
              Row(
                children: [
                  const Text(
                    'Device Connection',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(width: 12),
                  Chip(
                    label: Text(status),
                    backgroundColor: _statusColor().withOpacity(0.1),
                    labelStyle: TextStyle(color: _statusColor()),
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
                const Center(child: Text('No devices found.'))
              else
                ...devices.map(
                  (device) => Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      leading: Icon(
                        Icons.devices,
                        color: connectedDevice == device
                            ? Colors.green
                            : Colors.blueGrey,
                      ),
                      title: Text(device),
                      trailing: connectedDevice == device
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : CustomButton(
                              label: 'Connect',
                              onPressed: () => _connectToDevice(device),
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
                Card(
                  color: Colors.blueGrey.withOpacity(0.04),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.image,
                              color: Colors.blueGrey.shade400,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              isProcessingImage
                                  ? 'Receiving image...'
                                  : 'Image received',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        AnimatedSwitcher(
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
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
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
                                      label: isTTSPlaying
                                          ? 'Reading...'
                                          : 'Read Aloud',
                                      onPressed: isTTSPlaying
                                          ? () {}
                                          : _readAloud,
                                    ),
                                    AnimatedSwitcher(
                                      duration: Duration(milliseconds: 400),
                                      child: isTTSPlaying
                                          ? Padding(
                                              key: const ValueKey('tts'),
                                              padding: const EdgeInsets.only(
                                                top: 8.0,
                                              ),
                                              child: Row(
                                                children: const [
                                                  SizedBox(width: 8),
                                                  CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                  ),
                                                  SizedBox(width: 12),
                                                  Text('Playing audio...'),
                                                ],
                                              ),
                                            )
                                          : const SizedBox.shrink(),
                                    ),
                                  ],
                                )
                              : const Text(
                                  'Waiting for image from hardware...',
                                  key: ValueKey('waiting'),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
