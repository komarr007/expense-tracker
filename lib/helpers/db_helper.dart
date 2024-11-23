import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/expense.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  static Database? _database;

  factory DBHelper() {
    return _instance;
  }

  DBHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'expense.db');
    return await openDatabase(
      path,
      version: 2,
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
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add the category column for users upgrading from version 1
      await db.execute('ALTER TABLE expenses ADD COLUMN category TEXT');
    }
  }

  Future<int> insertExpense(Expense expense) async {
    final db = await database;
    return await db.insert('expenses', expense.toMap());
  }

  Future<int> deleteExpense(int id) async {
    final db = await database;
    return await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateExpense(Expense expense) async {
    final db = await database;
    return await db.update(
      'expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<List<Expense>> getExpenses() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('expenses');

    return List.generate(maps.length, (i) {
      return Expense(
        id: maps[i]['id'],
        name: maps[i]['name'],
        amount: maps[i]['amount'],
        spend_date: DateTime.parse(maps[i]['spend_date']),
        category: maps[i]['category'] ?? 'Uncategorized', // Handle null category
      );
    });
  }

  Future<void> importETLData(String etlDbPath) async {
    // Open the ETL database
    final etlDb = await openDatabase(etlDbPath);

    // Get all expense tables dynamically
    final List<Map<String, dynamic>> tables = await etlDb.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'expenses%';"
    );

    if (tables.isEmpty) {
      print('No expense tables found in ETL database.');
      return;
    }

    // Open the app database
    final appDb = await database;

    for (var table in tables) {
      final tableName = table['name'];
      print('Importing data from $tableName');

      // Query data from the current ETL table
      final List<Map<String, dynamic>> etlData = await etlDb.query(tableName);
      print('Fetched records from $tableName: $etlData');

      // Insert data into the app database
      for (var record in etlData) {
        final appRecord = {
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
        } catch (e) {
          print('Error inserting record: $e');
        }
      }
    }

    // Close the ETL database
    await etlDb.close();

    print('Data import completed.');
  }

  Future<void> importETLDataForceJuli(String etlDbPath) async {
      // Open the ETL database
      final etlDb = await openDatabase(etlDbPath);

      // Query data from the ETL table
      final List<Map<String, dynamic>> etlData = await etlDb.query('expenses_juni_juli');

      // Open the app database
      final appDb = await database;

      // Insert data into the app database
      for (var record in etlData) {
        // Transform the data to fit the app database schema
        final appRecord = {
          'id': record['id'],
          'name': record['name'],
          'amount': record['amount']?.toDouble(), // Convert to REAL (double)
          'spend_date': record['spend_date'],    // Ensure date format consistency
          'created_at': record['created_at'],
          'updated_at': record['updated_at'],
          'user_id': record['user_id'],
          'category': record['category'] ?? 'Uncategorized',
        };

        // Insert into the app database
        await appDb.insert('expenses', appRecord, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Close the ETL database
      await etlDb.close();
    }

  Future<void> importETLDataForceSeptember(String etlDbPath) async {
      // Open the ETL database
      final etlDb = await openDatabase(etlDbPath);

      // Query data from the ETL table
      final List<Map<String, dynamic>> etlData = await etlDb.query('expenses_agustus_september');

      // Open the app database
      final appDb = await database;

      // Insert data into the app database
      for (var record in etlData) {
        // Transform the data to fit the app database schema
        final appRecord = {
          'id': record['id'],
          'name': record['name'],
          'amount': record['amount']?.toDouble(), // Convert to REAL (double)
          'spend_date': record['spend_date'],    // Ensure date format consistency
          'created_at': record['created_at'],
          'updated_at': record['updated_at'],
          'user_id': record['user_id'],
          'category': record['category'] ?? 'Uncategorized',
        };

        // Insert into the app database
        await appDb.insert('expenses', appRecord, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Close the ETL database
      await etlDb.close();
    }

}
