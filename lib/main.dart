import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';

// Your local files
import 'splash_screen.dart';
import 'noti_service.dart';
import 'calendar_page.dart';
import 'settings_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
  _initNotifications();
}

Future<void> _initNotifications() async {
  try {
    final noti = NotiService();
    await noti.initNotification();
    debugPrint("✅ Notifications Ready");
  } catch (e) {
    debugPrint("❌ Notification Init Failed: $e");
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedTheme = prefs.getString('themeMode');
    setState(() {
      if (savedTheme == 'Light') _themeMode = ThemeMode.light;
      else if (savedTheme == 'Dark') _themeMode = ThemeMode.dark;
      else _themeMode = ThemeMode.system;
    });
  }

  void updateTheme(ThemeMode newMode) {
    setState(() => _themeMode = newMode);
  }

  @override
  Widget build(BuildContext context) { 
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      home: SplashScreen(onThemeChanged: updateTheme), 
    );
  }
}

class MainApp extends StatefulWidget {
  final Function(ThemeMode) onThemeChanged;
  const MainApp({super.key, required this.onThemeChanged});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  List<String> todoList = [];
  List<bool> taskCompleted = [];
  TextEditingController textEditingController = TextEditingController();
  String repeatValue = 'None';
  int reminderValue = 0; 
  String selectedAlarm = 'alarm1';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Observe app lifecycle
    askNotificationPermission();
    loadTasks();
    _loadSettings();

    // Foreground listener
    NotiService().onMarkTaskCompleted = (int taskId) {
      if (mounted) {
        loadTasks(); // Refresh from disk when foreground action happens
      }
    };
  }

  // --- NEW: Refresh tasks when you reopen the app ---
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      loadTasks(); // Reload from SharedPreferences when app is resumed
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedAlarm = prefs.getString('user_alarm') ?? 'alarm1';
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    textEditingController.dispose();
    super.dispose();
  }

  Future<void> askNotificationPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        await Permission.notification.request();
      }
    }
  }

  // --- FIX: Use consistent keys ---
  Future<void> saveTasks() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList('todoList', todoList);
  // Ensure this key is 'taskCompleted' (no extra 's')
  await prefs.setStringList('taskCompleted', taskCompleted.map((e) => e.toString()).toList());
}

  Future<void> loadTasks() async {
  final prefs = await SharedPreferences.getInstance();
  
  // Reloading directly from disk
  final List<String> loadedList = prefs.getStringList('todoList') ?? [];
  final List<String> loadedCompleted = prefs.getStringList('taskCompleted') ?? [];

  setState(() {
    todoList = loadedList;
    // Ensure we are parsing the fresh 'true'/'false' strings from the background
    taskCompleted = loadedCompleted.map((e) => e == 'true').toList();
    
    // Safety check: match lengths
    while (taskCompleted.length < todoList.length) {
      taskCompleted.add(false);
    }
  });
}

  Future<void> pickDateTimeAndAddTask() async {
    if (textEditingController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a task first lah!")),
      );
      return;
    }

    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        final dateString = DateFormat('dd/MM/yyyy').format(pickedDate);
        final dt = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
        final formattedTime = DateFormat('hh:mm a').format(dt);
        
        final finalTaskString = "${textEditingController.text}\n$dateString\n$formattedTime\n$repeatValue";

        // 1. Generate a unique ID for the notification itself (e.g., 1712912400)
// We use remainder to keep it within Android's integer limits
final int uniqueNotificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);

// 2. Schedule the notification
final resultMessage = await NotiService().scheduleNotification(
  id: uniqueNotificationId,
  payload: todoList.length.toString(), // The index must be passed here
  title: "Todo's lah Task",
  body: textEditingController.text,
  year: pickedDate.year,
  month: pickedDate.month,
  day: pickedDate.day,
  hour: pickedTime.hour,
  minute: pickedTime.minute,
  repeat: repeatValue,
  reminderMinutes: reminderValue,
  soundName: selectedAlarm,
);

// 3. Update the UI and save to disk
setState(() {
  todoList.add(finalTaskString);
  taskCompleted.add(false);
  textEditingController.clear();
});
saveTasks(); // Always save after adding

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(resultMessage ?? "Task scheduled successfully!"),
              backgroundColor: resultMessage != null ? Colors.orangeAccent : Colors.blue,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📝 𝙏𝙤𝙙𝙤_𝙨 𝙡𝙖𝙝'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context, 
              MaterialPageRoute(
                builder: (context) => SettingsPage(
                  onThemeChanged: widget.onThemeChanged,
                  onAlarmChanged: (newAlarm) {
                    setState(() {
                      selectedAlarm = newAlarm;
                    });
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildTaskInputCard(),
            const SizedBox(height: 15),
            _buildTaskListHeader(),
            Expanded(child: _buildTodoListView()),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskInputCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: textEditingController,
              decoration: InputDecoration(
                hintText: 'What needs to be done?',
                border: InputBorder.none,
                prefixIcon: const Icon(Icons.edit_note_rounded, color: Colors.blue),
              ),
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: repeatValue,
                    items: ['None', 'Daily', 'Weekly']
                        .map((val) => DropdownMenuItem(value: val, child: Text(val)))
                        .toList(),
                    onChanged: (v) => setState(() => repeatValue = v!),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: reminderValue,
                    items: const [
                          DropdownMenuItem(value: 0, child: Text("At time", style: TextStyle(fontSize: 14))),
                          DropdownMenuItem(value: 10, child: Text("10m before", style: TextStyle(fontSize: 14))),
                          DropdownMenuItem(value: 15, child: Text("15m before", style: TextStyle(fontSize: 14))),
                          DropdownMenuItem(value: 30, child: Text("30m before", style: TextStyle(fontSize: 14))),
                          DropdownMenuItem(value: 60, child: Text("1h before", style: TextStyle(fontSize: 14))),
                          DropdownMenuItem(value: 1440, child: Text("1d before", style: TextStyle(fontSize: 14))),
                        ],
                    onChanged: (v) => setState(() => reminderValue = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: pickDateTimeAndAddTask,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              icon: const Icon(Icons.add_task_rounded),
              label: const Text(
                "Set Schedule & Add", 
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskListHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("📋 Task List", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ElevatedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(
            builder: (context) => CalendarPage(tasks: todoList.map((task) {
              final parts = task.split('\n');
              return {
                'title': parts[0],
                'date': parts[1],
                'time': parts[2],
                'repeat': parts.length >= 4 ? parts[3] : 'None',
              };
            }).toList()))),
          icon: const Icon(Icons.calendar_month),
          label: const Text("Calendar"),
        ),
      ],
    );
  }

  Widget _buildTodoListView() {
    if (todoList.isEmpty) return const Center(child: Text("No tasks yet!"));
    return ListView.builder(
      itemCount: todoList.length,
      itemBuilder: (context, index) {
        final parts = todoList[index].split('\n');
        return Card(
          child: ListTile(
            leading: Checkbox(
              value: taskCompleted[index],
              onChanged: (val) {
                setState(() => taskCompleted[index] = val!);
                saveTasks();
              },
            ),
            title: Text(parts[0], style: TextStyle(decoration: taskCompleted[index] ? TextDecoration.lineThrough : null)),
            subtitle: Text("${parts[1]} at ${parts[2]}"),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: () {
                NotiService().cancelNotification(index);
                setState(() {
                  todoList.removeAt(index);
                  taskCompleted.removeAt(index);
                });
                saveTasks();
              },
            ),
          ),
        );
      },
    );
  }
}