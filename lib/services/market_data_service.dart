/// Market data ingestion and caching service.
library;

import 'package:sqflite/sqflite.dart';

import '../../data/datasources/local/database.dart';
import '../../data/models/market_data.dart';
import 'yahoo/yahoo_finance_repository.dart';

/// Service for ingesting and caching market data locally.
class MarketDataService {
  MarketDataService({YahooFinanceRepository? yahooRepo})
      : _yahooRepo = yahooRepo ?? YahooFinanceRepository();

  final YahooFinanceRepository _yahooRepo;

  /// Get cached data for a ticker, fetching from API if needed.
  Future<List<MarketData>> getData(String ticker, {int days = 365}) async {
    final db = await AppDatabase.database;

    // Check what we have cached
    final latestCached = await _getLatestTimestamp(db, ticker);
    final now = DateTime.now();

    if (latestCached == null) {
      // No cached data - fetch full history
      await ingestHistorical(ticker, days: days);
    } else {
      // Check if we need to update
      final hoursSinceUpdate = now.difference(latestCached).inHours;
      if (hoursSinceUpdate > 1) {
        // Fetch incremental update
        await ingestLatest(ticker);
      }
    }

    // Return cached data
    return _getCachedData(db, ticker, days: days);
  }

  /// Ingest historical data for a ticker.
  Future<int> ingestHistorical(String ticker, {int days = 365}) async {
    final bars = await _yahooRepo.getHistoricalData(ticker, days: days);
    if (bars.isEmpty) return 0;

    final db = await AppDatabase.database;
    var count = 0;

    // Use batch for performance
    final batch = db.batch();
    for (final bar in bars) {
      batch.insert(
        'market_data',
        {
          'ticker': bar.ticker,
          'timestamp': bar.timestamp.millisecondsSinceEpoch,
          'open': bar.open,
          'high': bar.high,
          'low': bar.low,
          'close': bar.close,
          'volume': bar.volume,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      count++;
    }

    await batch.commit(noResult: true);
    return count;
  }

  /// Ingest latest data (incremental update).
  Future<int> ingestLatest(String ticker) async {
    final quote = await _yahooRepo.getLatestQuote(ticker);
    if (quote == null) return 0;

    final db = await AppDatabase.database;
    await db.insert(
      'market_data',
      {
        'ticker': quote.ticker,
        'timestamp': quote.timestamp.millisecondsSinceEpoch,
        'open': quote.open,
        'high': quote.high,
        'low': quote.low,
        'close': quote.close,
        'volume': quote.volume,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return 1;
  }

  /// Get latest cached timestamp for a ticker.
  Future<DateTime?> _getLatestTimestamp(Database db, String ticker) async {
    final result = await db.query(
      'market_data',
      columns: ['MAX(timestamp) as latest'],
      where: 'ticker = ?',
      whereArgs: [ticker],
    );

    if (result.isEmpty || result.first['latest'] == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(result.first['latest'] as int);
  }

  /// Get cached data from database.
  Future<List<MarketData>> _getCachedData(Database db, String ticker, {int days = 365}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));

    final result = await db.query(
      'market_data',
      where: 'ticker = ? AND timestamp >= ?',
      whereArgs: [ticker, cutoff.millisecondsSinceEpoch],
      orderBy: 'timestamp ASC',
    );

    return result.map((row) => MarketData(
      ticker: row['ticker'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
      open: row['open'] as double,
      high: row['high'] as double,
      low: row['low'] as double,
      close: row['close'] as double,
      volume: row['volume'] as int,
    )).toList();
  }

  /// Get data for a specific time range.
  Future<List<MarketData>> getDataRange(String ticker, DateTime start, DateTime end) async {
    final db = await AppDatabase.database;

    final result = await db.query(
      'market_data',
      where: 'ticker = ? AND timestamp >= ? AND timestamp <= ?',
      whereArgs: [ticker, start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'timestamp ASC',
    );

    return result.map((row) => MarketData(
      ticker: row['ticker'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
      open: row['open'] as double,
      high: row['high'] as double,
      low: row['low'] as double,
      close: row['close'] as double,
      volume: row['volume'] as int,
    )).toList();
  }

  /// Clear cached data for a ticker (or all if null).
  Future<void> clearCache({String? ticker}) async {
    final db = await AppDatabase.database;
    if (ticker != null) {
      await db.delete('market_data', where: 'ticker = ?', whereArgs: [ticker]);
    } else {
      await db.delete('market_data');
    }
  }
}
