import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Money Logger',
      theme: ThemeData.dark(),  // Use a dark theme as per your design
      home: const SplashScreen(),  // Set splash screen as the initial screen
    );
  }
}
