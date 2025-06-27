class BluetoothService {
  // TODO: Implement Bluetooth communication methods

  // Mock scan for devices
  Future<List<String>> scanForDevices() async {
    await Future.delayed(const Duration(seconds: 2));
    return [
      'AEyes Glasses',
      'ESP32 Device',
      'Bluetooth Speaker',
    ];
  }

  // Mock connect to device
  Future<bool> connect(String device) async {
    await Future.delayed(const Duration(seconds: 1));
    // Simulate successful connection only for AEyes Glasses
    return device.contains('AEyes');
  }

  // Mock disconnect
  Future<void> disconnect() async {
    await Future.delayed(const Duration(milliseconds: 500));
  }
} 