import 'dart:io';
import 'dart:ui';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPreferences.getInstance();
  
  DartPluginRegistrant.ensureInitialized();
  // Initialize notifications before the app starts to catch payloads
  await _initNotifications(); 
  
  runApp(const MyApp());
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
      if (savedTheme == 'Light') {
        _themeMode = ThemeMode.light;
      } else if (savedTheme == 'Dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system;
      }
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
    WidgetsBinding.instance.addObserver(this); 

 WidgetsBinding.instance.addPostFrameCallback((_) {
  _handleNotificationLaunch();
});
    
    // 1. Initial Load with the new helper
    _initialLoad(); 

    askNotificationPermission();
    Future.delayed(const Duration(seconds: 3), () {
      NotiService().requestBatteryOptimizations();
    });

    NotiService().onMarkTaskCompleted = (int taskId) {
      if (mounted) syncAppWithDisk();
    };
  }

  Future<void> _initialLoad() async {
    await syncAppWithDisk();
    if (mounted) setState(() {}); 
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    textEditingController.dispose();
    super.dispose();
  }

  @override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) {
    debugPrint("🔄 App Resumed: Syncing with disk...");
    Future.delayed(const Duration(milliseconds: 500), () {
      syncAppWithDisk();
    });
  }
}


Future<void> syncAppWithDisk() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload(); 
  
  List<String> storedTodo = prefs.getStringList('todoList') ?? [];
  // Use a temporary list to avoid mid-loop UI flickers
  List<bool> syncedStatus = [];

  for (int i = 0; i < storedTodo.length; i++) {
    final parts = storedTodo[i].split('\n');
    // Ensure we are grabbing the ID correctly (usually the last part)
    final String taskId = parts.last.trim();
    
    // 1. Check the Atomic Boolean (from background)
    bool isDoneAtomic = prefs.getBool('status_$taskId') ?? false;
      debugPrint("📥 Checking status_$taskId = $isDoneAtomic");
    // 2. Check the legacy String List (from manual ticks)
    List<String> storedStatusList = prefs.getStringList('taskCompleted') ?? [];
    bool isDoneInList = (i < storedStatusList.length && storedStatusList[i] == 'true');

    // If either is true, the task is DONE
    syncedStatus.add(isDoneAtomic || isDoneInList);
  }

  if (mounted) {
    setState(() {
      todoList = storedTodo;
      taskCompleted = syncedStatus;
    });
  }
  debugPrint("✅ UI SYNC: ${todoList.length} tasks | ${taskCompleted.where((e) => e).length} ticks.");
  
}

  Future<void> askNotificationPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        await Permission.notification.request();
      }
    }
  }

  Future<void> saveTasks() async {
  final prefs = await SharedPreferences.getInstance();
  // Ensure these are awaited!
  await prefs.setStringList('todoList', todoList);
  await prefs.setStringList('taskCompleted', taskCompleted.map((e) => e.toString()).toList());
  debugPrint("📦 Current Tasks: $todoList");
  debugPrint("💾 Data saved to disk.");
}

Future<void> _handleNotificationLaunch() async {
  debugPrint("🚀 HANDLE FUNCTION CALLED");
  final noti = NotiService();
  final details = await noti.getLaunchDetails();

  if (details?.didNotificationLaunchApp ?? false) {
    final payload = details!.notificationResponse?.payload;

    if (payload != null) {
      debugPrint("🔥 FIX: Saving from MainApp: $payload");

      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool('status_$payload', true);

      List<String> todoList = prefs.getStringList('todoList') ?? [];
      List<String> completedList = prefs.getStringList('taskCompleted') ?? [];

      for (int i = 0; i < todoList.length; i++) {
        final parts = todoList[i].split('\n');
        final String storedId = parts.last.trim();

        if (storedId == payload) {
          while (completedList.length <= i) completedList.add('false');
          completedList[i] = 'true';
          break;
        }
      }

      await prefs.setStringList('taskCompleted', completedList);
      await Future.delayed(const Duration(milliseconds: 200));

      await syncAppWithDisk(); // ✅ FORCE UI UPDATE
    }
  }
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

    if (pickedDate != null && mounted) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null && mounted) {
        final dateString = DateFormat('dd/MM/yyyy').format(pickedDate);
        final dt = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, 
                            pickedTime.hour, pickedTime.minute);
        final formattedTime = DateFormat('hh:mm a').format(dt);
        
        final int uniqueId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
        debugPrint("🆔 Generated Task ID: $uniqueId");
        debugPrint("🆔 New Task Created → ID: $uniqueId | Title: ${textEditingController.text}");

        final resultMessage = await NotiService().scheduleNotification(
          id: uniqueId,
          payload: uniqueId.toString(),
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

        final finalTaskString = "${textEditingController.text}\n$dateString\n$formattedTime\n$repeatValue\n$uniqueId";

        setState(() {
          todoList.add(finalTaskString);
          taskCompleted.add(false);
          textEditingController.clear();
        });
        saveTasks();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(resultMessage ?? "Task scheduled!"),
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
                    setState(() => selectedAlarm = newAlarm);
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
              decoration: const InputDecoration(
                hintText: 'What needs to be done?',
                border: InputBorder.none,
                prefixIcon: Icon(Icons.edit_note_rounded, color: Colors.blue),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
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
          // KEY FIX: Combines content and status to force redraw
          key: ValueKey("${todoList[index]}_${taskCompleted[index]}"), 
          child: ListTile(
            leading: Checkbox(
              value: taskCompleted[index],
              // Inside your ListView Checkbox onChanged:
                onChanged: (val) async {
                if (val == null) return;

                // 1. Clean the ID to ensure it matches the background payload exactly
                final parts = todoList[index].split('\n');
                final String taskId = parts.last.trim(); 

                setState(() {
                  taskCompleted[index] = val;
                });

                // 2. Open SharedPreferences
                final prefs = await SharedPreferences.getInstance();
                
                // 3. Save the Atomic Key (Primary source for background sync)
                await prefs.setBool('status_$taskId', val); 

                // 4. Update the list and WAIT for it to finish saving
                // Make sure your saveTasks() function is awaited!
                await saveTasks(); 
                
                debugPrint("✅ Manual Tick: Saved status_$taskId as $val");
              },
            ),
            title: Text(
              parts[0], 
              style: TextStyle(
                decoration: taskCompleted[index] ? TextDecoration.lineThrough : null
              )
            ),
            subtitle: Text("${parts[1]} at ${parts[2]}"),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
             onPressed: () {
              final deletedTask = todoList[index];
              final deletedStatus = taskCompleted[index];

              // 🆔 Extract ID (optional but good)
              final parts = deletedTask.split('\n');
              final String taskId = parts.last.trim();

              debugPrint("🗑️ Deleting Task → ID: $taskId");

              // 🔕 Cancel notification
              if (parts.length >= 5) {
                int? notiId = int.tryParse(parts[4]);
                if (notiId != null) {
                  NotiService().cancelNotification(notiId);
                  debugPrint("🔕 Notification cancelled for ID: $notiId");
                }
              }

              setState(() {
                todoList.removeAt(index);
                taskCompleted.removeAt(index);
              });

              saveTasks();

              // 🔥 SHOW SNACKBAR WITH UNDO
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text("Task deleted"),
                  duration: const Duration(seconds: 3),

                  action: SnackBarAction(
                    label: "UNDO",
                    onPressed: () {
                      setState(() {
                        todoList.insert(index, deletedTask);
                        taskCompleted.insert(index, deletedStatus);
                      });

                      saveTasks();

                      debugPrint("↩️ Undo delete → Restored task $taskId");
                    },
                  ),
                ),
              );
            },
                        ),
          ),
        );
      },
    );
  }
}