import 'package:flutter/material.dart';
import 'home_screen.dart'; // Import your home screen to navigate after splash

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome(); // Automatically navigate to the home screen
  }

  _navigateToHome() async {
    await Future.delayed(Duration(seconds: 2), () {}); // Splash duration
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomeScreen()), // Go to home screen
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/logo.png', width: 150, height: 150,), // Replace with your app logo
            SizedBox(height: 20),
            CircularProgressIndicator(), // Loading animation
          ],
        ),
      ),
    );
  }
}
