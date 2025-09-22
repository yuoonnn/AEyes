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
  Function(Uint8List)? onImageReceived;

  // Scan for ESP32 device
  void startScan() {
    _scanStream = _ble.scanForDevices(withServices: [serviceUuid]).listen((
      device,
    ) {
      if (device.name.contains("ESP32S3-CAM")) {
        _device = device;
        stopScan();
        connect();
      }
    });
  }

  void stopScan() {
    _scanStream?.cancel();
  }

  void connect() {
    if (_device == null) return;
    _connectionStream = _ble.connectToDevice(id: _device!.id).listen((update) {
      if (update.connectionState == DeviceConnectionState.connected) {
        _subscribeToCharacteristic();
      }
    });
  }

  void _subscribeToCharacteristic() {
    final characteristic = QualifiedCharacteristic(
      serviceId: serviceUuid,
      characteristicId: charUuid,
      deviceId: _device!.id,
    );

    _notifyStream = _ble.subscribeToCharacteristic(characteristic).listen((
      data,
    ) {
      _imageBuffer.addAll(data);

      // Optional: Detect end of image (JPEG ends with 0xFFD9)
      if (_imageBuffer.length > 2 &&
          _imageBuffer[_imageBuffer.length - 2] == 0xFF &&
          _imageBuffer[_imageBuffer.length - 1] == 0xD9) {
        onImageReceived?.call(Uint8List.fromList(_imageBuffer));
        _imageBuffer.clear();
      }
    });
  }

  void disconnect() {
    _connectionStream?.cancel();
    _notifyStream?.cancel();
  }
}
