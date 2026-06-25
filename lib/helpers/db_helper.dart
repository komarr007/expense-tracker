import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/expense.dart';
import '../models/history_record.dart';
import '../models/income_record.dart';
import '../models/recurring_expense.dart';
import 'package:logger/logger.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  static Database? _database;
  final Logger logger = Logger();

  factory DBHelper() => _instance;
  DBHelper._internal();
  DBHelper.test({Database? database}) {
    _database = database;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final String path = join(await getDatabasesPath(), 'expense.db');
    return openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // ── Schema creation (fresh install) ─────────────────────────────────────────

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE expenses (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        name        TEXT,
        amount      REAL,
        spend_date  TEXT,
        created_at  TEXT,
        updated_at  TEXT,
        user_id     TEXT,
        category    TEXT,
        notes       TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE history_records (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        name        TEXT,
        amount      REAL,
        spend_date  TEXT,
        created_at  TEXT,
        updated_at  TEXT,
        user_id     TEXT,
        category    TEXT,
        notes       TEXT,
        deleted_at  TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE income_records (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        name        TEXT NOT NULL,
        amount      REAL NOT NULL,
        income_date TEXT NOT NULL,
        category    TEXT NOT NULL,
        notes       TEXT,
        created_at  TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE recurring_expenses (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        name        TEXT NOT NULL,
        amount      REAL NOT NULL,
        category    TEXT NOT NULL,
        notes       TEXT,
        frequency   TEXT NOT NULL,
        next_due    TEXT NOT NULL,
        created_at  TEXT NOT NULL
      )
    ''');
  }

  // ── Migrations ───────────────────────────────────────────────────────────────

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE expenses ADD COLUMN category TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE history_records (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          name        TEXT,
          amount      REAL,
          spend_date  TEXT,
          created_at  TEXT,
          updated_at  TEXT,
          user_id     TEXT,
          category    TEXT,
          deleted_at  TEXT
        )
      ''');
    }
    if (oldVersion < 4) {
      // Add notes to expenses
      try {
        await db.execute('ALTER TABLE expenses ADD COLUMN notes TEXT');
      } catch (_) {}
      // Add notes to history_records
      try {
        await db.execute('ALTER TABLE history_records ADD COLUMN notes TEXT');
      } catch (_) {}

      await db.execute('''
        CREATE TABLE IF NOT EXISTS income_records (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          name        TEXT NOT NULL,
          amount      REAL NOT NULL,
          income_date TEXT NOT NULL,
          category    TEXT NOT NULL,
          notes       TEXT,
          created_at  TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS recurring_expenses (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          name        TEXT NOT NULL,
          amount      REAL NOT NULL,
          category    TEXT NOT NULL,
          notes       TEXT,
          frequency   TEXT NOT NULL,
          next_due    TEXT NOT NULL,
          created_at  TEXT NOT NULL
        )
      ''');
    }
  }

  // ── Expenses ─────────────────────────────────────────────────────────────────

  Future<int> insertExpense(Expense expense) async {
    final db = await database;
    return db.insert('expenses', expense.toMap());
  }

  Future<int> updateExpense(Expense expense) async {
    final db = await database;
    return db.update(
      'expenses', expense.toMap(),
      where: 'id = ?', whereArgs: <Object?>[expense.id],
    );
  }

  Future<int> deleteExpense(int id) async {
    final db = await database;
    return db.delete('expenses', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  // Atomically moves an expense to history_records and deletes it from expenses.
  // Using a transaction prevents phantom duplicates if one step fails.
  Future<void> softDeleteExpense(Expense expense) async {
    final db = await database;
    final HistoryRecord record = HistoryRecord(
      name:       expense.name,
      amount:     expense.amount,
      spend_date: expense.spend_date,
      created_at: expense.created_at,
      updated_at: expense.updated_at,
      category:   expense.category,
      notes:      expense.notes,
      deleted_at: DateTime.now(),
    );
    await db.transaction((txn) async {
      await txn.insert('history_records', record.toMap());
      await txn.delete('expenses', where: 'id = ?', whereArgs: <Object?>[expense.id]);
    });
  }

  // Returns the sum of expenses for a given year+month without loading all rows.
  Future<double> getMonthlyExpenseTotal(int year, int month) async {
    final db   = await database;
    final String ym = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    final List<Map<String, dynamic>> result = await db.rawQuery(
      "SELECT COALESCE(SUM(amount), 0) AS total FROM expenses WHERE strftime('%Y-%m', spend_date) = ?",
      <Object>[ym],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // Returns the sum of expenses for a given year+month+category.
  Future<double> getCategoryMonthlyTotal(int year, int month, String category) async {
    final db   = await database;
    final String ym = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    final List<Map<String, dynamic>> result = await db.rawQuery(
      "SELECT COALESCE(SUM(amount), 0) AS total FROM expenses WHERE strftime('%Y-%m', spend_date) = ? AND category = ?",
      <Object>[ym, category],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<List<Expense>> getExpenses() async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('expenses', orderBy: 'spend_date DESC');
    return maps.map(Expense.fromMap).toList();
  }

  // ── History records ──────────────────────────────────────────────────────────

  Future<int> insertHistoryRecord(HistoryRecord record) async {
    final db = await database;
    return db.insert('history_records', record.toMap());
  }

  Future<int> deleteHistoryRecord(int id) async {
    final db = await database;
    return db.delete(
      'history_records', where: 'id = ?', whereArgs: <Object?>[id],
    );
  }

  Future<List<HistoryRecord>> getHistoryRecords() async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('history_records', orderBy: 'deleted_at DESC');
    return maps.map(HistoryRecord.fromMap).toList();
  }

  Future<void> deleteOldHistoryRecords() async {
    final db = await database;
    final String cutoff =
        DateTime.now().subtract(const Duration(days: 14)).toIso8601String();
    await db.delete(
      'history_records', where: 'deleted_at < ?', whereArgs: <Object?>[cutoff],
    );
  }

  // ── Income records ───────────────────────────────────────────────────────────

  Future<int> insertIncome(IncomeRecord record) async {
    final db = await database;
    return db.insert('income_records', record.toMap());
  }

  Future<int> updateIncome(IncomeRecord record) async {
    final db = await database;
    return db.update(
      'income_records', record.toMap(),
      where: 'id = ?', whereArgs: <Object?>[record.id],
    );
  }

  Future<int> deleteIncome(int id) async {
    final db = await database;
    return db.delete(
      'income_records', where: 'id = ?', whereArgs: <Object?>[id],
    );
  }

  Future<List<IncomeRecord>> getIncomeRecords() async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('income_records', orderBy: 'income_date DESC');
    return maps.map(IncomeRecord.fromMap).toList();
  }

  // ── Recurring expenses ───────────────────────────────────────────────────────

  Future<int> insertRecurring(RecurringExpense r) async {
    final db = await database;
    return db.insert('recurring_expenses', r.toMap());
  }

  Future<int> updateRecurring(RecurringExpense r) async {
    final db = await database;
    return db.update(
      'recurring_expenses', r.toMap(),
      where: 'id = ?', whereArgs: <Object?>[r.id],
    );
  }

  Future<int> deleteRecurring(int id) async {
    final db = await database;
    return db.delete(
      'recurring_expenses', where: 'id = ?', whereArgs: <Object?>[id],
    );
  }

  Future<List<RecurringExpense>> getRecurringExpenses() async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('recurring_expenses', orderBy: 'next_due ASC');
    return maps.map(RecurringExpense.fromMap).toList();
  }

  /// Auto-insert expense records for all overdue recurring templates.
  /// Catches up on missed cycles (e.g. after not opening the app for a month).
  Future<int> processRecurringExpenses() async {
    final db   = await database;
    final now  = DateTime.now();
    int created = 0;

    final List<Map<String, dynamic>> rows =
        await db.query('recurring_expenses');

    for (final row in rows) {
      DateTime nextDue = DateTime.parse(row['next_due'] as String);

      while (!nextDue.isAfter(now)) {
        await db.insert('expenses', <String, dynamic>{
          'name':       row['name'],
          'amount':     row['amount'],
          'spend_date': nextDue.toIso8601String(),
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
          'category':   row['category'],
          'notes':      row['notes'],
        });
        created++;
        nextDue = _advance(nextDue, row['frequency'] as String);
      }

      await db.update(
        'recurring_expenses',
        <String, dynamic>{'next_due': nextDue.toIso8601String()},
        where: 'id = ?', whereArgs: <Object?>[row['id']],
      );
    }

    return created;
  }

  DateTime _advance(DateTime d, String frequency) {
    switch (frequency) {
      case 'daily':   return d.add(const Duration(days: 1));
      case 'weekly':  return d.add(const Duration(days: 7));
      case 'monthly': return DateTime(d.year, d.month + 1, d.day);
      default:        return d.add(const Duration(days: 30));
    }
  }

  // Closes and nulls the database connection so the next access reopens it fresh.
  // Call this before replacing the database file on disk (e.g. restore from backup).
  Future<void> resetDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
