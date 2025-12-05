/// Market data ingestion and caching service.
library;

import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../data/datasources/local/database.dart';
import '../../data/models/market_data.dart';
import 'yahoo/yahoo_finance_repository.dart';

/// Service for ingesting and caching market data locally.
/// On web, data is fetched fresh each time (no caching).
class MarketDataService {
  MarketDataService({
    YahooFinanceRepository? yahooRepo,
    DataInterval interval = DataInterval.oneMinute,
  }) : _yahooRepo = yahooRepo ?? YahooFinanceRepository(interval: interval),
       _interval = interval;

  final YahooFinanceRepository _yahooRepo;
  final DataInterval _interval;

  /// Get data for a ticker - cached on native, fresh on web.
  Future<List<MarketData>> getData(String ticker, {int days = 7}) async {
    // On web, just fetch directly (no SQLite support)
    if (kIsWeb) {
      return _yahooRepo.getHistoricalData(ticker, days: days);
    }

    // On native platforms, use SQLite cache
    final db = await AppDatabase.database;

    // Check what we have cached for this interval
    final latestCached = await _getLatestTimestamp(db, ticker);
    final now = DateTime.now();

    if (latestCached == null) {
      // No cached data - fetch full history
      await ingestHistorical(ticker, days: days);
    } else {
      // Check if we need to update (more than 5 minutes old for 1m data)
      final minutesSinceUpdate = now.difference(latestCached).inMinutes;
      if (minutesSinceUpdate > 5) {
        await ingestHistorical(ticker, days: days);
      }
    }

    // Return cached data
    return _getCachedData(db, ticker, days: days);
  }

  /// Ingest historical data for a ticker.
  Future<int> ingestHistorical(String ticker, {int days = 7}) async {
    if (kIsWeb) return 0;

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
          'interval': _interval.value,
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
    // ignore: avoid_print
    print('MarketDataService: Cached $count bars for $ticker (${_interval.value})');
    return count;
  }

  /// Get latest cached timestamp for a ticker.
  Future<DateTime?> _getLatestTimestamp(Database db, String ticker) async {
    final result = await db.query(
      'market_data',
      columns: ['MAX(timestamp) as latest'],
      where: 'ticker = ? AND interval = ?',
      whereArgs: [ticker, _interval.value],
    );

    if (result.isEmpty || result.first['latest'] == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(result.first['latest'] as int);
  }

  /// Get cached data from database.
  Future<List<MarketData>> _getCachedData(Database db, String ticker, {int days = 7}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));

    final result = await db.query(
      'market_data',
      where: 'ticker = ? AND interval = ? AND timestamp >= ?',
      whereArgs: [ticker, _interval.value, cutoff.millisecondsSinceEpoch],
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
    if (kIsWeb) return;

    final db = await AppDatabase.database;
    if (ticker != null) {
      await db.delete('market_data', where: 'ticker = ?', whereArgs: [ticker]);
    } else {
      await db.delete('market_data');
    }
  }
}
