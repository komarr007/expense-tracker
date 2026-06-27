import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/debt.dart';
import '../models/envelope.dart';
import '../models/expense.dart';
import '../models/history_record.dart';
import '../models/income_record.dart';
import '../models/net_worth_item.dart';
import '../models/recurring_expense.dart';
import '../models/expense_category.dart';
import '../models/savings_goal.dart';
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
      version: 7,
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

    await db.execute('''
      CREATE TABLE net_worth_items (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        name        TEXT NOT NULL,
        value       REAL NOT NULL,
        type        TEXT NOT NULL,
        is_asset    INTEGER NOT NULL,
        created_at  TEXT NOT NULL,
        updated_at  TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE envelopes (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        name            TEXT NOT NULL,
        category        TEXT NOT NULL,
        monthly_budget  REAL NOT NULL,
        created_at      TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE debts (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        name             TEXT NOT NULL,
        original_amount  REAL NOT NULL,
        current_balance  REAL NOT NULL,
        interest_rate    REAL NOT NULL DEFAULT 0,
        minimum_payment  REAL,
        due_day          INTEGER,
        created_at       TEXT NOT NULL,
        updated_at       TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE savings_goals (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        name           TEXT NOT NULL,
        target_amount  REAL NOT NULL,
        current_amount REAL NOT NULL DEFAULT 0,
        deadline       TEXT,
        color_hex      TEXT NOT NULL DEFAULT 'FF6C63FF',
        created_at     TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE expense_categories (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        name       TEXT NOT NULL UNIQUE,
        color_hex  TEXT NOT NULL,
        nature     TEXT NOT NULL DEFAULT 'wants',
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_default INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await _seedCategories(db, _freshSeeds);
  }

  // Seed rows for a brand-new install (universal, language-neutral labels).
  static const List<Map<String, dynamic>> _freshSeeds = <Map<String, dynamic>>[
    <String, dynamic>{'name': 'food',          'color_hex': 'FFF472B6', 'nature': 'needs',   'sort_order': 0,  'is_default': 0},
    <String, dynamic>{'name': 'transport',     'color_hex': 'FF60A5FA', 'nature': 'needs',   'sort_order': 1,  'is_default': 0},
    <String, dynamic>{'name': 'health',        'color_hex': 'FFFB7185', 'nature': 'needs',   'sort_order': 2,  'is_default': 0},
    <String, dynamic>{'name': 'bills',         'color_hex': 'FFA78BFA', 'nature': 'needs',   'sort_order': 3,  'is_default': 0},
    <String, dynamic>{'name': 'shopping',      'color_hex': 'FF2DD4BF', 'nature': 'wants',   'sort_order': 4,  'is_default': 0},
    <String, dynamic>{'name': 'entertainment', 'color_hex': 'FFFBBF24', 'nature': 'wants',   'sort_order': 5,  'is_default': 0},
    <String, dynamic>{'name': 'savings',       'color_hex': 'FF4ADE80', 'nature': 'savings', 'sort_order': 6,  'is_default': 0},
    <String, dynamic>{'name': 'investment',    'color_hex': 'FF818CF8', 'nature': 'savings', 'sort_order': 7,  'is_default': 0},
    <String, dynamic>{'name': 'education',     'color_hex': 'FFF59E0B', 'nature': 'needs',   'sort_order': 8,  'is_default': 0},
    <String, dynamic>{'name': 'others',        'color_hex': 'FF94A3B8', 'nature': 'wants',   'sort_order': 99, 'is_default': 1},
  ];

  // Seed rows for users migrating from v6 — preserves old category strings
  // that already exist in their expenses table.
  static const List<Map<String, dynamic>> _migrationSeeds = <Map<String, dynamic>>[
    <String, dynamic>{'name': 'jajan',                  'color_hex': 'FF2DD4BF', 'nature': 'wants',   'sort_order': 0,  'is_default': 0},
    <String, dynamic>{'name': 'makan',                  'color_hex': 'FFF472B6', 'nature': 'needs',   'sort_order': 1,  'is_default': 0},
    <String, dynamic>{'name': 'savings',                'color_hex': 'FF4ADE80', 'nature': 'savings', 'sort_order': 2,  'is_default': 0},
    <String, dynamic>{'name': 'investment',             'color_hex': 'FF60A5FA', 'nature': 'savings', 'sort_order': 3,  'is_default': 0},
    <String, dynamic>{'name': 'health',                 'color_hex': 'FFFB7185', 'nature': 'needs',   'sort_order': 4,  'is_default': 0},
    <String, dynamic>{'name': 'mandatory share income', 'color_hex': 'FFA78BFA', 'nature': 'needs',   'sort_order': 5,  'is_default': 0},
    <String, dynamic>{'name': 'tarik tunai',            'color_hex': 'FF94A3B8', 'nature': 'needs',   'sort_order': 6,  'is_default': 0},
    <String, dynamic>{'name': 'others',                 'color_hex': 'FFFBBF24', 'nature': 'wants',   'sort_order': 99, 'is_default': 1},
  ];

  Future<void> _seedCategories(
      Database db, List<Map<String, dynamic>> seeds) async {
    for (final Map<String, dynamic> row in seeds) {
      await db.insert(
        'expense_categories',
        row,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
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
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS net_worth_items (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          name        TEXT NOT NULL,
          value       REAL NOT NULL,
          type        TEXT NOT NULL,
          is_asset    INTEGER NOT NULL,
          created_at  TEXT NOT NULL,
          updated_at  TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS envelopes (
          id              INTEGER PRIMARY KEY AUTOINCREMENT,
          name            TEXT NOT NULL,
          category        TEXT NOT NULL,
          monthly_budget  REAL NOT NULL,
          created_at      TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS debts (
          id               INTEGER PRIMARY KEY AUTOINCREMENT,
          name             TEXT NOT NULL,
          original_amount  REAL NOT NULL,
          current_balance  REAL NOT NULL,
          interest_rate    REAL NOT NULL DEFAULT 0,
          minimum_payment  REAL,
          due_day          INTEGER,
          created_at       TEXT NOT NULL,
          updated_at       TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS savings_goals (
          id             INTEGER PRIMARY KEY AUTOINCREMENT,
          name           TEXT NOT NULL,
          target_amount  REAL NOT NULL,
          current_amount REAL NOT NULL DEFAULT 0,
          deadline       TEXT,
          color_hex      TEXT NOT NULL DEFAULT 'FF6C63FF',
          created_at     TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS expense_categories (
          id         INTEGER PRIMARY KEY AUTOINCREMENT,
          name       TEXT NOT NULL UNIQUE,
          color_hex  TEXT NOT NULL,
          nature     TEXT NOT NULL DEFAULT 'wants',
          sort_order INTEGER NOT NULL DEFAULT 0,
          is_default INTEGER NOT NULL DEFAULT 0
        )
      ''');
      // Seed with the old hardcoded categories so existing expense records
      // still resolve to correct colors and 50/30/20 buckets.
      await _seedCategories(db, _migrationSeeds);
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

  // ── Finance queries ──────────────────────────────────────────────────────────

  Future<double> getMonthlyIncomeTotal(int year, int month) async {
    final db   = await database;
    final String ym = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    final List<Map<String, dynamic>> result = await db.rawQuery(
      "SELECT COALESCE(SUM(amount), 0) AS total FROM income_records WHERE strftime('%Y-%m', income_date) = ?",
      <Object>[ym],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // Returns total amount per expense category for the given month.
  Future<Map<String, double>> getExpenseCategoryTotals(int year, int month) async {
    final db = await database;
    final String ym = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    final List<Map<String, dynamic>> rows = await db.rawQuery(
      "SELECT category, COALESCE(SUM(amount), 0) AS total FROM expenses WHERE strftime('%Y-%m', spend_date) = ? GROUP BY category",
      <Object>[ym],
    );
    return <String, double>{
      for (final r in rows) r['category'] as String: (r['total'] as num).toDouble(),
    };
  }

  // ── Net worth ────────────────────────────────────────────────────────────────

  Future<int> insertNetWorthItem(NetWorthItem item) async {
    final db = await database;
    return db.insert('net_worth_items', item.toMap());
  }

  Future<int> updateNetWorthItem(NetWorthItem item) async {
    final db = await database;
    return db.update(
      'net_worth_items', item.toMap(),
      where: 'id = ?', whereArgs: <Object?>[item.id],
    );
  }

  Future<int> deleteNetWorthItem(int id) async {
    final db = await database;
    return db.delete('net_worth_items', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<List<NetWorthItem>> getNetWorthItems() async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('net_worth_items', orderBy: 'is_asset DESC, created_at ASC');
    return maps.map(NetWorthItem.fromMap).toList();
  }

  // ── Envelopes ────────────────────────────────────────────────────────────────

  Future<int> insertEnvelope(Envelope envelope) async {
    final db = await database;
    return db.insert('envelopes', envelope.toMap());
  }

  Future<int> updateEnvelope(Envelope envelope) async {
    final db = await database;
    return db.update(
      'envelopes', envelope.toMap(),
      where: 'id = ?', whereArgs: <Object?>[envelope.id],
    );
  }

  Future<int> deleteEnvelope(int id) async {
    final db = await database;
    return db.delete('envelopes', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<List<Envelope>> getEnvelopes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('envelopes', orderBy: 'created_at ASC');
    return maps.map(Envelope.fromMap).toList();
  }

  // ── Debts ────────────────────────────────────────────────────────────────────

  Future<int> insertDebt(Debt debt) async {
    final db = await database;
    return db.insert('debts', debt.toMap());
  }

  Future<int> updateDebt(Debt debt) async {
    final db = await database;
    return db.update(
      'debts', debt.toMap(),
      where: 'id = ?', whereArgs: <Object?>[debt.id],
    );
  }

  Future<int> deleteDebt(int id) async {
    final db = await database;
    return db.delete('debts', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<List<Debt>> getDebts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('debts', orderBy: 'created_at ASC');
    return maps.map(Debt.fromMap).toList();
  }

  // ── Savings Goals ─────────────────────────────────────────────────────────────

  Future<int> insertGoal(SavingsGoal goal) async {
    final db = await database;
    return db.insert('savings_goals', goal.toMap());
  }

  Future<int> updateGoal(SavingsGoal goal) async {
    final db = await database;
    return db.update(
      'savings_goals', goal.toMap(),
      where: 'id = ?', whereArgs: <Object?>[goal.id],
    );
  }

  Future<int> deleteGoal(int id) async {
    final db = await database;
    return db.delete('savings_goals', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<List<SavingsGoal>> getGoals() async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('savings_goals', orderBy: 'created_at ASC');
    return maps.map(SavingsGoal.fromMap).toList();
  }

  // ── Expense categories ───────────────────────────────────────────────────────

  Future<List<ExpenseCategory>> getCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('expense_categories', orderBy: 'sort_order ASC, name ASC');
    return maps.map(ExpenseCategory.fromMap).toList();
  }

  Future<int> insertCategory(ExpenseCategory cat) async {
    final db = await database;
    return db.insert('expense_categories', cat.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateCategory(ExpenseCategory cat) async {
    final db = await database;
    return db.update(
      'expense_categories', cat.toMap(),
      where: 'id = ?', whereArgs: <Object?>[cat.id],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    return db.delete(
      'expense_categories', where: 'id = ? AND is_default = 0', whereArgs: <Object?>[id],
    );
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
