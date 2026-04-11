import 'dart:io';
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
    await loadSavedTimeZone(); // Initialize timezone before scheduling

    // Note: If ic_launcher fails, ensure you have ic_launcher.png in 
    // android/app/src/main/res/drawable/
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

    // print("✅ Notifications Ready");
  }

  /// 2. Request Exact Alarm Permission (Fixes the PlatformException)
  Future<void> checkExactAlarmPermission() async {
    if (Platform.isAndroid) {
      final androidImplementation = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        final bool? granted = await androidImplementation.requestExactAlarmsPermission();
        if (granted == false) {
          // print("⚠️ Exact Alarm permission was denied by the user.");
        } else {
          // print("✅ Exact Alarm permission granted.");
        }
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
    }
  }

  /// 4. Notification Visual Details
  NotificationDetails _notificationDetails({
    bool withActions = false,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'todo_channel',
        'Task Reminders',
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: true, // This helps the notification show up over the lockscreen
        category: AndroidNotificationCategory.alarm,
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
    // Crucial: check permission every time before scheduling to avoid crashes
    await checkExactAlarmPermission();

    final location = tz.getLocation(_selectedTimeZone);

    // Calculate time
    var taskTime = tz.TZDateTime(location, year, month, day, hour, minute);
    var notificationTime = taskTime.subtract(Duration(minutes: reminderMinutes));

    final now = tz.TZDateTime.now(location);

    // print("------------------------------------------");
    // print("🚀 [NotiService] Attempting to schedule...");
    // print("📌 ID: $id | Title: $title");
    // print("⏰ Task Time: $taskTime");
    // print("🔔 Notification Time: $notificationTime ($reminderMinutes mins early)");

    // Prevent scheduling in the past
    if (notificationTime.isBefore(now)) {
      if (repeat == 'Daily') {
        notificationTime = notificationTime.add(const Duration(days: 1));
      } else if (repeat == 'Weekly') {
        notificationTime = notificationTime.add(const Duration(days: 7));
      } else {
        // If the time is within the last few minutes, show it almost immediately
        notificationTime = now.add(const Duration(seconds: 5));
      }
      // print("⚠️ [NotiService] Time was in past. Adjusted to: $notificationTime");
    }

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        notificationTime,
        _notificationDetails(withActions: true),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: id.toString(),
        matchDateTimeComponents: repeat == 'Daily'
            ? DateTimeComponents.time
            : repeat == 'Weekly'
                ? DateTimeComponents.dayOfWeekAndTime
                : null,
      );
      // print("✅ [NotiService] Scheduled Successfully.");
    } catch (e) {
      // print("❌ [NotiService] Failed to schedule: $e");
    }
    // print("------------------------------------------");
  }

  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
    // print("🗑️ [NotiService] Notification $id cancelled.");
  }
}



Future<void> requestBatteryOptimizations() async {
  if (Platform.isAndroid) {
    var status = await Permission.ignoreBatteryOptimizations.status;
    if (status.isDenied) {
      // This opens the system dialog for the user to select "Allow"
      await Permission.ignoreBatteryOptimizations.request();
    }
  }
}