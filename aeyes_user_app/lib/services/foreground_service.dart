import 'dart:io';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

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

  static Future<void> startIfNeeded() async {
    if (!Platform.isAndroid) return;
    final isRunning = await FlutterForegroundTask.isRunningService;
    if (!isRunning) {
      await FlutterForegroundTask.startService(
        notificationTitle: 'AEyes is running',
        notificationText: 'Bluetooth connection will remain active.',
      );
    }
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    final isRunning = await FlutterForegroundTask.isRunningService;
    if (isRunning) {
      await FlutterForegroundTask.stopService();
    }
  }
}


