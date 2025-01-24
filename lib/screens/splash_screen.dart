import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import '../helpers/db_helper.dart'; // Adjust the path to your DBHelper file
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final dbHelper = DBHelper();
  final Logger logger = Logger(); 

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _importExistingData();
    await dbHelper.deleteOldHistoryRecords();
    await Future.delayed(Duration(seconds: 2)); 
    _navigateToHome();
  }

  //code below for importing data from db
  Future<void> _importExistingData() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final etlDbPath = '${appDocDir.path}/expense_etl.db';

    final etlDbExists = await File(etlDbPath).exists();
    if (!etlDbExists) {
      try {
        final data = await rootBundle.load('assets/databases/expense_etl.db');
        final bytes = data.buffer.asUint8List();
        await File(etlDbPath).writeAsBytes(bytes);
      } catch (e) {
        logger.e('ETL database file not found in assets', error: e);
      }
    }

    // Import data using DBHelper
    try {
      await dbHelper.importExistingData(etlDbPath);
    } catch (e) {
      // Handle any errors during data import
      logger.e('Error importing data', error: e);
    }
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomeScreen()),
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
