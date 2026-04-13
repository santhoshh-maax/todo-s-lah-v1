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


// 🔥 Smooth fade animation
_controller = AnimationController(
  vsync: this,
  duration: const Duration(seconds: 2),
);

_fadeAnimation = Tween<double>(begin: 0.3, end: 1.0)
    .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

_controller.forward();

// Navigate after delay
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
return Scaffold(
backgroundColor: Colors.black,
body: Stack(
children: [


      // 🌟 MAIN CONTENT
      Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [

              Icon(Icons.assignment_turned_in,
                  color: Colors.blue, size: 90),

              SizedBox(height: 20),

              Text(
                "𝙏𝙤𝙙𝙤_𝙨 𝙡𝙖𝙝",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),

              SizedBox(height: 10),

              Text(
                "Organizing your tasks...",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),

              SizedBox(height: 6),

              // 🔢 VERSION TEXT
              Text(
                "Version 1.0.0",
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),

              SizedBox(height: 30),

              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                strokeWidth: 2,
              ),
            ],
          ),
        ),
      ),

      // © LEFT BOTTOM
      Positioned(
  bottom: 10,
  left: 0,
  right: 0,
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: const [
        Flexible(
          child: Text(
            "© 2026 Santhosh P S",
            style: TextStyle(color: Colors.grey, fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: 10),
        Flexible(
          child: Text(
            "Developed by Santhosh P S",
            style: TextStyle(color: Colors.grey, fontSize: 11),
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
