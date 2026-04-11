import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';

class NotiService {
  static final NotiService _instance = NotiService._internal();
  factory NotiService() => _instance;
  NotiService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  String _selectedTimeZone = 'UTC';
  Function(int)? onMarkTaskCompleted;

  Future<void> initNotification() async {
    tz_data.initializeTimeZones();
   const androidInit = AndroidInitializationSettings('ic_notification');
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

  Future<void> loadSavedTimeZone() async {
    _selectedTimeZone = await FlutterTimezone.getLocalTimezone();
  }

  NotificationDetails _notificationDetails({
    bool withActions = false,
    String? payload,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'todo_channel',
        'Task Reminders',
        importance: Importance.max,
        priority: Priority.high,
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
    final location = tz.getLocation(_selectedTimeZone);

    // 1. Calculate the exact time of the task
    var taskTime = tz.TZDateTime(location, year, month, day, hour, minute);

    // 2. Subtract the reminder offset
    var notificationTime = taskTime.subtract(
      Duration(minutes: reminderMinutes),
    );

    print("------------------------------------------");
    print("🚀 [NotiService] Attempting to schedule...");
    print("📌 ID: $id | Title: $title");
    print("⏰ Task Time: $taskTime");
    print(
      "🔔 Notification Time: $notificationTime ($reminderMinutes mins early)",
    );

    // 3. Prevent scheduling in the past
    final now = tz.TZDateTime.now(location);
    if (notificationTime.isBefore(now)) {
      if (repeat == 'Daily') {
        notificationTime = notificationTime.add(const Duration(days: 1));
      } else if (repeat == 'Weekly') {
        notificationTime = notificationTime.add(const Duration(days: 7));
      } else {
        // If not repeating and time passed, schedule 5 seconds from now so the user sees it immediately
        notificationTime = now.add(const Duration(seconds: 5));
      }
      print("⚠️ [NotiService] Adjusted to: $notificationTime");
    }

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      notificationTime,
      _notificationDetails(withActions: true, payload: id.toString()),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: repeat == 'Daily'
          ? DateTimeComponents.time
          : repeat == 'Weekly'
          ? DateTimeComponents.dayOfWeekAndTime
          : null,
    );

    print("✅ [NotiService] Scheduled Successfully.");
    print("------------------------------------------");
  }
  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
    print("🗑️ [NotiService] Notification $id cancelled.");
  }
}
// Add this method to fix the error in main.dart
  