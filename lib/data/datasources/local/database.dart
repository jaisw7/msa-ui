/// SQLite database setup and operations.
library;

import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Database helper for local storage.
class AppDatabase {
  static const String _dbName = 'msa.db';
  static const int _dbVersion = 2;  // Bumped for account_transactions

  static Database? _database;
  static bool _ffiInitialized = false;

  /// Check if we're on a platform that supports SQLite.
  static bool get isSupported => !kIsWeb;

  /// Initialize FFI for desktop platforms.
  static void _initFfi() {
    if (_ffiInitialized || kIsWeb) return;

    // Only use FFI on desktop (not mobile or web)
    if (defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    _ffiInitialized = true;
  }

  /// Get database instance (singleton).
  static Future<Database> get database async {
    if (!isSupported) {
      throw UnsupportedError('SQLite not supported on web');
    }

    _initFfi();
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize the database.
  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/$_dbName';

    // ignore: avoid_print
    print('AppDatabase: Opening database at $path');

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create tables on first run.
  static Future<void> _onCreate(Database db, int version) async {
    // ignore: avoid_print
    print('AppDatabase: Creating tables (version $version)');

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
        interval TEXT NOT NULL DEFAULT '1m',
        open REAL NOT NULL,
        high REAL NOT NULL,
        low REAL NOT NULL,
        close REAL NOT NULL,
        volume INTEGER NOT NULL,
        PRIMARY KEY (ticker, timestamp, interval)
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

    await db.execute('''
      CREATE TABLE account_transactions (
        transaction_id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        timestamp INTEGER NOT NULL,
        notes TEXT,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000)
      )
    ''');
    await db.execute('CREATE INDEX idx_account_transactions_timestamp ON account_transactions(timestamp)');

    // ignore: avoid_print
    print('AppDatabase: Tables created successfully');
  }

  /// Handle database upgrades.
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // ignore: avoid_print
    print('AppDatabase: Upgrading from $oldVersion to $newVersion');

    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS account_transactions (
          transaction_id INTEGER PRIMARY KEY AUTOINCREMENT,
          type TEXT NOT NULL,
          amount REAL NOT NULL,
          timestamp INTEGER NOT NULL,
          notes TEXT,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000)
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_account_transactions_timestamp ON account_transactions(timestamp)');
    }
  }

  /// Close the database.
  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
