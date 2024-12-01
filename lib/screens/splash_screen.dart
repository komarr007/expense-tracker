import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import '../helpers/db_helper.dart'; // Adjust the path to your DBHelper file
import 'home_screen.dart';   // Import your home screen


class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp(); // Initialize the app
  }

  Future<void> _initializeApp() async {
    await _importDataFromETL(); // Import ETL data
    _navigateToHome();          // Navigate to home screen after completion
  }

  Future<void> _importDataFromETL() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final etlDbPath = '${appDocDir.path}/expense_etl.db';

    // Check if the ETL database is already copied
    final etlDbExists = await File(etlDbPath).exists();
    if (!etlDbExists) {
      // Copy ETL database from assets
      final data = await rootBundle.load('assets/databases/expense_etl.db');
      final bytes = data.buffer.asUint8List();
      await File(etlDbPath).writeAsBytes(bytes);
    }

    // Import data using DBHelper
    final dbHelper = DBHelper();
    await dbHelper.importETLData(etlDbPath);

    print('ETL data imported successfully.');
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomeScreen()), // Navigate to home screen
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png', 
              width: 150, 
              height: 150,
            ), // App logo
            SizedBox(height: 20),
            CircularProgressIndicator(), // Loading animation
            SizedBox(height: 20),
            Text(
              'Initializing app...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ), // Informative text
          ],
        ),
      ),
    );
  }
}
