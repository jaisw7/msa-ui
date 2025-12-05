/// Trading repository for positions and trades.
library;

import 'package:sqflite/sqflite.dart';

import '../datasources/local/database.dart';
import '../models/position.dart';
import '../models/trade.dart';

/// Repository interface for trading operations.
abstract class TradingRepository {
  /// Get all positions.
  Future<List<Position>> getAllPositions();

  /// Get position by ticker.
  Future<Position?> getPosition(String ticker);

  /// Save or update a position.
  Future<void> savePosition(Position position);

  /// Update an existing position.
  Future<void> updatePosition(Position position);

  /// Delete a position.
  Future<void> deletePosition(String ticker);

  /// Get all trades.
  Future<List<Trade>> getAllTrades();

  /// Get trades for a ticker.
  Future<List<Trade>> getTradesForTicker(String ticker);

  /// Save a trade.
  Future<void> saveTrade(Trade trade);

  /// Get recent trades (last N).
  Future<List<Trade>> getRecentTrades(int limit);
}

/// SQLite implementation of TradingRepository.
class SqliteTradingRepository implements TradingRepository {
  @override
  Future<List<Position>> getAllPositions() async {
    final db = await AppDatabase.database;
    final maps = await db.query('positions', orderBy: 'ticker ASC');
    return maps.map((m) => Position.fromMap(m)).toList();
  }

  @override
  Future<Position?> getPosition(String ticker) async {
    final db = await AppDatabase.database;
    final maps = await db.query(
      'positions',
      where: 'ticker = ?',
      whereArgs: [ticker],
    );
    if (maps.isEmpty) return null;
    return Position.fromMap(maps.first);
  }

  @override
  Future<void> savePosition(Position position) async {
    final db = await AppDatabase.database;
    await db.insert(
      'positions',
      position.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updatePosition(Position position) async {
    final db = await AppDatabase.database;
    await db.update(
      'positions',
      position.toMap(),
      where: 'ticker = ?',
      whereArgs: [position.ticker],
    );
  }

  @override
  Future<void> deletePosition(String ticker) async {
    final db = await AppDatabase.database;
    await db.delete(
      'positions',
      where: 'ticker = ?',
      whereArgs: [ticker],
    );
  }

  @override
  Future<List<Trade>> getAllTrades() async {
    final db = await AppDatabase.database;
    final maps = await db.query('trades', orderBy: 'timestamp DESC');
    return maps.map((m) => Trade.fromMap(m)).toList();
  }

  @override
  Future<List<Trade>> getTradesForTicker(String ticker) async {
    final db = await AppDatabase.database;
    final maps = await db.query(
      'trades',
      where: 'ticker = ?',
      whereArgs: [ticker],
      orderBy: 'timestamp DESC',
    );
    return maps.map((m) => Trade.fromMap(m)).toList();
  }

  @override
  Future<void> saveTrade(Trade trade) async {
    final db = await AppDatabase.database;
    await db.insert(
      'trades',
      trade.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<Trade>> getRecentTrades(int limit) async {
    final db = await AppDatabase.database;
    final maps = await db.query(
      'trades',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return maps.map((m) => Trade.fromMap(m)).toList();
  }
}
