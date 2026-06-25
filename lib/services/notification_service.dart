import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/db_helper.dart';
import '../models/expense.dart';

class NotificationService {
  static final NotificationService _i = NotificationService._();
  factory NotificationService() => _i;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'budget_alerts',
    'Budget Alerts',
    channelDescription:
        'Alerts when spending approaches or exceeds budget limits',
    importance: Importance.high,
    priority: Priority.high,
    icon: '@mipmap/launcher_icon',
  );
  static const NotificationDetails _details =
      NotificationDetails(android: _androidDetails);

  Future<void> init() async {
    if (_ready) return;
    const AndroidInitializationSettings android =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    await _plugin.initialize(const InitializationSettings(android: android));
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _ready = true;
  }

  Future<void> _show(int id, String title, String body) async {
    await init();
    await _plugin.show(id, title, body, _details);
  }

  // Call this immediately after any expense is saved.
  Future<void> checkBudgets(Expense expense) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final double monthBudget = prefs.getDouble('monthly_budget') ?? 0;
      final String? rawCat = prefs.getString('category_budgets');
      final Map<String, double> catBudgets = rawCat != null
          ? Map<String, double>.from(
              (jsonDecode(rawCat) as Map<String, dynamic>)
                  .map((k, v) => MapEntry(k, (v as num).toDouble())))
          : <String, double>{};

      // Use targeted SQL SUM queries — avoids a full table scan on every save.
      final DateTime now = DateTime.now();
      final double monthTotal =
          await DBHelper().getMonthlyExpenseTotal(now.year, now.month);

      // Monthly budget check (notification ID 1)
      if (monthBudget > 0) {
        final double pct = monthTotal / monthBudget;
        if (pct >= 1.0) {
          await _show(1, 'Monthly Budget Exceeded',
              'Spent ${_rp(monthTotal)} of ${_rp(monthBudget)} this month.');
        } else if (pct >= 0.8) {
          await _show(1, 'Budget Warning — ${(pct * 100).toStringAsFixed(0)}% used',
              '${_rp(monthBudget - monthTotal)} remaining from your ${_rp(monthBudget)} budget.');
        }
      }

      // Per-category check (notification IDs 200–299)
      final String cat = expense.category;
      if (catBudgets.containsKey(cat)) {
        final double limit    = catBudgets[cat]!;
        final double catTotal =
            await DBHelper().getCategoryMonthlyTotal(now.year, now.month, cat);
        final double pct = catTotal / limit;
        final int notifId = 200 + (cat.hashCode.abs() % 100);
        if (pct >= 1.0) {
          await _show(notifId, '$cat budget exceeded',
              'Spent ${_rp(catTotal)} of ${_rp(limit)} for $cat this month.');
        } else if (pct >= 0.8) {
          await _show(notifId, '$cat — ${(pct * 100).toStringAsFixed(0)}% used',
              '${_rp(limit - catTotal)} left in your $cat budget.');
        }
      }
    } catch (_) {
      // Notifications are non-critical; swallow errors silently.
    }
  }

  String _rp(double v) {
    if (v >= 1000000) return 'Rp ${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return 'Rp ${(v / 1000).toStringAsFixed(0)}K';
    return 'Rp ${v.toStringAsFixed(0)}';
  }
}
