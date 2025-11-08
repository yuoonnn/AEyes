import 'package:flutter_blue_plus/flutter_blue_plus.dart' as ble;
import 'dart:async';

class BluetoothService {
  final ble.FlutterBluePlus _flutterBlue = ble.FlutterBluePlus.instance;
  StreamSubscription<List<ble.ScanResult>>? _scanSubscription;
  ble.BluetoothDevice? _connectedDevice;
  List<ble.BluetoothService>? _services;

  // Device connection state
  bool get isConnected => _connectedDevice != null;
  ble.BluetoothDevice? get connectedDevice => _connectedDevice;

  // Scan for BLE devices
  Stream<List<ble.BluetoothDevice>> scanForDevices({Duration? timeout}) {
    final controller = StreamController<List<ble.BluetoothDevice>>();
    final devices = <ble.BluetoothDevice>[];

    _scanSubscription = _flutterBlue.scanResults.listen((results) {
      for (final result in results) {
        // Avoid duplicates
        if (!devices.any((device) => device.remoteId == result.device.remoteId)) {
          devices.add(result.device);
          controller.add(List.from(devices));
        }
      }
    });

    // Start scanning
    _flutterBlue.startScan(timeout: timeout ?? const Duration(seconds: 10));

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
    _flutterBlue.stopScan();
  }

  // Get device name with fallback
  String _getDeviceName(ble.BluetoothDevice device) {
    try {
      // Try to get the local name first, then use remoteId as fallback
      final localName = device.localName;
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
      // Check if it's a BLE device by looking at the manufacturer data or services
      // For now, we'll assume all discovered devices are BLE since we're using BLE scan
      return 'BLE';
    } catch (e) {
      return 'Unknown';
    }
  }

  // Get scanned devices list
  Future<List<Map<String, dynamic>>> getScannedDevices() async {
    final devices = <Map<String, dynamic>>[];
    
    try {
      final results = await _flutterBlue.scanResults.first;
      
      for (final result in results) {
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
  Stream<ble.BluetoothState> get bluetoothState => _flutterBlue.state;

  // Check if Bluetooth is available
  Future<bool> get isAvailable => _flutterBlue.isAvailable;

  // Cleanup
  void dispose() {
    stopScan();
    _scanSubscription?.cancel();
    disconnectDevice();
  }
}