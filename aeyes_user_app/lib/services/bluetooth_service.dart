import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class BluetoothService {
  final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
  BluetoothConnection? _connection;

  Function(Uint8List)? onImageReceived;

  bool get isConnected => _connection?.isConnected ?? false;

  /// Scan for nearby Bluetooth devices
  Future<List<String>> scanForDevices() async {
    final List<String> found = [];
    final bondedDevices = await _bluetooth.getBondedDevices();
    for (var device in bondedDevices) {
      if (device.name != null && !found.contains(device.name)) {
        found.add(device.name!);
      }
    }
    return found;
  }

  /// Connect to selected device by name
  Future<bool> connect(String deviceName) async {
    final List<BluetoothDevice> devices = await _bluetooth.getBondedDevices();
    final target = devices.firstWhere(
      (d) => d.name == deviceName,
      orElse: () => BluetoothDevice(address: '', name: null),
    );

    if (target.address.isEmpty) {
      print("Device not found");
      return false;
    }

    try {
      _connection = await BluetoothConnection.toAddress(target.address);
      print('Connected to ${target.name}');

      _connection!.input
          ?.listen((Uint8List data) {
            print('Received ${data.length} bytes');
            onImageReceived?.call(Uint8List.fromList(data));
          })
          .onDone(() {
            print('Disconnected by remote device');
          });

      return true;
    } catch (e) {
      print('Connection failed: $e');
      return false;
    }
  }

  Future<void> disconnect() async {
    await _connection?.close();
    _connection = null;
  }
}
