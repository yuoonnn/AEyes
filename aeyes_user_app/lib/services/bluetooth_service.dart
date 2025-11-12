import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Integrated version: supports Option B BLE image streaming protocol.
class AppBluetoothService {
  // Known UUIDs from ESP32 sketch
  static final Guid _serviceUuid = Guid('12345678-1234-1234-1234-1234567890ab');
  static final Guid _imageCharUuid = Guid(
    'abcd1234-ab12-cd34-ef56-1234567890ab',
  );

  // -------- Logging --------
  final StreamController<String> _logController =
      StreamController<String>.broadcast();
  Stream<String> get logs => _logController.stream;
  void _log(String message) {
    final ts = DateTime.now().toIso8601String();
    final line = '[$ts] $message';
    // Always print to console as well
    print(line);
    // Best-effort add to stream
    if (!_logController.isClosed) {
      _logController.add(line);
    }
  }

  // Public logger for other layers (e.g., UI) to emit to the same stream
  void log(String message) => _log(message);

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  BluetoothDevice? _connectedDevice;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  BluetoothCharacteristic? _imageCharacteristic;
  BluetoothCharacteristic? _buttonCharacteristic;
  BluetoothCharacteristic? _voiceCharacteristic;
  BluetoothCharacteristic? _audioOutputCharacteristic;
  List<BluetoothService>? _discoveredServices;
  bool _isConnected = false;
  bool _autoConnect = true;
  String? _preferredDeviceId; // BluetoothRemoteId string
  Timer? _autoScanTimer;

  // Callbacks for hardware events
  Function(Uint8List)? onImageReceived;
  Function(String)? onButtonPressed;
  Function(Uint8List)? onVoiceCommandReceived;
  Function(String)? onVoiceCommandText;
  Function(String)? onRecordingCommand; // START_RECORDING or STOP_RECORDING

  // Internal image buffer
  final _imageBuffer = BytesBuilder();
  int _expectedImageSize = 0;
  bool _receivingImage = false;
  // Header parsing state
  final List<int> _headerBuffer = <int>[];
  bool _awaitingHeader = true;
  // Robust stream buffer to handle arbitrary notification boundaries
  final List<int> _rxBuffer = <int>[];

  bool get isConnected => _isConnected;

  // ---------------------------------------------------------------------------
  // Scan for devices
  Stream<List<BluetoothDevice>> scanForDevices({Duration? timeout}) {
    final controller = StreamController<List<BluetoothDevice>>();
    final devices = <BluetoothDevice>[];

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      _log('🔎 Scan results: ${results.length} candidates');
      for (final result in results) {
        if (!devices.any((d) => d.remoteId == result.device.remoteId) &&
            result.device.platformName.isNotEmpty) {
          devices.add(result.device);
          controller.add(List.from(devices));
          _log(
            '   • Found device: ${result.device.platformName} (${result.device.remoteId})',
          );
        }
      }
    });

    _log('🔎 Starting BLE scan...');
    FlutterBluePlus.startScan(
      timeout: timeout ?? const Duration(seconds: 10),
    ).catchError((e) {
      _log('❌ Failed to start scan: $e');
    });

    Future.delayed(timeout ?? const Duration(seconds: 10), () {
      stopScan();
      controller.close();
    });

    return controller.stream;
  }

  void stopScan() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    FlutterBluePlus.stopScan();
    _log('🛑 Scan stopped');
  }

  // ---------------------------------------------------------------------------
  // Connect to device
  Future<bool> connect(BluetoothDevice device) async {
    try {
      if (_isConnected) await disconnect();

      // Reset parser state for new session
      _awaitingHeader = true;
      _headerBuffer.clear();
      _imageBuffer.clear();
      _expectedImageSize = 0;
      _receivingImage = false;

      _log(
        '🔗 Connecting to ESP32: ${device.platformName} (${device.remoteId})',
      );
      await device.connect(timeout: const Duration(seconds: 15));
      // Request higher MTU to match ESP32 setting
      try {
        await device.requestMtu(200);
        _log('📏 MTU requested: 200');
      } catch (e) {
        _log('⚠️ MTU request failed: $e');
      }
      _connectedDevice = device;
      // Persist preferred device for auto-connect
      _preferredDeviceId = device.remoteId.str;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('preferred_ble_device_id', _preferredDeviceId!);
      } catch (_) {}

      _log('🔍 Discovering services...');
      final services = await device.discoverServices();
      _discoveredServices = services;

      // Prefer exact service/characteristic when available
      BluetoothService? targetService;
      for (final s in services) {
        _log('🔧 Service discovered: ${s.uuid}');
        if (s.uuid == _serviceUuid) {
          targetService = s;
          break;
        }
      }
      if (targetService == null) {
        _log('⚠️ Target service not found. Listing discovered services:');
        for (final s in services) {
          _log('   • Service: ${s.uuid}');
        }
      } else {
        _log('✅ Target service found: ${targetService.uuid}');
      }
      if (targetService != null) {
        for (final c in targetService.characteristics) {
          _log('   • Char: ${c.uuid}, props: ${c.properties}');
          if (c.uuid == _imageCharUuid && c.properties.notify) {
            _imageCharacteristic = c;
          }
        }
      }
      // Fallback: search all services for first notify characteristic
      _imageCharacteristic ??= () {
        for (final service in services) {
          for (final c in service.characteristics) {
            _log('   • Char: ${c.uuid}, props: ${c.properties}');
            if (c.properties.notify) return c;
          }
        }
        return null;
      }();

      // Subscribe to all notify characteristics to ensure we receive any data
      for (final service in services) {
        for (final c in service.characteristics) {
          if (c.properties.notify) {
            try {
              await c.setNotifyValue(true);
              c.onValueReceived.listen((value) {
                _log('🔔 Notification from ${c.uuid}: ${value.length} bytes');

                // Try to parse as button/voice/recording command first
                final parsed = _parseButtonOrVoiceCommand(value);
                if (parsed != null) {
                  if (parsed['type'] == 'button') {
                    onButtonPressed?.call(parsed['data'] as String);
                  } else if (parsed['type'] == 'voice') {
                    onVoiceCommandText?.call(parsed['data'] as String);
                  } else if (parsed['type'] == 'record') {
                    onRecordingCommand?.call(parsed['data'] as String);
                  }
                  return; // Don't process as image
                }

                // Route all notify data through image handler; it will only act when a valid header/image is present
                _handleImageData(value);
              });
              if (c == _imageCharacteristic) {
                _log('📬 Subscribed to image characteristic: ${c.uuid}');
              } else {
                _log(
                  '📬 Subscribed to auxiliary notify characteristic: ${c.uuid}',
                );
              }
            } catch (e) {
              _log('❌ Failed to subscribe ${c.uuid}: $e');
            }
          }
        }
      }
      if (_imageCharacteristic == null) {
        _log(
          '❌ No suitable image characteristic found (will still listen to all notify chars).',
        );
      }

      _isConnected = true;
      _log('✅ Connected to ${device.platformName}');
      // Stop any auto-scan loop while connected
      _autoScanTimer?.cancel();
      // Monitor connection to auto-reconnect
      _connSub?.cancel();
      _connSub = device.connectionState.listen((state) async {
        if (state == BluetoothConnectionState.disconnected) {
          _log('🔻 Disconnected by system/device');
          _isConnected = false;
          if (_autoConnect && _preferredDeviceId != null) {
            _log('🔁 Scheduling auto-reconnect...');
            _scheduleAutoScan();
          }
        }
      });
      return true;
    } catch (e) {
      _log('❌ Failed to connect: $e');
      _isConnected = false;
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Auto-connect
  Future<void> enableAutoConnect(bool enabled) async {
    _autoConnect = enabled;
    if (!enabled) {
      _autoScanTimer?.cancel();
      return;
    }
    // Load preferred device id if missing
    if (_preferredDeviceId == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        _preferredDeviceId = prefs.getString('preferred_ble_device_id');
      } catch (_) {}
    }
    _scheduleAutoScan();
  }

  void _scheduleAutoScan() {
    _autoScanTimer?.cancel();
    if (!_autoConnect) return;
    _autoScanTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      if (_isConnected || _preferredDeviceId == null) return;
      _log('🟢 Auto-connect scan tick...');
      try {
        // One-shot scan and attempt connect if preferred device is found
        final results =
            await FlutterBluePlus.startScan(
              timeout: const Duration(seconds: 6),
              // No filters; some platforms ignore service filter before bonding
            ).then(
              (_) => FlutterBluePlus.scanResults.first.timeout(
                const Duration(seconds: 6),
              ),
            );
        // results is a List<ScanResult>
        for (final r in results) {
          if (r.device.remoteId.str == _preferredDeviceId) {
            _log('✅ Preferred device detected nearby → auto-connecting');
            FlutterBluePlus.stopScan();
            await connect(r.device);
            break;
          }
        }
      } catch (e) {
        _log('⚠️ Auto-connect scan failed: $e');
      } finally {
        try {
          FlutterBluePlus.stopScan();
        } catch (_) {}
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Option B: Image stream handler
  void _handleImageData(List<int> data) {
    if (data.isEmpty) return;
    _rxBuffer.addAll(data);
    _log('📥 RX +${data.length} bytes (buffer ${_rxBuffer.length})');

    // Process zero or more frames contained in the rx buffer.
    while (true) {
      // 1) Find header "IMG\n<size>\n"
      if (_awaitingHeader) {
        final headerPrefix = [0x49, 0x4D, 0x47, 0x0A]; // "IMG\n"
        final startIndex = _indexOfSequence(_rxBuffer, headerPrefix);

        if (startIndex == -1) {
          // Keep only last 3 bytes to match potential start of "IMG"
          _shrinkBufferKeepTail(_rxBuffer, 3);
          return;
        }

        // Drop bytes before header start (noise from other notifications, etc.)
        if (startIndex > 0) {
          _rxBuffer.removeRange(0, startIndex);
        }

        // Find the second newline that terminates the header
        final secondNlIndex = _indexOfByteFrom(_rxBuffer, 0x0A, 4);
        if (secondNlIndex == -1) {
          // Wait until full header arrives
          return;
        }

        // Parse size between indices [4, secondNlIndex)
        try {
          final sizeBytes = _rxBuffer.sublist(4, secondNlIndex);
          final sizeString = utf8
              .decode(sizeBytes, allowMalformed: false)
              .trim();
          _expectedImageSize = int.tryParse(sizeString) ?? 0;
        } catch (_) {
          _expectedImageSize = 0;
        }

        _imageBuffer.clear();
        _receivingImage = true;
        _awaitingHeader = false;
        _log('🟡 New image incoming (size $_expectedImageSize bytes)');

        // Remove the header (up to and including the newline)
        _rxBuffer.removeRange(0, secondNlIndex + 1);
      }

      // 2) Accumulate image bytes and emit when complete
      if (_receivingImage) {
        // Prefer explicit size when present
        final hasSize =
            _expectedImageSize > 0 && _rxBuffer.length >= _expectedImageSize;

        // Or detect JPEG EOI marker 0xFF 0xD9
        final eoiIndex = _indexOfSequence(_rxBuffer, [0xFF, 0xD9]);
        final hasEoi = eoiIndex != -1;

        if (hasSize || hasEoi) {
          final endIndex = hasSize ? _expectedImageSize : (eoiIndex + 2);
          final frameBytes = Uint8List.fromList(_rxBuffer.sublist(0, endIndex));
          _rxBuffer.removeRange(0, endIndex);

          _receivingImage = false;
          _awaitingHeader = true;
          _log('✅ Full image received (${frameBytes.length} bytes)');
          onImageReceived?.call(frameBytes);
          _imageBuffer.clear();
          _expectedImageSize = 0;

          // Continue loop to see if another frame is already buffered
          if (_rxBuffer.isNotEmpty) {
            _log(
              '🔁 Additional buffered data present (${_rxBuffer.length} bytes), scanning for next frame...',
            );
          }
          continue;
        }

        // Not enough data yet for this frame
        final expected = _expectedImageSize > 0 ? '$_expectedImageSize' : '?';
        _log(
          '⏳ Waiting for more image data (${_rxBuffer.length}/$expected bytes buffered)',
        );
        return;
      }

      // Nothing else to do
      break;
    }
  }

  // Parse button or voice command messages from ESP32
  // Format: "BTN\n<id>\n<event>\n" or "VOICE\n<text>\n"
  Map<String, dynamic>? _parseButtonOrVoiceCommand(List<int> data) {
    try {
      final text = utf8.decode(data, allowMalformed: true);

      // Check for button message: "BTN\n<id>\n<event>\n"
      if (text.startsWith('BTN\n')) {
        final lines = text.split('\n');
        if (lines.length >= 3) {
          final buttonId = lines[1];
          final event = lines[2];
          return {'type': 'button', 'data': '$buttonId:$event'};
        }
      }

      // Check for voice command: "VOICE\n<text>\n"
      if (text.startsWith('VOICE\n')) {
        final lines = text.split('\n');
        if (lines.length >= 2) {
          final voiceText = lines[1];
          if (voiceText.isNotEmpty) {
            return {'type': 'voice', 'data': voiceText};
          }
        }
      }

      // Check for recording command: "RECORD\n<command>\n"
      if (text.startsWith('RECORD\n')) {
        final lines = text.split('\n');
        if (lines.length >= 2) {
          final command = lines[1];
          if (command.isNotEmpty) {
            return {'type': 'record', 'data': command};
          }
        }
      }
    } catch (e) {
      // Not a text message, likely binary image data
    }
    return null;
  }

  int _indexOfSequence(List<int> buffer, List<int> sequence) {
    if (sequence.isEmpty || buffer.isEmpty || sequence.length > buffer.length) {
      return -1;
    }
    final lastStart = buffer.length - sequence.length;
    for (int i = 0; i <= lastStart; i++) {
      bool match = true;
      for (int j = 0; j < sequence.length; j++) {
        if (buffer[i + j] != sequence[j]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
  }

  int _indexOfByteFrom(List<int> buffer, int value, int fromIndex) {
    for (int i = fromIndex; i < buffer.length; i++) {
      if (buffer[i] == value) return i;
    }
    return -1;
  }

  void _shrinkBufferKeepTail(List<int> buffer, int keep) {
    if (buffer.length <= keep) return;
    buffer.removeRange(0, buffer.length - keep);
  }

  // ---------------------------------------------------------------------------
  Future<bool> connectByName(String deviceName) async {
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
      await Future.delayed(const Duration(seconds: 2));

      List<ScanResult> results = [];
      var subscription = FlutterBluePlus.scanResults.listen((s) {
        results = s;
      });

      await Future.delayed(const Duration(seconds: 2));
      await subscription.cancel();
      await FlutterBluePlus.stopScan();

      BluetoothDevice? target;
      for (var r in results) {
        if (r.device.platformName == deviceName) {
          target = r.device;
          break;
        }
      }

      if (target != null) return await connect(target);
      _log('Device $deviceName not found');
      return false;
    } catch (e) {
      _log('Error connecting by name: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  Future<void> disconnect() async {
    try {
      _connSub?.cancel();
      _connSub = null;
      await _imageCharacteristic?.setNotifyValue(false);
      await _buttonCharacteristic?.setNotifyValue(false);
      await _voiceCharacteristic?.setNotifyValue(false);

      await _connectedDevice?.disconnect();
      _connectedDevice = null;
      _discoveredServices = null;
      _audioOutputCharacteristic = null;
      _imageCharacteristic = null;
      _buttonCharacteristic = null;
      _voiceCharacteristic = null;
      _isConnected = false;
      // Reset parsing state
      _awaitingHeader = true;
      _headerBuffer.clear();
      _imageBuffer.clear();
      _expectedImageSize = 0;
      _receivingImage = false;
      _log('🔌 Disconnected.');
    } catch (e) {
      _log('Error disconnecting: $e');
    }
  }

  // ---------------------------------------------------------------------------
  Stream<BluetoothAdapterState> get bluetoothState =>
      FlutterBluePlus.adapterState;
  Future<bool> get isAvailable => FlutterBluePlus.isAvailable;

  Map<String, dynamic>? getConnectedDeviceInfo() {
    if (_connectedDevice == null) return null;
    return {
      'id': _connectedDevice!.remoteId.toString(),
      'name': _connectedDevice!.platformName,
      'type': 'BLE',
    };
  }

  BluetoothDevice? get connectedDevice => _connectedDevice;
  List<BluetoothService>? getServices() => _discoveredServices;

  // ---------------------------------------------------------------------------
  /// Request ESP32 to capture and send an image
  /// Returns a Future that completes when image is received (via onImageReceived callback)
  Future<void> requestImageCapture() async {
    if (!_isConnected || _imageCharacteristic == null) {
      _log('❌ Cannot request image: not connected or no image characteristic');
      throw Exception('Not connected to ESP32');
    }

    // Send a command to trigger image capture
    // ESP32 should recognize this command and call sendCameraImage()
    // Using "CAPTURE" command
    try {
      final command = utf8.encode('CAPTURE\n');
      await _imageCharacteristic!.write(command, withoutResponse: false);
      _log('📸 Requested image capture from ESP32');
    } catch (e) {
      _log('❌ Error requesting image capture: $e');
      rethrow;
    }
  }

  Future<void> sendData(List<int> data) async {
    if (_connectedDevice == null || _imageCharacteristic == null) {
      _log('No device connected or characteristic found');
      return;
    }
    try {
      await _imageCharacteristic!.write(data);
      _log('Data sent: ${data.length} bytes');
    } catch (e) {
      _log('Error sending data: $e');
    }
  }

  Future<void> sendAudioToBoneConduction(Uint8List audioData) async {
    if (_connectedDevice == null || _audioOutputCharacteristic == null) {
      _log('No device or audio characteristic');
      return;
    }

    const chunk = 20;
    for (int i = 0; i < audioData.length; i += chunk) {
      final end = (i + chunk < audioData.length) ? i + chunk : audioData.length;
      await _audioOutputCharacteristic!.write(
        audioData.sublist(i, end),
        withoutResponse: true,
      );
    }
    _log('Audio sent: ${audioData.length} bytes');
  }

  Future<void> sendTextForTTS(String text) async {
    if (_connectedDevice == null || _audioOutputCharacteristic == null) return;
    try {
      final data = utf8.encode(text);
      await sendAudioToBoneConduction(Uint8List.fromList(data));
      _log('Text sent for TTS: $text');
    } catch (e) {
      _log('Error TTS: $e');
    }
  }

  void dispose() {
    stopScan();
    _scanSubscription?.cancel();
    disconnect();
    _logController.close();
  }
}
