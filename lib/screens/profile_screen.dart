import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../helpers/db_helper.dart';
import '../models/expense.dart';
import '../models/income_record.dart';
import '../services/category_registry.dart';
import '../services/reload_notifier.dart';
import '../theme/app_theme.dart';
import 'history_screen.dart';
import 'manage_categories_screen.dart';
import 'recurring_screen.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _budgetCtrl = TextEditingController();
  final NumberFormat _fmt =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  double _currentBudget = 0.0;
  Map<String, double> _catBudgets = <String, double>{};

  @override
  void initState() {
    super.initState();
    ReloadNotifier.instance.addListener(_onReload);
    _loadPrefs();
  }

  @override
  void dispose() {
    ReloadNotifier.instance.removeListener(_onReload);
    _budgetCtrl.dispose();
    super.dispose();
  }

  void _onReload() => setState(() {});

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final double b = prefs.getDouble('monthly_budget') ?? 0.0;
    final String? raw = prefs.getString('category_budgets');
    final Map<String, double> cats = raw != null
        ? Map<String, double>.from(
            (jsonDecode(raw) as Map<String, dynamic>)
                .map((k, v) => MapEntry(k, (v as num).toDouble())))
        : <String, double>{};
    setState(() {
      _currentBudget  = b;
      _budgetCtrl.text = b > 0 ? b.toStringAsFixed(0) : '';
      _catBudgets     = cats;
    });
  }

  // ── Monthly budget ─────────────────────────────────────────────────────────

  Future<void> _saveBudget() async {
    final String raw = _budgetCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (raw.isEmpty) { Fluttertoast.showToast(msg: 'Enter a budget amount first.'); return; }
    final double b = double.parse(raw);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('monthly_budget', b);
    setState(() => _currentBudget = b);
    Fluttertoast.showToast(msg: 'Budget saved: ${_fmt.format(b)}');
  }

  Future<void> _clearBudget() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('monthly_budget');
    setState(() { _currentBudget = 0.0; _budgetCtrl.clear(); });
    Fluttertoast.showToast(msg: 'Budget cleared.');
  }

  // ── Category budgets ───────────────────────────────────────────────────────

  Future<void> _setCategoryBudget(String cat) async {
    final existing = _catBudgets[cat];
    final TextEditingController ctrl = TextEditingController(
        text: existing != null ? existing.toStringAsFixed(0) : '');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  alignment: Alignment.center,
                  child: Container(width: 36, height: 4,
                      decoration: BoxDecoration(color: AppColors.textMuted, borderRadius: BorderRadius.circular(2)))),
              Row(
                children: <Widget>[
                  Container(width: 10, height: 10,
                      decoration: BoxDecoration(color: AppColors.category(cat), shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text('Budget for $cat',
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Monthly limit',
                  prefixText: 'Rp  ',
                  prefixStyle: TextStyle(color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final String raw2 = ctrl.text.replaceAll(RegExp(r'[^0-9]'), '');
                        if (raw2.isEmpty) { Navigator.pop(context); return; }
                        final newBudgets = Map<String, double>.from(_catBudgets);
                        newBudgets[cat] = double.parse(raw2);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('category_budgets', jsonEncode(newBudgets));
                        setState(() => _catBudgets = newBudgets);
                        if (mounted) { Navigator.pop(context); Fluttertoast.showToast(msg: 'Budget set for $cat'); }
                      },
                      style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
                      child: const Text('Save'),
                    ),
                  ),
                  if (existing != null) ...<Widget>[
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () async {
                        final newBudgets = Map<String, double>.from(_catBudgets)..remove(cat);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('category_budgets', jsonEncode(newBudgets));
                        setState(() => _catBudgets = newBudgets);
                        if (mounted) { Navigator.pop(context); Fluttertoast.showToast(msg: 'Budget cleared for $cat'); }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.negative,
                        side: const BorderSide(color: AppColors.negative),
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      child: const Text('Clear'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
    ctrl.dispose();
  }

  // ── Data export ────────────────────────────────────────────────────────────

  Future<bool> _requestStoragePermission() async {
    final info = await DeviceInfoPlugin().androidInfo;
    // Android 13+ (SDK 33+) removed WRITE_EXTERNAL_STORAGE; SAF/FilePicker
    // handles directory access natively without a separate permission grant.
    if (info.version.sdkInt >= 33) return true;
    if (await Permission.storage.request().isGranted) return true;
    if (await Permission.manageExternalStorage.request().isGranted) return true;
    if (await Permission.photos.request().isGranted) return true;
    return false;
  }

  Future<void> _restoreDatabase() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore from Backup'),
        content: const Text(
          'This will replace ALL current data with the selected backup.\n\n'
          'This cannot be undone. Continue?',
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore', style: TextStyle(color: AppColors.negative)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      if (!await _requestStoragePermission()) {
        Fluttertoast.showToast(msg: 'Storage permission required.');
        return;
      }

      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: <String>['db'],
      );
      if (result == null || result.files.single.path == null) return;

      final File src = File(result.files.single.path!);

      // Verify the file is a real SQLite database by checking its 16-byte magic header.
      final RandomAccessFile raf = await src.open();
      final List<int> header = await raf.read(16);
      await raf.close();
      const List<int> _sqliteMagic = <int>[
        83, 81, 76, 105, 116, 101, 32, 102, 111, 114, 109, 97, 116, 32, 51, 0,
      ]; // "SQLite format 3\0"
      for (int i = 0; i < _sqliteMagic.length; i++) {
        if (i >= header.length || header[i] != _sqliteMagic[i]) {
          Fluttertoast.showToast(msg: 'Not a valid database file.');
          return;
        }
      }

      // Close the live connection before replacing the file on disk.
      await DBHelper().resetDatabase();

      final Directory appDir = await getApplicationDocumentsDirectory();
      final String dbPath = '${appDir.parent.path}/databases/expense.db';
      await src.copy(dbPath);

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Restore Complete'),
          content: const Text(
            'Your backup has been restored.\n\n'
            'Tap "Exit App" and reopen to see the restored data.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                SystemNavigator.pop();
              },
              child: const Text('Exit App'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Later'),
            ),
          ],
        ),
      );
    } catch (e) {
      Fluttertoast.showToast(msg: 'Restore failed: $e');
    }
  }

  Future<void> _exportDatabase() async {
    try {
      final dir    = await getApplicationDocumentsDirectory();
      final dbFile = File('${dir.parent.path}/databases/expense.db');
      if (!await dbFile.exists()) { Fluttertoast.showToast(msg: 'No database found!'); return; }
      if (!await _requestStoragePermission()) { Fluttertoast.showToast(msg: 'Storage permission required.'); return; }
      final String? dest = await FilePicker.platform.getDirectoryPath();
      if (dest == null || dest.isEmpty) { Fluttertoast.showToast(msg: 'No directory selected.'); return; }
      await dbFile.copy('$dest/expenses_backup.db');
      Fluttertoast.showToast(msg: 'Backup saved to $dest');
    } catch (e) { Fluttertoast.showToast(msg: 'Backup failed: $e'); }
  }

  Future<void> _exportToExcel() async {
    try {
      final List<Expense>      expenses = await DBHelper().getExpenses();
      final List<IncomeRecord> income   = await DBHelper().getIncomeRecords();
      if (expenses.isEmpty && income.isEmpty) {
        Fluttertoast.showToast(msg: 'No data to export.');
        return;
      }

      final Excel excel = Excel.createExcel();

      // ── Expenses sheet ────────────────────────────────────────────────────
      final Sheet expSheet = excel['Expenses'];
      expSheet.appendRow(<CellValue?>[
        TextCellValue('ID'), TextCellValue('Name'), TextCellValue('Amount'),
        TextCellValue('Date'), TextCellValue('Category'), TextCellValue('Notes'),
      ]);
      for (final e in expenses) {
        expSheet.appendRow(<CellValue?>[
          TextCellValue(e.id.toString()), TextCellValue(e.name),
          DoubleCellValue(e.amount),
          TextCellValue(DateFormat('yyyy-MM-dd').format(e.spend_date)),
          TextCellValue(e.category), TextCellValue(e.notes ?? ''),
        ]);
      }

      // ── Income sheet ──────────────────────────────────────────────────────
      final Sheet incSheet = excel['Income'];
      incSheet.appendRow(<CellValue?>[
        TextCellValue('ID'), TextCellValue('Name'), TextCellValue('Amount'),
        TextCellValue('Date'), TextCellValue('Category'), TextCellValue('Notes'),
      ]);
      for (final r in income) {
        incSheet.appendRow(<CellValue?>[
          TextCellValue(r.id.toString()), TextCellValue(r.name),
          DoubleCellValue(r.amount),
          TextCellValue(DateFormat('yyyy-MM-dd').format(r.income_date)),
          TextCellValue(r.category), TextCellValue(r.notes ?? ''),
        ]);
      }

      // Remove the default empty sheet the library creates
      excel.delete('Sheet1');

      if (!await _requestStoragePermission()) { Fluttertoast.showToast(msg: 'Storage permission required.'); return; }
      final String? dest = await FilePicker.platform.getDirectoryPath();
      if (dest == null || dest.isEmpty) { Fluttertoast.showToast(msg: 'No directory selected.'); return; }
      final String filename = 'money_logger_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx';
      await File('$dest/$filename').writeAsBytes(excel.encode()!);
      Fluttertoast.showToast(msg: 'Exported $filename to $dest');
    } catch (e) { Fluttertoast.showToast(msg: 'Export failed: $e'); }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _sectionLabel('MONTHLY BUDGET'),
            const SizedBox(height: 8),
            _budgetCard(),
            const SizedBox(height: 28),
            _sectionLabel('CATEGORIES'),
            const SizedBox(height: 8),
            _manageCategoriesCard(),
            const SizedBox(height: 28),
            _sectionLabel('CATEGORY LIMITS'),
            const SizedBox(height: 8),
            _catBudgetsCard(),
            const SizedBox(height: 28),
            _sectionLabel('AUTOMATION'),
            const SizedBox(height: 8),
            _recurringCard(),
            const SizedBox(height: 28),
            _sectionLabel('DATA MANAGEMENT'),
            const SizedBox(height: 8),
            _dataCard(),
            const SizedBox(height: 28),
            _sectionLabel('APP INFO'),
            const SizedBox(height: 8),
            _infoCard(),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8));

  Widget _budgetCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.accent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('Monthly Budget', style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                    Text(
                      _currentBudget > 0 ? _fmt.format(_currentBudget) : 'Not set',
                      style: TextStyle(color: _currentBudget > 0 ? AppColors.positive : AppColors.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _budgetCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Budget Amount',
              hintText: 'e.g. 5000000',
              prefixText: 'Rp  ',
              prefixStyle: TextStyle(color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saveBudget,
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Save'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
                ),
              ),
              if (_currentBudget > 0) ...<Widget>[
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: _clearBudget,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.negative,
                    side: const BorderSide(color: AppColors.negative),
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  child: const Text('Clear'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _catBudgetsCard() {
    return Container(
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
      child: Column(
        children: CategoryRegistry().names.asMap().entries.map((entry) {
          final String cat    = entry.value;
          final double? limit = _catBudgets[cat];
          final bool isLast   = entry.key == CategoryRegistry().names.length - 1;
          return Column(
            children: <Widget>[
              InkWell(
                onTap: () => _setCategoryBudget(cat),
                borderRadius: isLast
                    ? const BorderRadius.vertical(bottom: Radius.circular(16))
                    : BorderRadius.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  child: Row(
                    children: <Widget>[
                      Container(width: 10, height: 10,
                          decoration: BoxDecoration(color: AppColors.category(cat), shape: BoxShape.circle)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(cat, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13))),
                      Text(
                        limit != null ? _fmt.format(limit) : 'Not set',
                        style: TextStyle(
                          color: limit != null ? AppColors.textSecondary : AppColors.textMuted, fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 18),
                    ],
                  ),
                ),
              ),
              if (!isLast) const Divider(height: 1, indent: 36, endIndent: 0),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _manageCategoriesCard() {
    final int count = CategoryRegistry().names.length;
    return InkWell(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const ManageCategoriesScreen())),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider)),
        child: Row(
          children: <Widget>[
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.category_rounded,
                  color: AppColors.accent, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('Manage Categories',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  Text('$count ${count == 1 ? 'category' : 'categories'} · add, edit, reorder',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _recurringCard() {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecurringScreen())),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
        child: Row(
          children: <Widget>[
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.event_repeat_rounded, color: AppColors.accent, size: 20),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Recurring Expenses', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                  Text('Auto-add bills & subscriptions', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _dataCard() {
    return Container(
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
      child: Column(
        children: <Widget>[
          _dataAction(icon: Icons.history_rounded, iconColor: AppColors.accent,
              label: 'Deleted Records', sublabel: 'View recently deleted transactions', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()))),
          const Divider(height: 1, indent: 68),
          _dataAction(icon: Icons.backup_rounded, iconColor: const Color(0xFF60A5FA),
              label: 'Backup Database', sublabel: 'Save a copy of the database file', onTap: _exportDatabase),
          const Divider(height: 1, indent: 68),
          _dataAction(icon: Icons.restore_rounded, iconColor: AppColors.warning,
              label: 'Restore from Backup', sublabel: 'Replace data from a .db backup file', onTap: _restoreDatabase),
          const Divider(height: 1, indent: 68),
          _dataAction(icon: Icons.table_chart_outlined, iconColor: AppColors.positive,
              label: 'Export to Excel', sublabel: 'Download all records as .xlsx', onTap: _exportToExcel, isLast: true),
        ],
      ),
    );
  }

  Widget _dataAction({required IconData icon, required Color iconColor, required String label, required String sublabel, required VoidCallback onTap, bool isLast = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: isLast ? const BorderRadius.vertical(bottom: Radius.circular(16)) : BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: <Widget>[
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: iconColor.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                  Text(sublabel, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
      child: Column(
        children: <Widget>[
          _infoRow('App Name', 'The Money Logger'),
          const Divider(height: 20),
          _infoRow('Version', '1.4.0 (build 6)'),
          const Divider(height: 20),
          _infoRow('Data Retention', 'Deleted records kept 14 days'),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: <Widget>[
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
    ],
  );
}
