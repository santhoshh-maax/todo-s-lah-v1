import 'dart:io';
import 'package:flutter/foundation.dart'; // Added for debugPrint
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';

class NotiService {
  static final NotiService _instance = NotiService._internal();
  factory NotiService() => _instance;
  NotiService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  String _selectedTimeZone = 'UTC';
  Function(int)? onMarkTaskCompleted;

  /// 1. Initialize Notifications
  Future<void> initNotification() async {
    tz_data.initializeTimeZones();
    await loadSavedTimeZone();

    const androidInit = AndroidInitializationSettings('@mipmap/icon');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.actionId == 'mark_done' && onMarkTaskCompleted != null) {
          onMarkTaskCompleted!(int.parse(details.payload ?? '0'));
        }
      },
    );
  }

  /// 2. Request Exact Alarm Permission
  Future<void> checkExactAlarmPermission() async {
    if (Platform.isAndroid) {
      final androidImplementation = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        // In production, we just request it; the OS handles the UI
        await androidImplementation.requestExactAlarmsPermission();
      }
    }
  }

  /// 3. Load Device Timezone
  Future<void> loadSavedTimeZone() async {
    try {
      _selectedTimeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(_selectedTimeZone));
    } catch (e) {
      _selectedTimeZone = 'UTC';
      debugPrint("Timezone Error: $e");
    }
  }

  /// 4. Notification Visual Details
  NotificationDetails _notificationDetails({
    bool withActions = false,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'todo_channel_id_01', // Changed ID to ensure a fresh channel in release
        'Task Reminders',
        channelDescription: 'Notifications for your scheduled tasks',
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: true, 
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public, // Ensures it shows on lockscreen
        actions: withActions
            ? [
                const AndroidNotificationAction(
                  'mark_done',
                  'Mark as Completed',
                  showsUserInterface: true,
                ),
              ]
            : null,
      ),
    );
  }

  /// 5. Schedule Logic
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required int year,
    required int month,
    required int day,
    required int hour,
    required int minute,
    String repeat = 'None',
    int reminderMinutes = 0,
  }) async {
    await checkExactAlarmPermission();

    final location = tz.getLocation(_selectedTimeZone);
    var taskTime = tz.TZDateTime(location, year, month, day, hour, minute);
    var notificationTime = taskTime.subtract(Duration(minutes: reminderMinutes));
    final now = tz.TZDateTime.now(location);

    // Logic to handle past times
    if (notificationTime.isBefore(now)) {
      if (repeat == 'Daily') {
        notificationTime = notificationTime.add(const Duration(days: 1));
      } else if (repeat == 'Weekly') {
        notificationTime = notificationTime.add(const Duration(days: 7));
      } else {
        // Show in 5 seconds if the user picked a time that just passed
        notificationTime = now.add(const Duration(seconds: 5));
      }
    }

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        notificationTime,
        _notificationDetails(withActions: true),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // Keeps it working in battery saver
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: id.toString(),
        matchDateTimeComponents: repeat == 'Daily'
            ? DateTimeComponents.time
            : repeat == 'Weekly'
                ? DateTimeComponents.dayOfWeekAndTime
                : null,
      );
    } catch (e) {
      debugPrint("Schedule Failure: $e");
    }
  }

  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }
}

/// Request Battery Optimization Exemption
Future<void> requestBatteryOptimizations() async {
  if (Platform.isAndroid) {
    var status = await Permission.ignoreBatteryOptimizations.status;
    if (status.isDenied) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }
}