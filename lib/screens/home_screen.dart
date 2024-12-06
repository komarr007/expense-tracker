import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'expense_list_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:io';


class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // List of screens for each tab
  final List<Widget> _screens = [
    HomeScreenContent(), // Replace with actual screen widgets
    ExpenseListScreen(),
    DashboardScreen(),
    HistoryScreenContent(),
    ProfileScreenContent(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex], // Display the selected screen
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Color(0xFF1C1C1E), // Dark background color for bar
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Record',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class HomeScreenContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/logo.png', width: 150, height: 150,), // Replace with your app logo
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class RecordScreenContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Record Screen Content'));
  }
}

class AnalyticsScreenContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Analytics Screen Content'));
  }
}

class HistoryScreenContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('History feature currently under development'));
  }
}

class ProfileScreenContent extends StatelessWidget {
  // Function to export database
  Future<void> _exportDatabase(BuildContext context) async {
    try {
      // Get the path to the internal database
      final directory = await getApplicationDocumentsDirectory();
      print(directory);
      final dbPath = '${directory.parent.path}/databases/expense.db'; // Replace 'expenses.db' with your database name

      // Check if the database exists
      final dbFile = File(dbPath);
      if (!await dbFile.exists()) {
        Fluttertoast.showToast(
          msg: "No database found!",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
        return;
      }

      // Define the path for the backup file
      final externalDir = await getExternalStorageDirectory();
      final backupPath = '${externalDir!.path}/expenses_backup.db';

      // Copy the database to the backup file
      final backupFile = File(backupPath);
      await dbFile.copy(backupFile.path);

      // Notify the user of success
      Fluttertoast.showToast(
        msg: "Database backed up successfully to $backupPath",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
      );
    } catch (e) {
      // Handle errors
      Fluttertoast.showToast(
        msg: "Backup failed: $e",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        backgroundColor: Color(0xFF1C1C1E), // Match the app's dark theme
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Profile Page',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _exportDatabase(context),
              icon: Icon(Icons.backup),
              label: Text('Backup Data'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent, // Button color
              ),
            ),
          ],
        ),
      ),
    );
  }
}
