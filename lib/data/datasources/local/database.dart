/// SQLite database setup and operations.
library;

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Database helper for local storage.
class AppDatabase {
  static const String _dbName = 'msa.db';
  static const int _dbVersion = 1;

  static Database? _database;

  /// Get database instance (singleton).
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize the database.
  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create tables on first run.
  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE positions (
        ticker TEXT PRIMARY KEY,
        shares INTEGER NOT NULL,
        avg_cost REAL NOT NULL,
        current_price REAL NOT NULL,
        last_updated INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE trades (
        id TEXT PRIMARY KEY,
        ticker TEXT NOT NULL,
        type TEXT NOT NULL,
        shares INTEGER NOT NULL,
        price REAL NOT NULL,
        timestamp INTEGER NOT NULL,
        signal TEXT NOT NULL,
        pnl REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE market_data (
        ticker TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        open REAL NOT NULL,
        high REAL NOT NULL,
        low REAL NOT NULL,
        close REAL NOT NULL,
        volume INTEGER NOT NULL,
        PRIMARY KEY (ticker, timestamp)
      )
    ''');

    await db.execute('''
      CREATE TABLE performance_snapshots (
        date INTEGER PRIMARY KEY,
        portfolio_value REAL NOT NULL,
        daily_pnl REAL NOT NULL,
        total_return REAL NOT NULL,
        sharpe_ratio REAL,
        max_drawdown REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE alpha_configs (
        alpha_name TEXT PRIMARY KEY,
        config TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Create indexes for performance
    await db.execute('CREATE INDEX idx_trades_ticker ON trades(ticker)');
    await db.execute('CREATE INDEX idx_trades_timestamp ON trades(timestamp)');
    await db.execute('CREATE INDEX idx_market_data_ticker ON market_data(ticker)');
  }

  /// Handle database upgrades.
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle migrations as needed
  }

  /// Close the database.
  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
