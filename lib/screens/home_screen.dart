import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'expense_list_screen.dart';
import 'history_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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
    HistoryScreen(),
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
  const HomeScreenContent({super.key});

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
  const RecordScreenContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Record Screen Content'));
  }
}

class AnalyticsScreenContent extends StatelessWidget {
  const AnalyticsScreenContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Analytics Screen Content'));
  }
}

class HistoryScreenContent extends StatelessWidget {
  const HistoryScreenContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('History feature currently under development'));
  }
}

class ProfileScreenContent extends StatelessWidget {
  const ProfileScreenContent({super.key});

  // Function to export the database
  Future<void> _exportDatabase(BuildContext context) async {
    try {
      // Get the database path
      final directory = await getApplicationDocumentsDirectory();
      final dbPath = '${directory.parent.path}/databases/expense.db'; // Update with your actual database file name
      final dbFile = File(dbPath);

      // Check if the database exists
      if (!await dbFile.exists()) {
        Fluttertoast.showToast(
          msg: "No database found!",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
        return;
      }

      // Request storage permissions dynamically based on Android version
      bool havePermission = await _requestStoragePermission();
      if (!havePermission) {
        Fluttertoast.showToast(
          msg: "Storage permissions are required to back up the database.",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
        );
        return;
      }

      // Use FilePicker to select the backup directory
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      // Ensure the selected directory is valid
      if (selectedDirectory == null || selectedDirectory.isEmpty) {
        Fluttertoast.showToast(
          msg: "Invalid directory selected.",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
        );
        return;
      }

      // Copy the database to the selected directory
      final backupPath = '$selectedDirectory/expenses_backup.db';
      await dbFile.copy(backupPath);

      // Notify the user of successful backup
      Fluttertoast.showToast(
        msg: "Database backed up successfully to: $backupPath",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
      );
    } catch (e) {
      // Handle errors
      Fluttertoast.showToast(
        msg: "Backup failed: ${e.toString()}",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  // Helper function to request storage permissions
  Future<bool> _requestStoragePermission() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;

    if (androidInfo.version.sdkInt < 33) {
      if (await Permission.storage.request().isGranted) {
        return true;
      } else if (await Permission.storage.isPermanentlyDenied) {
        openAppSettings();
      } else if (await Permission.audio.request().isDenied){
        openAppSettings();
      } if (await Permission.manageExternalStorage.request().isGranted) {
        return true;
      } if (await Permission.manageExternalStorage.isPermanentlyDenied) {
        openAppSettings();
      } if (await Permission.manageExternalStorage.request().isDenied){
        return false;
      } else {
        if (await Permission.photos.request().isGranted) {
          return true;
        }else if (await Permission.photos.isPermanentlyDenied) {
          openAppSettings();
        }else if (await Permission.photos.request().isDenied){
          return false;
        }
      }
    } else if (Platform.isIOS) {
      return true;
    }

    return false;
  }

  // Debug function for permissions
  void debugPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.storage,
      Permission.manageExternalStorage,
    ].request();

    statuses.forEach((permission, status) {
      print('Permission: $permission, Status: $status');
    });

    bool isStorageGranted = await Permission.storage.isGranted;
    bool isManageExternalStorageGranted =
        await Permission.manageExternalStorage.isGranted;

    print('Is Storage Permission Granted: $isStorageGranted');
    print('Is Manage External Storage Permission Granted: $isManageExternalStorageGranted');
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
            ElevatedButton(
              onPressed: debugPermissions,
              child: Text("Debug Permissions"),
            )

          ],
        ),
      ),
    );
  }
}
