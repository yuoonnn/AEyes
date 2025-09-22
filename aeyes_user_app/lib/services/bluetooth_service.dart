import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

class BluetoothService {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  DiscoveredDevice? _device;

  StreamSubscription<DiscoveredDevice>? _scanStream;
  StreamSubscription<ConnectionStateUpdate>? _connectionStream;
  StreamSubscription<List<int>>? _notifyStream;

  final Uuid serviceUuid = Uuid.parse("12345678-1234-1234-1234-1234567890ab");
  final Uuid charUuid = Uuid.parse("abcd1234-ab12-cd34-ef56-1234567890ab");

  // Image buffer
  final List<int> _imageBuffer = [];

  // Callback for when a full image is received
  Function(Uint8List)? onImageReceived;

  /// Scan for ESP32 devices
  Future<List<String>> scanForDevices() async {
    final List<String> found = [];
    _scanStream = _ble.scanForDevices(withServices: [serviceUuid]).listen((
      device,
    ) {
      if (device.name.isNotEmpty && !found.contains(device.name)) {
        found.add(device.name);
      }

      // Auto-stop when ESP32-S3 is found
      if (device.name.contains("ESP32S3-CAM")) {
        _device = device;
        stopScan();
      }
    });

    // Allow some time for discovery
    await Future.delayed(const Duration(seconds: 4));
    stopScan();
    return found;
  }

  /// Stop scanning
  void stopScan() {
    _scanStream?.cancel();
    _scanStream = null;
  }

  /// Connect to selected device by name
  Future<bool> connect(String deviceName) async {
    if (_device == null || _device!.name != deviceName) {
      return false;
    }

    final completer = Completer<bool>();
    _connectionStream = _ble.connectToDevice(id: _device!.id).listen((update) {
      if (update.connectionState == DeviceConnectionState.connected) {
        _subscribeToCharacteristic();
        completer.complete(true);
      } else if (update.connectionState == DeviceConnectionState.disconnected) {
        completer.complete(false);
      }
    }, onError: (e) => completer.completeError(e));

    return completer.future;
  }

  /// Subscribe to image data characteristic
  void _subscribeToCharacteristic() {
    if (_device == null) return;

    final characteristic = QualifiedCharacteristic(
      serviceId: serviceUuid,
      characteristicId: charUuid,
      deviceId: _device!.id,
    );

    _notifyStream = _ble.subscribeToCharacteristic(characteristic).listen((
      data,
    ) {
      _imageBuffer.addAll(data);

      // Detect JPEG end marker 0xFFD9
      if (_imageBuffer.length > 2 &&
          _imageBuffer[_imageBuffer.length - 2] == 0xFF &&
          _imageBuffer[_imageBuffer.length - 1] == 0xD9) {
        final imageBytes = Uint8List.fromList(_imageBuffer);
        onImageReceived?.call(imageBytes);
        _imageBuffer.clear();
      }
    });
  }

  /// Disconnect cleanly
  Future<void> disconnect() async {
    await _connectionStream?.cancel();
    await _notifyStream?.cancel();
    _connectionStream = null;
    _notifyStream = null;
    _device = null;
  }
}
