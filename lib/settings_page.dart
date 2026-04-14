import 'package:flutter/material.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

class SettingsPage extends StatefulWidget {
  final Function(ThemeMode) onThemeChanged;
  final Function(String) onAlarmChanged;

  const SettingsPage({
    super.key,
    required this.onThemeChanged,
    required this.onAlarmChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String selectedAlarm = 'alarm1';
  String _selectedTheme = 'System';
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _audioPlayer.dispose(); // Clean up the player when leaving the page
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedTheme = prefs.getString('themeMode') ?? 'System';
      selectedAlarm = prefs.getString('selectedAlarm') ?? 'alarm1';
    });
  }

  void _changeAlarm(String newValue) async {
  final prefs = await SharedPreferences.getInstance();

  // 💾 SAVE
  await prefs.setString('selectedAlarm', newValue);
  debugPrint("💾 Saved selectedAlarm = $newValue");

  setState(() {
    selectedAlarm = newValue;
  });

  debugPrint("🎵 UI Updated → selectedAlarm = $selectedAlarm");

  // 🔊 PREVIEW SOUND
  try {
    await _audioPlayer.stop();
    await _audioPlayer.play(AssetSource('raw/$newValue.mp3'));
    debugPrint("🔊 Playing preview: $newValue.mp3");
  } catch (e) {
    debugPrint("❌ Preview error: $e");
  }

  // 🔁 UPDATE MAIN APP
  widget.onAlarmChanged(newValue);
  debugPrint("🔄 Notified MainApp → $newValue");

  // 🔔 SNACKBAR
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "🔔 Tone changed to ${newValue.replaceAll('alarm', 'Tone ')}",
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

  Future<void> _updateTheme(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', theme);

    setState(() {
      _selectedTheme = theme;
    });

    ThemeMode mode;
    if (theme == 'Light') {
      mode = ThemeMode.light;
    } else if (theme == 'Dark') {
      mode = ThemeMode.dark;
    } else {
      mode = ThemeMode.system;
    }

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

  void _showTonePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const Text(
                    "Select Alarm Tone",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: 20,
                      itemBuilder: (context, index) {
                        String toneValue = 'alarm${index + 1}';
                        bool isSelected = selectedAlarm == toneValue;

                        return ListTile(
                          leading: Icon(
                            isSelected
                                ? Icons.play_circle_fill
                                : Icons.play_circle_outline,
                            color: isSelected ? Colors.blue : Colors.grey,
                          ),
                          title: Text(
                            "Tone ${index + 1}",
                            style: TextStyle(
                              color: isSelected ? Colors.blue : null,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check, color: Colors.blue)
                              : null,
                          onTap: () {
                            setModalState(() {
                              selectedAlarm = toneValue;
                            });
                            _changeAlarm(toneValue);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _sendEmail() async {
    final intent = AndroidIntent(
      action: 'android.intent.action.SENDTO',
      data:
          'mailto:santhoshpanneer03@gmail.com?subject=Todo App Complaint/Query&body=Hi Santhosh,',
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
          Expanded(
            child: ListView(
              children: [
                _buildSectionHeader("Appearance"),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedTheme,
                        isExpanded: true,
                        icon: const Icon(
                          Icons.palette_rounded,
                          color: Colors.blue,
                        ),
                        items: ['Light', 'Dark', 'System'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Row(
                              children: [
                                Icon(
                                  value == 'Light'
                                      ? Icons.wb_sunny_outlined
                                      : value == 'Dark'
                                      ? Icons.nightlight_round
                                      : Icons.settings_suggest,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  value,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          if (newValue != null) _updateTheme(newValue);
                        },
                      ),
                    ),
                  ),
                ),
                const Divider(),
                _buildSectionHeader("Notifications"),
                ListTile(
                  leading: const Icon(
                    Icons.music_note_rounded,
                    color: Colors.blue,
                  ),
                  title: const Text("Alarm Tone"),
                  subtitle: Text(
                    "Current: ${selectedAlarm.replaceAll('alarm', 'Tone ')}",
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                  ),
                  onTap: () => _showTonePicker(context),
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
                  trailing: Text("1.0.0"),
                ),
              ],
            ),
          ),
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
