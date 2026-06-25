import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import '../helpers/db_helper.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  final DBHelper _db = DBHelper();
  final Logger _log = Logger();

  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _scale;

  String _statusText = 'Initializing…';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _scale = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _ctrl.forward();
    _init();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _importData();
    _setStatus('Cleaning up old records…');
    await _db.deleteOldHistoryRecords();
    _setStatus('Checking recurring expenses…');
    try {
      final int created = await _db.processRecurringExpenses();
      if (created > 0) _log.i('Auto-created $created recurring expense(s)');
    } catch (e) {
      _log.e('processRecurring', error: e);
    }
    await Future<void>.delayed(const Duration(milliseconds: 800));
    _navigate();
  }

  Future<void> _importData() async {
    _setStatus('Loading data…');
    try {
      final Directory dir = await getApplicationDocumentsDirectory();
      final String path   = '${dir.path}/expense_etl.db';
      if (!await File(path).exists()) {
        final ByteData data =
            await rootBundle.load('assets/databases/expense_etl.db');
        await File(path).writeAsBytes(data.buffer.asUint8List());
      }
      await _db.importExistingData(path);
    } catch (e) {
      _log.e('ETL import', error: e);
    }
  }

  void _setStatus(String s) {
    if (mounted) setState(() => _statusText = s);
  }

  void _navigate() {
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[Color(0xFF0B0F1E), Color(0xFF1E1B4B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // Logo
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: AppColors.divider),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: AppColors.accent.withOpacity(0.3),
                            blurRadius: 40,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(27),
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.account_balance_wallet_rounded,
                            size: 48,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      'Money Logger',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Track every rupiah',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 48),

                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.accent.withOpacity(0.8)),
                      ),
                    ),

                    const SizedBox(height: 14),

                    Text(
                      _statusText,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
