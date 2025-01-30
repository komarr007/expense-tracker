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
      final Directory directory = await getApplicationDocumentsDirectory();
      final String dbPath = '${directory.parent.path}/databases/expense.db';
      final File dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        Fluttertoast.showToast(msg: 'No database found!', toastLength: Toast.LENGTH_SHORT, gravity: ToastGravity.BOTTOM);
        return;
      }

      final bool havePermission = await _requestStoragePermission();
      if (!havePermission) {
        Fluttertoast.showToast(msg: 'Storage permissions required.', toastLength: Toast.LENGTH_LONG, gravity: ToastGravity.BOTTOM);
        return;
      }

      final String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null || selectedDirectory.isEmpty) {
        Fluttertoast.showToast(msg: 'Invalid directory selected.', toastLength: Toast.LENGTH_LONG, gravity: ToastGravity.BOTTOM);
        return;
      }

      final String backupPath = '$selectedDirectory/expenses_backup.db';
      await dbFile.copy(backupPath);

      Fluttertoast.showToast(msg: 'Backup saved: $backupPath', toastLength: Toast.LENGTH_LONG, gravity: ToastGravity.BOTTOM);
    } catch (e) {
      Fluttertoast.showToast(msg: 'Backup failed: ${e.toString()}', toastLength: Toast.LENGTH_LONG, gravity: ToastGravity.BOTTOM);
    }
  }

  Future<bool> _requestStoragePermission() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;

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

    final Map<Permission, PermissionStatus> statuses = await <Permission>[
      Permission.storage,
      Permission.manageExternalStorage,
    ].request();

    statuses.forEach((Permission permission, PermissionStatus status) {
      print('Permission: $permission, Status: $status');
    });
  }
  
  Future<void> _exportToExcel(BuildContext context) async {
    try {
      final List<Expense> expenses = await DBHelper().getExpenses();

      if (expenses.isEmpty) {
        Fluttertoast.showToast(msg: 'No data to export.');
        return;
      }

      final Excel excel = Excel.createExcel();
      final Sheet sheet = excel['Expenses'];

      // Add column headers
      sheet.appendRow(<CellValue?>[
        TextCellValue('ID'),
        TextCellValue('Name'),
        TextCellValue('Amount'),
        TextCellValue('Date'),
        TextCellValue('Category'),
      ]);

      // Add rows from expense data
      for (Expense expense in expenses) {
        sheet.appendRow(<CellValue?>[
          TextCellValue(expense.id.toString()),
          TextCellValue(expense.name),
          TextCellValue(expense.amount.toString()),
          TextCellValue(expense.spend_date.toIso8601String()), // ✅ Convert DateTime to String
          TextCellValue(expense.category),
        ]);
      }

      final bool havePermission = await _requestStoragePermission();
      if (!havePermission) {
        Fluttertoast.showToast(msg: 'Storage permissions required.');
        return;
      }

      final String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null || selectedDirectory.isEmpty) {
        Fluttertoast.showToast(msg: 'Invalid directory selected.');
        return;
      }

      final String filePath = '$selectedDirectory/expenses.xlsx';
      final File excelFile = File(filePath);
      await excelFile.writeAsBytes(excel.encode()!);

      Fluttertoast.showToast(msg: 'Excel file saved: $filePath');
    } catch (e) {
      Fluttertoast.showToast(msg: 'Export failed: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: const Color(0xFF1C1C1E),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('Profile Page', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _exportDatabase(context),
              icon: const Icon(Icons.backup),
              label: const Text('Backup Data'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            ),
            ElevatedButton(onPressed: debugPermissions, child: const Text('Debug Permissions')),
            ElevatedButton.icon(
              onPressed: () => _exportToExcel(context),
              icon: const Icon(Icons.file_present),
              label: const Text('Export to Excel'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
          ],
        ),
      ),
    );
  }
}