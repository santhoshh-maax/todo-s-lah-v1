import 'dart:io';
import 'package:flutter/material.dart'; // Ensure this is present
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse details) async {
  // This is the most important line for background execution!
  WidgetsFlutterBinding.ensureInitialized();

  if (details.actionId == 'mark_done') {
    final String? payload = details.payload;
    if (payload == null) return;

    final prefs = await SharedPreferences.getInstance();
    // Force the phone to refresh the file from the disk
    await prefs.reload(); 

    List<String> completedList = prefs.getStringList('taskCompleted') ?? [];
    
    int index = int.tryParse(payload) ?? -1;

    if (index >= 0 && index < completedList.length) {
      completedList[index] = 'true';
      // Use await to ensure the write finishes before the OS kills this process
      await prefs.setStringList('taskCompleted', completedList);
      debugPrint("✅ Background mark_done worked for index $index");
    }
  }
}

// ... rest of your NotiService class follows ...
class NotiService {
  static final NotiService _instance = NotiService._internal();
  factory NotiService() => _instance;
  NotiService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  String _selectedTimeZone = 'UTC';
  Function(int)? onMarkTaskCompleted;

  Future<void> initNotification() async {
    tz_data.initializeTimeZones();
    await loadSavedTimeZone();

    const androidInit = AndroidInitializationSettings('@mipmap/icon');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.actionId == 'mark_done') {
          // Trigger the background logic manually for foreground clicks
          notificationTapBackground(details);
          if (onMarkTaskCompleted != null) {
            onMarkTaskCompleted!(int.parse(details.payload ?? '0'));
          }
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
  }

  Future<void> checkExactAlarmPermission() async {
    if (Platform.isAndroid) {
      final androidImplementation = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
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
    String soundName = 'alarm1',
  }) async {
    await checkExactAlarmPermission();

    AndroidNotificationDetails androidPlatformChannelSpecifics = 
    AndroidNotificationDetails(
      'alarm_channel_$soundName', 
      'Task Alarms',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(soundName), 
      actions: [
        const AndroidNotificationAction(
          'mark_done',
          'Mark as Completed',
          showsUserInterface: true, // Set to true to ensure click registers on Oppo
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
        feedbackMessage = "Reminder window passed. Alert set for exact time.";
      } else {
        notificationTime = now.add(const Duration(seconds: 5));
        feedbackMessage = "Time passed. Notifying you now.";
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
/// Request Battery Optimization Exemption
Future<void> requestBatteryOptimizations() async {
  if (Platform.isAndroid) {
    var status = await Permission.ignoreBatteryOptimizations.status;
    if (status.isDenied) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }
}