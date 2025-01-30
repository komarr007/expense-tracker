import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:excel/excel.dart';
import '../helpers/db_helper.dart';
import '../models/expense.dart';


class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // Function to export the database
  Future<void> _exportDatabase(BuildContext context) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final dbPath = '${directory.parent.path}/databases/expense.db';
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        Fluttertoast.showToast(msg: "No database found!", toastLength: Toast.LENGTH_SHORT, gravity: ToastGravity.BOTTOM);
        return;
      }

      bool havePermission = await _requestStoragePermission();
      if (!havePermission) {
        Fluttertoast.showToast(msg: "Storage permissions required.", toastLength: Toast.LENGTH_LONG, gravity: ToastGravity.BOTTOM);
        return;
      }

      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null || selectedDirectory.isEmpty) {
        Fluttertoast.showToast(msg: "Invalid directory selected.", toastLength: Toast.LENGTH_LONG, gravity: ToastGravity.BOTTOM);
        return;
      }

      final backupPath = '$selectedDirectory/expenses_backup.db';
      await dbFile.copy(backupPath);

      Fluttertoast.showToast(msg: "Backup saved: $backupPath", toastLength: Toast.LENGTH_LONG, gravity: ToastGravity.BOTTOM);
    } catch (e) {
      Fluttertoast.showToast(msg: "Backup failed: ${e.toString()}", toastLength: Toast.LENGTH_LONG, gravity: ToastGravity.BOTTOM);
    }
  }

  Future<bool> _requestStoragePermission() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;

    if (androidInfo.version.sdkInt <= 35) {
      if (await Permission.storage.request().isGranted) return true;
      if (await Permission.manageExternalStorage.request().isGranted) return true;
      if (await Permission.photos.request().isGranted) return true;
    } else if (Platform.isIOS) {
      return true;
    }

    return false;
  }

  void debugPermissions() async {

    Map<Permission, PermissionStatus> statuses = await [
      Permission.storage,
      Permission.manageExternalStorage,
    ].request();

    statuses.forEach((permission, status) {
      print('Permission: $permission, Status: $status');
    });
  }
  
  Future<void> _exportToExcel(BuildContext context) async {
    try {
      List<Expense> expenses = await DBHelper().getExpenses();

      if (expenses.isEmpty) {
        Fluttertoast.showToast(msg: "No data to export.");
        return;
      }

      final excel = Excel.createExcel();
      final sheet = excel['Expenses'];

      // Add column headers
      sheet.appendRow([
        TextCellValue('ID'),
        TextCellValue('Name'),
        TextCellValue('Amount'),
        TextCellValue('Date'),
        TextCellValue('Category'),
      ]);

      // Add rows from expense data
      for (var expense in expenses) {
        sheet.appendRow([
          TextCellValue(expense.id.toString()),
          TextCellValue(expense.name),
          TextCellValue(expense.amount.toString()),
          TextCellValue(expense.spend_date.toIso8601String()), // ✅ Convert DateTime to String
          TextCellValue(expense.category),
        ]);
      }

      bool havePermission = await _requestStoragePermission();
      if (!havePermission) {
        Fluttertoast.showToast(msg: "Storage permissions required.");
        return;
      }

      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null || selectedDirectory.isEmpty) {
        Fluttertoast.showToast(msg: "Invalid directory selected.");
        return;
      }

      final filePath = '$selectedDirectory/expenses.xlsx';
      final excelFile = File(filePath);
      await excelFile.writeAsBytes(excel.encode()!);

      Fluttertoast.showToast(msg: "Excel file saved: $filePath");
    } catch (e) {
      Fluttertoast.showToast(msg: "Export failed: ${e.toString()}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        backgroundColor: Color(0xFF1C1C1E),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Profile Page', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _exportDatabase(context),
              icon: Icon(Icons.backup),
              label: Text('Backup Data'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            ),
            ElevatedButton(onPressed: debugPermissions, child: Text("Debug Permissions")),
            ElevatedButton.icon(
              onPressed: () => _exportToExcel(context),
              icon: Icon(Icons.file_present),
              label: Text('Export to Excel'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
          ],
        ),
      ),
    );
  }
}