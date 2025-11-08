import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as ble;
import '../services/tts_service.dart';

class BluetoothService {
  ble.BluetoothDevice? _connectedDevice;
  ble.BluetoothCharacteristic? _characteristic;
  ble.BluetoothCharacteristic? _writeCharacteristic; // For sending commands
  StreamSubscription<List<int>>? _subscription;

  Function(Uint8List)? onImageReceived;

  bool get isConnected => _connectedDevice != null;

  /// Scan for nearby Bluetooth devices
  Future<List<String>> scanForDevices() async {
    final List<String> found = [];
    final Set<String> deviceIds = {}; // Track by ID to avoid duplicates
    
    // Check if Bluetooth is available
    if (await ble.FlutterBluePlus.isSupported == false) {
      print("Bluetooth not supported");
      return found;
    }

    // Turn on Bluetooth if off
    final adapterState = await ble.FlutterBluePlus.adapterState.first;
    if (adapterState == ble.BluetoothAdapterState.off) {
      await ble.FlutterBluePlus.turnOn();
      // Wait a bit for Bluetooth to turn on
      await Future.delayed(const Duration(seconds: 1));
    }

    print("Starting Bluetooth scan...");
    
    // Start scanning with longer timeout for ESP32
    await ble.FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 10), // Increased to 10 seconds
      withServices: [], // Don't filter by services - scan all devices
    );
    
    // Collect scan results during the scan period
    final subscription = ble.FlutterBluePlus.scanResults.listen((results) {
      for (ble.ScanResult result in results) {
        final device = result.device;
        final deviceId = device.remoteId.str;
        
        // Skip if we've already seen this device
        if (deviceIds.contains(deviceId)) continue;
        deviceIds.add(deviceId);
        
        // Get device name - prefer platformName, fallback to advertisedName, or use ID
        String deviceName = device.platformName;
        if (deviceName.isEmpty) {
          deviceName = device.advertisedName.isNotEmpty 
              ? device.advertisedName 
              : 'Unknown Device';
        }
        
        // For ESP32, also check if name contains common ESP32 identifiers
        // or if it's a BLE device (ESP32 typically uses BLE)
        if (deviceName.isNotEmpty && deviceName != 'Unknown Device') {
          found.add(deviceName);
          print('Found device: $deviceName (ID: $deviceId)');
        } else if (device.platformType == ble.BluetoothDeviceType.le) {
          // If it's a BLE device but no name, use ID
          final displayName = 'BLE Device ($deviceId)';
          found.add(displayName);
          print('Found BLE device: $displayName');
        }
      }
    });
    
    // Wait for scan to complete
    await Future.delayed(const Duration(seconds: 10));
    
    // Stop scanning
    await ble.FlutterBluePlus.stopScan();
    await subscription.cancel();
    
    print("Scan complete. Found ${found.length} devices: $found");
    return found;
  }

  /// Connect to selected device by name
  Future<bool> connect(String deviceName) async {
    try {
      print("Connecting to device: $deviceName");
      
      // Start scanning to find the device
      await ble.FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 8),
        withServices: [],
      );
      
      ble.BluetoothDevice? targetDevice;
      final subscription = ble.FlutterBluePlus.scanResults.listen((results) {
        for (ble.ScanResult result in results) {
          final device = result.device;
          final name = device.platformName.isNotEmpty 
              ? device.platformName 
              : device.advertisedName;
          
          // Match by name or by ID (if deviceName contains ID)
          if (name == deviceName || 
              device.remoteId.str == deviceName ||
              (deviceName.startsWith('BLE Device') && deviceName.contains(device.remoteId.str))) {
            targetDevice = device;
            print("Found target device: $name (${device.remoteId.str})");
            break;
          }
        }
      });
      
      // Wait for scan to find device or timeout
      await Future.delayed(const Duration(seconds: 8));
      await subscription.cancel();
      await ble.FlutterBluePlus.stopScan();

      if (targetDevice == null) {
        print("Device not found: $deviceName");
        return false;
      }

      // Connect to device
      await targetDevice.connect(timeout: const Duration(seconds: 15));
      _connectedDevice = targetDevice;
      print('Connected to ${targetDevice.platformName}');

      // Discover services
      List<ble.BluetoothService> bleServices = await targetDevice.discoverServices();
      
      // Find characteristics for data transfer
      for (ble.BluetoothService service in bleServices) {
        for (ble.BluetoothCharacteristic characteristic in service.characteristics) {
          // Characteristic for receiving data (notifications)
          if (characteristic.properties.read || characteristic.properties.notify) {
            _characteristic = characteristic;
            
            // Subscribe to notifications if available
            if (characteristic.properties.notify) {
              await characteristic.setNotifyValue(true);
              _subscription = characteristic.onValueReceived.listen((data) {
                print('Received ${data.length} bytes');
                onImageReceived?.call(Uint8List.fromList(data));
              });
            }
          }
          
          // Characteristic for sending data (write)
          if (characteristic.properties.write || characteristic.properties.writeWithoutResponse) {
            _writeCharacteristic = characteristic;
          }
        }
      }

      return true;
    } catch (e) {
      print('Connection failed: $e');
      return false;
    }
  }

  /// Send volume settings to ESP32 via BLE

  Future<bool> sendVolumeSettings() async {
    if (!isConnected || _writeCharacteristic == null) {
      print('Not connected or write characteristic not found');
      return false;
    }

    try {
      final ttsService = TTSService();
      final volumeJson = await ttsService.getVolumeSettingsJSON();
      
      // Convert JSON string to bytes
      final bytes = utf8.encode(volumeJson);
      
      // Send via BLE write characteristic
      await _writeCharacteristic!.write(bytes, withoutResponse: false);
      print('Volume settings sent to ESP32: $volumeJson');
      return true;
    } catch (e) {
      print('Error sending volume settings: $e');
      return false;
    }
  }

  /// Send custom command/data to ESP32

  Future<bool> sendDataToESP32(Uint8List data) async {
    if (!isConnected || _writeCharacteristic == null) {
      print('Not connected or write characteristic not found');
      return false;
    }

    try {
      await _writeCharacteristic!.write(data, withoutResponse: false);
      print('Data sent to ESP32: ${data.length} bytes');
      return true;
    } catch (e) {
      print('Error sending data: $e');
      return false;
    }
  }

  /// Get volume settings as bytes (alternative format for ESP32)
  /// Returns: [tts_volume, beep_volume] as two bytes (0-100 each)
  Future<Uint8List> getVolumeSettingsAsBytes() async {
    final ttsService = TTSService();
    final volumes = await ttsService.getVolumeSettings();
    
    return Uint8List.fromList([
      volumes['tts_volume'] ?? 50,
      volumes['beep_volume'] ?? 50,
    ]);
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    await _connectedDevice?.disconnect();
    _connectedDevice = null;
    _characteristic = null;
    _writeCharacteristic = null;
  }
}
