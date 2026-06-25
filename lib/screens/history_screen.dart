import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/history_record.dart';
import '../models/expense.dart';
import '../helpers/db_helper.dart';
import '../theme/app_theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<HistoryRecord>> _future;
  final NumberFormat _fmt =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _future = DBHelper().getHistoryRecords();
  }

  void _refresh() => setState(() => _future = DBHelper().getHistoryRecords());

  Future<void> _restore(HistoryRecord record) async {
    await DBHelper().insertExpense(Expense(
      name:       record.name,
      amount:     record.amount,
      spend_date: record.spend_date,
      created_at: record.created_at,
      updated_at: record.updated_at,
      user_id:    record.user_id,
      category:   record.category,
    ));
    await DBHelper().deleteHistoryRecord(record.id!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Record restored')),
      );
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deleted History'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: FutureBuilder<List<HistoryRecord>>(
        future: _future,
        builder: (_, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}',
                  style: const TextStyle(color: AppColors.negative)),
            );
          }
          final List<HistoryRecord> records = snapshot.data ?? <HistoryRecord>[];
          if (records.isEmpty) return _empty();
          return _list(records);
        },
      ),
    );
  }

  Widget _empty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.history_toggle_off_rounded,
                size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text('No deleted records',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            const SizedBox(height: 6),
            const Text('Deleted expenses appear here for 14 days',
                style:
                    TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ],
        ),
      );

  Widget _list(List<HistoryRecord> records) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: records.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _item(records[i]),
    );
  }

  Widget _item(HistoryRecord r) {
    final Color cat = AppColors.category(r.category);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            // Category icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cat.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Container(
                  width: 12,
                  height: 12,
                  decoration:
                      BoxDecoration(color: cat, shape: BoxShape.circle),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    r.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${r.category}  ·  ${DateFormat('MMM d, yyyy').format(r.spend_date)}',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: <Widget>[
                      const Icon(Icons.delete_outline_rounded,
                          size: 11, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Text(
                        'Deleted ${DateFormat('MMM d, HH:mm').format(r.deleted_at)}',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Amount + restore
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  _fmt.format(r.amount),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _restore(r),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Restore',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
