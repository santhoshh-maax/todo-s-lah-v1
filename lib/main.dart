import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
// 1. You need this specific import for the platform override



// Your local files
import 'splash_screen.dart';
import 'noti_service.dart';
import 'calendar_page.dart';
import 'settings_page.dart';

void main() {
  // 1. Standard Flutter initialization
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Start UI immediately to prevent the OS from timing out the app
  runApp(const MyApp());

  // 3. Initialize notifications in the background WITHOUT battery requests
  _initNotifications();
}

Future<void> _initNotifications() async {
  try {
    final noti = NotiService();
    // Use the fixed icon name (no .png extension)
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
  int reminderValue = 0; // Default to "At time"

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    askNotificationPermission();
    loadTasks();

    NotiService().onMarkTaskCompleted = (int taskId) {
      if (mounted) {
        setState(() {
          if (taskId >= 0 && taskId < taskCompleted.length) {
            taskCompleted[taskId] = true; 
            saveTasks();
          }
        });
      }
    };
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
      // Only call if you have the android_intent package configured
      
    }
  }

  

  Future<void> saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('todoList', todoList);
    await prefs.setStringList('taskCompleted', taskCompleted.map((e) => e.toString()).toList());
  }

  Future<void> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final loadedList = prefs.getStringList('todoList') ?? [];
    final loadedCompleted = prefs.getStringList('taskCompleted') ?? [];

    setState(() {
      todoList = loadedList;
      taskCompleted = loadedCompleted.map((e) => e == 'true').toList();
      // Adjust lengths if mismatched
      while (taskCompleted.length < todoList.length) {
        taskCompleted.add(false);
      }
    });
  }

  Future<void> pickDateTimeAndAddTask() async {
    final input = textEditingController.text.trim();
    if (input.isEmpty) return;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (pickedTime == null) return;

    _createTask(input, pickedDate, pickedTime);
  }

  void _createTask(String input, DateTime pickedDate, TimeOfDay pickedTime) {
    final dateString = DateFormat('dd/MM/yyyy').format(pickedDate);
    final dt = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
    final formattedTime = DateFormat('hh:mm a').format(dt);
    
    // Format: Title | Date | Time | Repeat
    final finalTask = "$input\n$dateString\n$formattedTime\n$repeatValue";

    setState(() {
      todoList.add(finalTask);
      taskCompleted.add(false);
    });

    saveTasks(); 

    NotiService().scheduleNotification(
  id: todoList.length - 1,
  title: "Task Reminder",
  body: "📝 $input",
  year: pickedDate.year,
  month: pickedDate.month,
  day: pickedDate.day,
  hour: pickedTime.hour,
  minute: pickedTime.minute,
  repeat: repeatValue,
  reminderMinutes: reminderValue, // 🔥 Pass the new value here
);

    textEditingController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📝 𝙏𝙤𝙙𝙤_𝙨 𝙡𝙖𝙝'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (context) => SettingsPage(onThemeChanged: widget.onThemeChanged))),
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
    shadowColor: Colors.black26,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text input field
          TextField(
            controller: textEditingController,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: 'What needs to be done?',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              border: InputBorder.none,
              prefixIcon: const Icon(Icons.edit_note_rounded, color: Colors.blue),
            ),
          ),
          const Divider(height: 20, thickness: 1),
          
          // Selection Controls Row
          Row(
            children: [
              // Repeat Selection
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(" Repeat", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: repeatValue,
                        items: ['None', 'Daily', 'Weekly']
                            .map((val) => DropdownMenuItem(value: val, child: Text(val, style: const TextStyle(fontSize: 14))))
                            .toList(),
                        onChanged: (v) => setState(() => repeatValue = v!),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 15),
              
              // Reminder Selection
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(" Reminder", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    DropdownButtonHideUnderline(
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
              ),
            ],
          ),
          
          const SizedBox(height: 15),
          
          // Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: pickDateTimeAndAddTask,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add_task_rounded),
              label: const Text("Set Schedule & Add", style: TextStyle(fontWeight: FontWeight.bold)),
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