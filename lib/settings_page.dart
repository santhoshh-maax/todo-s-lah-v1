import 'package:flutter/material.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  // 1. Add this variable to hold the function
  final Function(ThemeMode) onThemeChanged; 

  // 2. Update the constructor to require this function
  const SettingsPage({super.key, required this.onThemeChanged});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}
class _SettingsPageState extends State<SettingsPage> {
  String _selectedTheme = 'System';

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedTheme = prefs.getString('themeMode') ?? 'System';
    });
  }

Future<void> _updateTheme(String theme) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('themeMode', theme);
  
  setState(() {
    _selectedTheme = theme;
  });

  // Convert String to ThemeMode
  ThemeMode mode;
  if (theme == 'Light') {
    mode = ThemeMode.light;
  } else if (theme == 'Dark') {
    mode = ThemeMode.dark;
  } else {
    mode = ThemeMode.system;
  }
  
  // 🚀 This is the magic line that fixes the UI instantly
  widget.onThemeChanged(mode); 

  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Theme updated to $theme'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

  Future<void> _sendEmail() async {
    final intent = AndroidIntent(
      action: 'android.intent.action.SENDTO',
      data: 'mailto:santhoshpanneer03@gmail.com?subject=Todo App Complaint/Query&body=Hi Santhosh,',
      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    try {
      await intent.launch();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open email app')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Column(
        children: [
          // MAIN SETTINGS CONTENT
          Expanded(
            child: ListView(
              children: [
                _buildSectionHeader("Appearance"),
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text("App Theme"),
                  subtitle: Text("Current: $_selectedTheme"),
                  trailing: DropdownButton<String>(
                    value: _selectedTheme,
                    items: ['Light', 'Dark', 'System'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      if (newValue != null) _updateTheme(newValue);
                    },
                  ),
                ),
                const Divider(),
                _buildSectionHeader("Support"),
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text("Send Feedback"),
                  subtitle: const Text("Report bugs or suggest features"),
                  onTap: _sendEmail,
                ),
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text("Version"),
                  trailing: Text("2.0.0"),
                ),
              ],
            ),
          ),

          // DEVELOPER FOOTER
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              children: [
                const Divider(),
                const SizedBox(height: 10),
                const Text(
                  "Developed by",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Text(
                  "SANTHOSH PANNEER SELVAM",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.blue.shade700,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}