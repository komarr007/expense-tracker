import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() {
  // Silence all log output in production builds.
  if (kReleaseMode) Logger.level = Level.off;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Money Logger',
      theme: AppTheme.dark,
      home: const SplashScreen(),
    );
  }
}
