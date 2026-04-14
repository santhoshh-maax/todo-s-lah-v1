import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse details) async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  if (details.actionId == 'mark_done') {
    final String? payloadId = details.payload;
    if (payloadId == null) return;

    await prefs.setBool('status_$payloadId', true);

    List<String> todoList = prefs.getStringList('todoList') ?? [];
    List<String> completedList = prefs.getStringList('taskCompleted') ?? [];

    for (int i = 0; i < todoList.length; i++) {
      final parts = todoList[i].split('\n');
      final String storedId = parts.last.trim();

      if (storedId == payloadId) {
        while (completedList.length <= i) completedList.add('false');
        completedList[i] = 'true';
        break;
      }
    }

    await prefs.setStringList('taskCompleted', completedList);
  }
}
class NotiService {
  static final NotiService _instance = NotiService._internal();
  factory NotiService() => _instance;
  NotiService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  String _selectedTimeZone = 'UTC';
  Function(int)? onMarkTaskCompleted;

  Future<NotificationAppLaunchDetails?> getLaunchDetails() async {
  return _plugin.getNotificationAppLaunchDetails();
}


  Future<void> initNotification() async {
    tz_data.initializeTimeZones();
    await loadSavedTimeZone();

    const androidInit = AndroidInitializationSettings('@mipmap/icon');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) async {
      if (details.actionId == 'mark_done') {
        final String? payloadId = details.payload;
        if (payloadId == null) return;

        final prefs = await SharedPreferences.getInstance();

        // ✅ SAME LOGIC AS BACKGROUND
        await prefs.setBool('status_$payloadId', true);
        debugPrint("💾 Saved status_$payloadId = true");

        await prefs.reload();

        List<String> todoList = prefs.getStringList('todoList') ?? [];
        List<String> completedList = prefs.getStringList('taskCompleted') ?? [];

        for (int i = 0; i < todoList.length; i++) {
          final parts = todoList[i].split('\n');
final String storedId = parts.last.trim();
  debugPrint("🔍 Comparing stored: $storedId vs payload: $payloadId");

if (storedId == payloadId) {
            while (completedList.length <= i) completedList.add('false');
            completedList[i] = 'true';
            break;
          }
        }

        await prefs.setStringList('taskCompleted', completedList);

        debugPrint("✅ Foreground: Task $payloadId marked complete");

        // 🔁 Notify UI to refresh
        if (onMarkTaskCompleted != null) {
          onMarkTaskCompleted?.call(0);
        }
      }
    },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
  }

  Future<void> requestBatteryOptimizations() async {
    if (Platform.isAndroid) {
      await Future.delayed(const Duration(seconds: 2));
      var status = await Permission.ignoreBatteryOptimizations.status;
      if (!status.isGranted) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    }
  }

  Future<void> checkExactAlarmPermission() async {
    if (Platform.isAndroid) {
      final androidImplementation = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.requestExactAlarmsPermission();
      }
    }
  }

  Future<void> loadSavedTimeZone() async {
    try {
      _selectedTimeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(_selectedTimeZone));
    } catch (e) {
      _selectedTimeZone = 'UTC';
      debugPrint("Timezone Error: $e");
    }
  }

  Future<String?> scheduleNotification({
  required int id,
  required String payload,
  required String title,
  required String body,
  required int year,
  required int month,
  required int day,
  required int hour,
  required int minute,
  String repeat = 'None',
  int reminderMinutes = 0,
  String soundName = 'alarm1', // keep but ignore
}) async {
  await checkExactAlarmPermission();

  // 🔥 ALWAYS LOAD SAVED VALUE
  final prefs = await SharedPreferences.getInstance();
  final savedAlarm = prefs.getString('selectedAlarm') ?? 'alarm1';

  debugPrint("🔔 Using alarm sound: $savedAlarm");

  AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'alarm_channel_${savedAlarm}_v4', // 👈 important (new channel)
    'Task Alarms',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,

    // ✅ USE SAVED VALUE
    sound: RawResourceAndroidNotificationSound(savedAlarm),

    actions: [
      const AndroidNotificationAction(
        'mark_done',
        'Mark as Completed',
        showsUserInterface: true,
        cancelNotification: true,
      ),
    ],
  );
    final location = tz.getLocation(_selectedTimeZone);
    var taskTime = tz.TZDateTime(location, year, month, day, hour, minute);
    var notificationTime = taskTime.subtract(Duration(minutes: reminderMinutes));
    final now = tz.TZDateTime.now(location);

    String? feedbackMessage;
    if (notificationTime.isBefore(now)) {
      if (taskTime.isAfter(now)) {
        notificationTime = taskTime;
        feedbackMessage = "Set for exact time.";
      } else {
        notificationTime = now.add(const Duration(seconds: 5));
        feedbackMessage = "Notifying you now.";
      }
    }

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        notificationTime,
        NotificationDetails(android: androidPlatformChannelSpecifics),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      return feedbackMessage;
    } catch (e) {
      debugPrint("Schedule Failure: $e");
      return "Error: Could not schedule.";
    }
  }

  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }
}