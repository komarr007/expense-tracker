import 'package:flutter/material.dart';
import '../models/history_record.dart';
import '../models/expense.dart';
import '../helpers/db_helper.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});
  
  Future<List<HistoryRecord>> fetchHistoryRecords() async {
    return await DBHelper().getHistoryRecords();
  }

  Future<void> restoreRecord(BuildContext context, HistoryRecord record) async {
    final expense = Expense(
      name: record.name,
      amount: record.amount,
      spend_date: record.spend_date,
      created_at: record.created_at,
      updated_at: record.updated_at,
      user_id: record.user_id,
      category: record.category,
    );
    await DBHelper().insertExpense(expense);
    await DBHelper().deleteHistoryRecord(record.id!);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Record restored')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('History'),
      ),
      body: FutureBuilder<List<HistoryRecord>>(
        future: fetchHistoryRecords(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No history records found'));
          } else {
            final historyRecords = snapshot.data!;
            return ListView.builder(
              itemCount: historyRecords.length,
              itemBuilder: (context, index) {
                final record = historyRecords[index];
                return ListTile(
                  title: Text(record.name),
                  subtitle: Text('Deleted at: ${record.deleted_at}'),
                  trailing: IconButton(
                    icon: Icon(Icons.restore),
                    onPressed: () => restoreRecord(context, record),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}