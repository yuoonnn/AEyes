import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'database_service.dart';

class BatteryService {
  final Battery _battery = Battery();
  final DatabaseService _databaseService = DatabaseService();
  
  StreamSubscription<int>? _phoneBatterySubscription;
  StreamSubscription<List<int>>? _esp32BatterySubscription;
  Timer? _updateTimer;
  
  int? _phoneBatteryLevel;
  int? _esp32BatteryLevel;
  BatteryState? _phoneBatteryState;
  
  // Stream controllers for battery updates
  final _phoneBatteryController = StreamController<int>.broadcast();
  final _esp32BatteryController = StreamController<int>.broadcast();
  
  Stream<int> get phoneBatteryStream => _phoneBatteryController.stream;
  Stream<int> get esp32BatteryStream => _esp32BatteryController.stream;
  
  // BLE Battery Service UUIDs (standard)
  static const String batteryServiceUUID = '0000180f-0000-1000-8000-00805f9b34fb';
  static const String batteryLevelCharacteristicUUID = '00002a19-0000-1000-8000-00805f9b34fb';
  
  int? get phoneBatteryLevel => _phoneBatteryLevel;
  int? get esp32BatteryLevel => _esp32BatteryLevel;
  BatteryState? get phoneBatteryState => _phoneBatteryState;
  
  /// Start monitoring phone battery
  Future<void> startMonitoringPhoneBattery() async {
    try {
      // Get initial battery level
      _phoneBatteryLevel = await _battery.batteryLevel;
      _phoneBatteryState = await _battery.batteryState;
      
      // Emit initial value to stream immediately
      if (_phoneBatteryLevel != null) {
        _phoneBatteryController.add(_phoneBatteryLevel!);
      }
      
      // Update Firestore immediately
      if (_phoneBatteryLevel != null) {
        await _updatePhoneBatteryInFirestore(_phoneBatteryLevel!);
      }
      
      // Poll battery level periodically (battery_plus 6.0.2 doesn't have onBatteryLevelChanged)
      _updateTimer?.cancel();
      _updateTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
        try {
          final level = await _battery.batteryLevel;
          if (level != _phoneBatteryLevel) {
            _phoneBatteryLevel = level;
            _phoneBatteryController.add(level);
            _updatePhoneBatteryInFirestore(level);
          }
          _phoneBatteryState = await _battery.batteryState;
        } catch (e) {
          print('Error polling phone battery: $e');
        }
      });
      
      print('Phone battery monitoring started: $_phoneBatteryLevel%');
    } catch (e) {
      print('Error starting phone battery monitoring: $e');
    }
  }
  
  /// Start monitoring ESP32 battery via BLE
  Future<void> startMonitoringESP32Battery(BluetoothDevice device) async {
    try {
      // Discover services
      List<BluetoothService> services = await device.discoverServices();
      
      // Find Battery Service
      BluetoothService? batteryService;
      for (var service in services) {
        if (service.uuid.toString().toLowerCase() == batteryServiceUUID.toLowerCase()) {
          batteryService = service;
          break;
        }
      }
      
      if (batteryService == null) {
        print('Battery Service not found on ESP32 device');
        return;
      }
      
      // Find Battery Level Characteristic
      BluetoothCharacteristic? batteryCharacteristic;
      for (var characteristic in batteryService.characteristics) {
        if (characteristic.uuid.toString().toLowerCase() == batteryLevelCharacteristicUUID.toLowerCase()) {
          batteryCharacteristic = characteristic;
          break;
        }
      }
      
      if (batteryCharacteristic == null) {
        print('Battery Level Characteristic not found');
        return;
      }
      
      // Read initial battery level
      if (batteryCharacteristic.properties.read) {
        List<int> value = await batteryCharacteristic.read();
        if (value.isNotEmpty) {
          _esp32BatteryLevel = value[0];
          await _updateESP32BatteryInFirestore(_esp32BatteryLevel!);
          print('ESP32 battery level: $_esp32BatteryLevel%');
        }
      }
      
      // Subscribe to notifications if available
      if (batteryCharacteristic.properties.notify) {
        await batteryCharacteristic.setNotifyValue(true);
        _esp32BatterySubscription = batteryCharacteristic.onValueReceived.listen((value) {
          if (value.isNotEmpty) {
            _esp32BatteryLevel = value[0];
            _esp32BatteryController.add(_esp32BatteryLevel!);
            _updateESP32BatteryInFirestore(_esp32BatteryLevel!);
            print('ESP32 battery updated: $_esp32BatteryLevel%');
          }
        });
      }
      
      // Also poll periodically if notifications not available
      _startPeriodicESP32BatteryPolling(batteryCharacteristic);
      
    } catch (e) {
      print('Error starting ESP32 battery monitoring: $e');
    }
  }
  
  /// Periodically poll ESP32 battery if notifications not available
  void _startPeriodicESP32BatteryPolling(BluetoothCharacteristic characteristic) {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      try {
        if (characteristic.properties.read) {
          List<int> value = await characteristic.read();
          if (value.isNotEmpty) {
            _esp32BatteryLevel = value[0];
            _esp32BatteryController.add(_esp32BatteryLevel!);
            await _updateESP32BatteryInFirestore(_esp32BatteryLevel!);
          }
        }
      } catch (e) {
        print('Error polling ESP32 battery: $e');
      }
    });
  }
  
  /// Update phone battery in Firestore
  Future<void> _updatePhoneBatteryInFirestore(int batteryLevel) async {
    try {
      final userId = _databaseService.currentUserId;
      if (userId == null) return;
      
      // Get user's device (phone)
      final devices = await _databaseService.getUserDevices();
      final phoneDevice = devices.where(
        (device) => device['device_type'] == 'phone',
      ).firstOrNull;
      
      if (phoneDevice == null) {
        // Create phone device entry
        await _databaseService.saveDevice(
          deviceName: 'Phone',
          bleMacAddress: '',
          batteryLevel: batteryLevel,
          deviceType: 'phone',
        );
      } else {
        // Update existing phone device
        await _databaseService.updateDeviceBattery(
          phoneDevice['device_id'] as String,
          batteryLevel,
        );
      }
    } catch (e) {
      print('Error updating phone battery in Firestore: $e');
    }
  }
  
  /// Update ESP32 battery in Firestore
  Future<void> _updateESP32BatteryInFirestore(int batteryLevel) async {
    try {
      final userId = _databaseService.currentUserId;
      if (userId == null) return;
      
      // Get user's ESP32 device
      final devices = await _databaseService.getUserDevices();
      final esp32Device = devices.firstWhere(
        (device) => device['device_type'] == 'smart_glasses',
        orElse: () => {},
      );
      
      if (esp32Device.isNotEmpty) {
        await _databaseService.updateDeviceBattery(
          esp32Device['device_id'] as String,
          batteryLevel,
        );
      }
    } catch (e) {
      print('Error updating ESP32 battery in Firestore: $e');
    }
  }
  
  /// Stop all monitoring
  void stopMonitoring() {
    _phoneBatterySubscription?.cancel();
    _phoneBatterySubscription = null;
    _esp32BatterySubscription?.cancel();
    _esp32BatterySubscription = null;
    _updateTimer?.cancel();
    _updateTimer = null;
  }
  
  /// Dispose resources
  void dispose() {
    stopMonitoring();
    _phoneBatteryController.close();
    _esp32BatteryController.close();
  }
}

