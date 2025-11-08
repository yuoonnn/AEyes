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
    
    // Check if Bluetooth is available
    if (await ble.FlutterBluePlus.isSupported == false) {
      print("Bluetooth not supported");
      return found;
    }

    // Turn on Bluetooth if off
    if (await ble.FlutterBluePlus.adapterState.first == ble.BluetoothAdapterState.off) {
      await ble.FlutterBluePlus.turnOn();
    }

    // Start scanning
    await ble.FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
    
    // Listen to scan results
    await for (List<ble.ScanResult> results in ble.FlutterBluePlus.scanResults) {
      for (ble.ScanResult result in results) {
        if (result.device.platformName.isNotEmpty && 
            !found.contains(result.device.platformName)) {
          found.add(result.device.platformName);
        }
      }
    }

    // Stop scanning
    await ble.FlutterBluePlus.stopScan();
    
    return found;
  }

  /// Connect to selected device by name
  Future<bool> connect(String deviceName) async {
    try {
      // Start scanning to find the device
      await ble.FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
      
      ble.BluetoothDevice? targetDevice;
      await for (List<ble.ScanResult> results in ble.FlutterBluePlus.scanResults) {
        for (ble.ScanResult result in results) {
          if (result.device.platformName == deviceName) {
            targetDevice = result.device;
            break;
          }
        }
        if (targetDevice != null) break;
      }
      
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
