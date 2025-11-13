import 'dart:io';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';

class ForegroundServiceController {
  static Future<void> initialize() async {
    if (!Platform.isAndroid) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'aeyes_fg_channel',
        channelName: 'AEyes Background Service',
        channelDescription: 'Keeps Bluetooth active for background processing.',
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: false),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 15000,
        isOnceEvent: false,
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Start the foreground service only if Bluetooth permissions are granted
  static Future<void> startIfNeeded() async {
    if (!Platform.isAndroid) return;
    
    // Check if Bluetooth permissions are granted (required for connectedDevice service type)
    final hasBluetoothConnect = await Permission.bluetoothConnect.isGranted;
    final hasBluetoothScan = await Permission.bluetoothScan.isGranted;
    
    if (!hasBluetoothConnect || !hasBluetoothScan) {
      print('⚠️ Foreground service not started: Bluetooth permissions not granted');
      return;
    }
    
    try {
      final isRunning = await FlutterForegroundTask.isRunningService;
      if (!isRunning) {
        await FlutterForegroundTask.startService(
          notificationTitle: 'AEyes is running',
          notificationText: 'Bluetooth connection will remain active.',
        );
        print('✅ Foreground service started successfully');
      }
    } catch (e) {
      print('⚠️ Failed to start foreground service: $e');
      // Don't crash the app if service fails to start
    }
  }

  /// Start the service after permissions are granted (call this from BluetoothScreen)
  static Future<void> startAfterPermissionsGranted() async {
    await startIfNeeded();
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      final isRunning = await FlutterForegroundTask.isRunningService;
      if (isRunning) {
        await FlutterForegroundTask.stopService();
      }
    } catch (e) {
      print('⚠️ Failed to stop foreground service: $e');
    }
  }
}


