import 'package:flutter_blue_plus/flutter_blue_plus.dart' as ble;
import 'dart:async';
import 'dart:typed_data';

class BluetoothService {
  StreamSubscription<List<ble.ScanResult>>? _scanSubscription;
  ble.BluetoothDevice? _connectedDevice;
  List<ble.BluetoothService>? _services;
  
  // Callback for image reception
  Function(Uint8List)? onImageReceived;

  // Device connection state
  bool get isConnected => _connectedDevice != null;
  ble.BluetoothDevice? get connectedDevice => _connectedDevice;

  // Scan for BLE devices ONLY (flutter_blue_plus only scans BLE, not classic Bluetooth)
  // This is perfect for ESP32 which uses BLE
  Stream<List<ble.BluetoothDevice>> scanForDevices({Duration? timeout}) {
    final controller = StreamController<List<ble.BluetoothDevice>>();
    final devices = <ble.BluetoothDevice>[];

    _scanSubscription = ble.FlutterBluePlus.scanResults.listen((results) {
      for (final result in results) {
        // Avoid duplicates
        if (!devices.any((device) => device.remoteId == result.device.remoteId)) {
          // flutter_blue_plus only returns BLE devices, so all results are BLE
          devices.add(result.device);
          controller.add(List.from(devices));
        }
      }
    });

    // Start scanning for BLE devices only
    // Note: flutter_blue_plus.startScan() only scans BLE devices by default
    // It will NOT scan classic Bluetooth devices (like speakers, headphones, etc.)
    ble.FlutterBluePlus.startScan(
      timeout: timeout ?? const Duration(seconds: 10),
      // Optional: Filter by services if you know ESP32's service UUID
      // withServices: [ble.Guid('your-esp32-service-uuid')],
    );

    // Stop scanning after timeout and close stream
    Future.delayed(timeout ?? const Duration(seconds: 10), () {
      stopScan();
      controller.close();
    });

    return controller.stream;
  }

  // Stop scanning
  void stopScan() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    ble.FlutterBluePlus.stopScan();
  }

  // Get device name with fallback
  String _getDeviceName(ble.BluetoothDevice device) {
    try {
      // Try to get the local name first, then use remoteId as fallback
      final localName = device.platformName;
      if (localName != null && localName.isNotEmpty) {
        return localName;
      }
      return device.remoteId.toString();
    } catch (e) {
      return device.remoteId.toString();
    }
  }

  // Get device type
  String _getDeviceType(ble.BluetoothDevice device) {
    try {
      // All devices returned by flutter_blue_plus are BLE devices
      // Classic Bluetooth devices (speakers, headphones, etc.) are NOT included
      // This is perfect for ESP32 which uses BLE
      return 'BLE';
    } catch (e) {
      return 'Unknown';
    }
  }

  // Get scanned devices list (BLE devices only)
  Future<List<Map<String, dynamic>>> getScannedDevices() async {
    final devices = <Map<String, dynamic>>[];
    
    try {
      // Start scan for BLE devices only (classic Bluetooth devices are excluded)
      await ble.FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
      await Future.delayed(const Duration(seconds: 2));
      
      final results = ble.FlutterBluePlus.scanResults;
      final resultsList = await results.first;
      
      for (final result in resultsList) {
        final device = result.device;
        final deviceName = _getDeviceName(device);
        final deviceType = _getDeviceType(device);
        
        devices.add({
          'id': device.remoteId.toString(),
          'name': deviceName,
          'type': deviceType,
          'rssi': result.rssi,
          'device': device,
        });
      }
      
      await ble.FlutterBluePlus.stopScan();
    } catch (e) {
      print('Error getting scanned devices: $e');
    }
    
    return devices;
  }

  // Connect to a device
  Future<bool> connectToDevice(ble.BluetoothDevice device) async {
    try {
      if (_connectedDevice != null) {
        await disconnectDevice();
      }

      print('Connecting to device: ${_getDeviceName(device)}');
      
      // Connect with timeout
      await device.connect(timeout: const Duration(seconds: 15));
      _connectedDevice = device;

      print('Connected to ${_getDeviceName(device)}');

      // Discover services
      List<ble.BluetoothService> bleServices = await device.discoverServices();
      _services = bleServices;

      print('Discovered ${bleServices.length} services');

      return true;
    } catch (e) {
      print('Failed to connect to device: $e');
      return false;
    }
  }

  // Alias for connectToDevice to match existing code
  Future<bool> connect(ble.BluetoothDevice device) async {
    return await connectToDevice(device);
  }

  // Connect to device by ID
  Future<bool> connectToDeviceById(String deviceId) async {
    try {
      // First, try to get from scanned devices
      final scannedDevices = await getScannedDevices();
      final deviceInfo = scannedDevices.firstWhere(
        (device) => device['id'] == deviceId,
        orElse: () => {},
      );

      if (deviceInfo.isEmpty) {
        print('Device not found in scanned devices');
        return false;
      }

      final device = deviceInfo['device'] as ble.BluetoothDevice;
      return await connectToDevice(device);
    } catch (e) {
      print('Error connecting to device by ID: $e');
      return false;
    }
  }

  // Disconnect from current device
  Future<void> disconnectDevice() async {
    try {
      if (_connectedDevice != null) {
        await _connectedDevice?.disconnect();
        _connectedDevice = null;
        _services = null;
        print('Disconnected from device');
      }
    } catch (e) {
      print('Error disconnecting device: $e');
    }
  }

  // Alias for disconnectDevice to match existing code
  Future<void> disconnect() async {
    await disconnectDevice();
  }

  // Get connected device info
  Map<String, dynamic>? getConnectedDeviceInfo() {
    if (_connectedDevice == null) return null;

    return {
      'id': _connectedDevice!.remoteId.toString(),
      'name': _getDeviceName(_connectedDevice!),
      'type': _getDeviceType(_connectedDevice!),
    };
  }

  // Get services
  List<ble.BluetoothService>? getServices() {
    return _services;
  }

  // Check Bluetooth state
  Stream<ble.BluetoothAdapterState> get bluetoothState => ble.FlutterBluePlus.adapterState;

  // Check if Bluetooth is available
  Future<bool> get isAvailable async => await ble.FlutterBluePlus.isSupported;

  // Send image data to connected device
  Future<void> sendImageData(Uint8List imageData) async {
    if (_connectedDevice == null || _services == null) {
      print('No device connected or services discovered');
      return;
    }

    try {
      // Find the appropriate service and characteristic for image transfer
      for (final service in _services!) {
        for (final characteristic in service.characteristics) {
          // Check if this characteristic supports write operations
          if (characteristic.properties.write) {
            // Split image data into chunks if needed (MTU limitation)
            const chunkSize = 512; // Adjust based on your device's MTU
            for (int i = 0; i < imageData.length; i += chunkSize) {
              final end = (i + chunkSize < imageData.length) ? i + chunkSize : imageData.length;
              final chunk = imageData.sublist(i, end);
              await characteristic.write(chunk);
            }
            print('Image data sent successfully');
            return;
          }
        }
      }
      print('No writable characteristic found for image transfer');
    } catch (e) {
      print('Error sending image data: $e');
    }
  }

  // Cleanup
  void dispose() {
    stopScan();
    _scanSubscription?.cancel();
    disconnectDevice();
  }
}