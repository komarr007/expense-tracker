import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../helpers/db_helper.dart';
import '../models/recurring_expense.dart';
import '../theme/app_theme.dart';
import 'add_recurring_screen.dart';

class RecurringScreen extends StatefulWidget {
  const RecurringScreen({super.key});

  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen> {
  List<RecurringExpense> _items = <RecurringExpense>[];
  bool _loading = true;

  final NumberFormat _fmt =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final List<RecurringExpense> list = await DBHelper().getRecurringExpenses();
    if (mounted) setState(() { _items = list; _loading = false; });
  }

  Future<void> _delete(RecurringExpense r) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Recurring'),
        content: Text('Stop auto-adding "${r.name}"?'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.negative)),
          ),
        ],
      ),
    );
    if (confirmed == true && r.id != null) {
      await DBHelper().deleteRecurring(r.id!);
      _load();
    }
  }

  Future<void> _edit(RecurringExpense r) async {
    final bool? changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddRecurringScreen(recurring: r)),
    );
    if (changed == true) _load();
  }

  Future<void> _add() async {
    final bool? created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddRecurringScreen()),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Expenses'),
        actions: <Widget>[
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? _empty()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _item(_items[i]),
                ),
    );
  }

  Widget _empty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.event_repeat_rounded, size: 64, color: AppColors.textMuted),
        const SizedBox(height: 16),
        const Text('No recurring expenses', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
        const SizedBox(height: 6),
        const Text('Tap + to add one (e.g. rent, subscriptions)',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      ],
    ),
  );

  Widget _item(RecurringExpense r) {
    final Color cat  = AppColors.category(r.category);
    final DateTime now = DateTime.now();
    final bool isDue = !r.next_due.isAfter(now);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDue ? AppColors.warning.withOpacity(0.5) : AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: cat.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: Center(child: Container(width: 12, height: 12, decoration: BoxDecoration(color: cat, shape: BoxShape.circle))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(r.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 3),
                  Row(
                    children: <Widget>[
                      _badge(r.frequencyLabel, AppColors.accent),
                      const SizedBox(width: 6),
                      _badge(
                        isDue
                            ? 'Due today!'
                            : 'Next: ${DateFormat('MMM d').format(r.next_due)}',
                        isDue ? AppColors.warning : AppColors.textMuted,
                      ),
                    ],
                  ),
                  if (r.notes != null && r.notes!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(r.notes!, style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(_fmt.format(r.amount),
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    GestureDetector(
                      onTap: () => _edit(r),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                        child: const Icon(Icons.edit_rounded, size: 14, color: AppColors.accent),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _delete(r),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(color: AppColors.negative.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                        child: const Icon(Icons.delete_outline_rounded, size: 14, color: AppColors.negative),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
  );
}
