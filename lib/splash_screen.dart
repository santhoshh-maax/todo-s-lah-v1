import 'dart:async';
import 'package:flutter/material.dart';
import 'main.dart';

class SplashScreen extends StatefulWidget {
final Function(ThemeMode) onThemeChanged;
const SplashScreen({super.key, required this.onThemeChanged});

@override
State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
with SingleTickerProviderStateMixin {

late AnimationController _controller;
late Animation<double> _fadeAnimation;

@override
void initState() {
super.initState();

_controller = AnimationController(
  vsync: this,
  duration: const Duration(seconds: 2),
);

_fadeAnimation = Tween<double>(begin: 0.3, end: 1.0)
    .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

_controller.forward();

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
void dispose() {
_controller.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {
final isDark = Theme.of(context).brightness == Brightness.dark;

return Scaffold(
  backgroundColor: isDark ? Colors.black : Colors.white,
  body: Stack(
    children: [

      // 🌟 MAIN CONTENT
      Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              Icon(
                Icons.assignment_turned_in,
                color: Colors.blue,
                size: 90,
              ),

              const SizedBox(height: 20),

              Text(
                "𝙏𝙤𝙙𝙤_𝙨 𝙡𝙖𝙝",
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                "Organizing your tasks...",
                style: TextStyle(
                  color: isDark ? Colors.grey : Colors.grey.shade700,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                "Version 1.0.0",
                style: TextStyle(
                  color: isDark ? Colors.grey : Colors.grey.shade700,
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 30),

              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                strokeWidth: 2,
              ),
            ],
          ),
        ),
      ),

      // 📌 FOOTER
      Positioned(
        bottom: 10,
        left: 0,
        right: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  "© 2026 Santhosh P S",
                  style: TextStyle(
                    color: isDark ? Colors.grey : Colors.grey.shade700,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  "Developed by Santhosh P S",
                  style: TextStyle(
                    color: isDark ? Colors.grey : Colors.grey.shade700,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  ),
);

}
}
