import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/expense.dart';
import '../models/history_record.dart';
import 'package:logger/logger.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  static Database? _database;
  final Logger logger = Logger();

  factory DBHelper() {
    return _instance;
  }

  DBHelper._internal();

  // Add a named constructor for testing purposes
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
    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade, // Add onUpgrade method for migrations
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        amount REAL,
        spend_date TEXT,
        created_at TEXT,
        updated_at TEXT,
        user_id TEXT,
        category TEXT  -- New category field
      )
    ''');

    await db.execute('''
      CREATE TABLE history_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        amount REAL,
        spend_date TEXT,
        created_at TEXT,
        updated_at TEXT,
        user_id TEXT,
        category TEXT,
        deleted_at TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add the category column for users upgrading from version 1
      await db.execute('ALTER TABLE expenses ADD COLUMN category TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE history_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT,
          amount REAL,
          spend_date TEXT,
          created_at TEXT,
          updated_at TEXT,
          user_id TEXT,
          category TEXT,
          deleted_at TEXT
        )
      ''');
    }
  }

  Future<int> insertExpense(Expense expense) async {
    final Database db = await database;
    return await db.insert('expenses', expense.toMap());
  }

  Future<int> deleteExpense(int id) async {
    final Database db = await database;
    return await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<int> updateExpense(Expense expense) async {
    final Database db = await database;
    return await db.update(
      'expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[expense.id],
    );
  }

  Future<List<Expense>> getExpenses() async {
    final Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('expenses');

    return List.generate(maps.length, (int i) {
      return Expense(
        id: maps[i]['id'],
        name: maps[i]['name'],
        amount: maps[i]['amount'],
        spend_date: DateTime.parse(maps[i]['spend_date']),
        created_at: DateTime.parse(maps[i]['created_at']),
        updated_at: DateTime.parse(maps[i]['updated_at']),
        category: maps[i]['category'] ?? 'Uncategorized', // Handle null category
      );
    });
  }

  Future<int> insertHistoryRecord(HistoryRecord record) async {
    final Database db = await database;
    return await db.insert('history_records', record.toMap());
  }

  Future<List<HistoryRecord>> getHistoryRecords() async {
    final Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('history_records');

    return List.generate(maps.length, (int i) {
      return HistoryRecord(
        id: maps[i]['id'],
        name: maps[i]['name'],
        amount: maps[i]['amount'],
        spend_date: DateTime.parse(maps[i]['spend_date']),
        created_at: DateTime.parse(maps[i]['created_at']),
        updated_at: DateTime.parse(maps[i]['updated_at']),
        category: maps[i]['category'],
        deleted_at: DateTime.parse(maps[i]['deleted_at']),
      );
    });
  }

  Future<int> deleteHistoryRecord(int id) async {
    final Database db = await database;
    return await db.delete(
      'history_records',
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> deleteOldHistoryRecords() async {
    final Database db = await database;
    final String twoWeeksAgo = DateTime.now().subtract(const Duration(days: 14)).toIso8601String();
    await db.delete(
      'history_records',
      where: 'deleted_at < ?',
      whereArgs: <Object?>[twoWeeksAgo],
    );
  }

  Future<void> importExistingData(String etlDbPath) async {
    // Open the existing database
    final Database etlDb = await openDatabase(etlDbPath);

    // Get all expense tables dynamically
    final List<Map<String, dynamic>> tables = await etlDb.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'expenses%';"
    );

    if (tables.isEmpty) {
      return;
    }

    // Open the app database
    final Database appDb = await database;

    for (Map<String, dynamic> table in tables) {
      final tableName = table['name'];

      // Query data from the current existing table
      final List<Map<String, dynamic>> etlData = await etlDb.query(tableName);

      // Insert data into the app database
      for (Map<String, dynamic> record in etlData) {
        final Map<String, dynamic> appRecord = <String, dynamic>{
          'id': record['id'],  // Primary key (can be null to auto-generate)
          'name': record['name'],
          'amount': record['amount']?.toDouble(),
          'spend_date': record['spend_date'],
          'created_at': record['created_at'],
          'updated_at': record['updated_at'],
          'user_id': record['user_id'],
          'category': record['category'] ?? 'Uncategorized',
        };

        // Insert into the app database
        try {
          await appDb.insert('expenses', appRecord, conflictAlgorithm: ConflictAlgorithm.replace);
        } catch (e, stackTrace) {
          logger.e('An error occurred', error: e, stackTrace: stackTrace);
        }
      }
    }

    // Close the existing database
    await etlDb.close();
  }
}
