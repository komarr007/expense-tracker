import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite/sqflite.dart';
import '../../lib/helpers/db_helper.dart';
import '../../lib/models/expense.dart';

import 'db_helper_test.mocks.dart';

@GenerateMocks([Database])
void main() {
  late MockDatabase mockDatabase;
  late DBHelper dbHelper;

  setUp(() {
    mockDatabase = MockDatabase();
    dbHelper = DBHelper.test(database: mockDatabase);
  });

  test('should insert an expense into the database', () async {
    final expense = Expense(
      name: 'Groceries',
      spend_date: DateTime.now(),
      category: 'Food',
      amount: 100.0,
    );

    when(mockDatabase.insert('expenses', any)).thenAnswer((_) async => 1);

    await dbHelper.insertExpense(expense);

    verify(mockDatabase.insert('expenses', expense.toMap())).called(1);
  });

  test('should retrieve expenses from the database', () async {
    when(mockDatabase.query('expenses')).thenAnswer((_) async => [
      {
        'id': 1,
        'name': 'Groceries',
        'amount': 100.0,
        'spend_date': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'category': 'Food',
      }
    ]);

    final expenses = await dbHelper.getExpenses();

    expect(expenses.length, 1);
    expect(expenses.first.name, 'Groceries');
    expect(expenses.first.category, 'Food');
  });

  test('should delete an expense from the database', () async {
    when(mockDatabase.delete('expenses', where: 'id = ?', whereArgs: [1]))
        .thenAnswer((_) async => 1);

    await dbHelper.deleteExpense(1);

    verify(mockDatabase.delete('expenses', where: 'id = ?', whereArgs: [1]))
        .called(1);
  });
}
