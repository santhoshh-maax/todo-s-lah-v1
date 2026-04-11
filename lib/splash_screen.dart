import 'dart:async';
import 'package:flutter/material.dart';
import 'main.dart';

class SplashScreen extends StatefulWidget {
  final Function(ThemeMode) onThemeChanged;
  const SplashScreen({super.key, required this.onThemeChanged});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // 2-second delay then move to the Todo List
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MainApp(onThemeChanged: widget.onThemeChanged),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Sleek black background
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ensure you have an icon in your assets folder
            // Or replace with Icon(Icons.check_circle, color: Colors.blue, size: 100)
            const Icon(Icons.assignment_turned_in, color: Colors.blue, size: 80),
            const SizedBox(height: 20),
            const Text(
              "𝙏𝙤𝙙𝙤_𝙨 𝙡𝙖𝙝",
              style: TextStyle(
                color: Colors.white, 
                fontSize: 24, 
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Organizing your tasks...",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 30),
            // Optional: Add a subtle loading indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}