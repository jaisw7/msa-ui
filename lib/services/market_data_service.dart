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
      final data = await _yahooRepo.getHistoricalData(ticker, days: days);
      // ignore: avoid_print
      print('MarketDataService: Fetched ${data.length} ticks for $ticker (web, no cache)');
      return data;
    }

    // On native platforms, use SQLite cache
    final db = await AppDatabase.database;

    // Check what we have cached for this interval
    final latestCached = await _getLatestTimestamp(db, ticker);
    final now = DateTime.now();

    if (latestCached == null) {
      // No cached data - fetch full history
      // ignore: avoid_print
      print('MarketDataService: No cache for $ticker, fetching full history...');
      await _ingestFull(ticker, days: days);
    } else {
      // Check if we need to update (more than 1 minute old for 1m data)
      final minutesSinceUpdate = now.difference(latestCached).inMinutes;
      if (minutesSinceUpdate >= 1) {
        // ignore: avoid_print
        print('MarketDataService: Delta fetch for $ticker (since $latestCached)...');
        await _ingestDelta(ticker, since: latestCached);
      } else {
        // ignore: avoid_print
        print('MarketDataService: Cache fresh for $ticker ($minutesSinceUpdate min old)');
      }
    }

    // Return cached data
    final cached = await _getCachedData(db, ticker, days: days);
    // ignore: avoid_print
    print('MarketDataService: Returning ${cached.length} cached ticks for $ticker');
    return cached;
  }

  /// Ingest full historical data for a ticker.
  Future<int> _ingestFull(String ticker, {int days = 7}) async {
    if (kIsWeb) return 0;

    final bars = await _yahooRepo.getHistoricalData(ticker, days: days);
    if (bars.isEmpty) return 0;

    final db = await AppDatabase.database;
    final count = await _insertBars(db, bars);
    // ignore: avoid_print
    print('MarketDataService: Full fetch - cached $count bars for $ticker');
    return count;
  }

  /// Ingest delta (new bars since timestamp) for a ticker.
  Future<int> _ingestDelta(String ticker, {required DateTime since}) async {
    if (kIsWeb) return 0;

    // Add 1 second to avoid re-fetching the last bar
    final sinceAfter = since.add(const Duration(seconds: 1));
    final bars = await _yahooRepo.getHistoricalData(ticker, since: sinceAfter);

    if (bars.isEmpty) {
      // ignore: avoid_print
      print('MarketDataService: Delta fetch - no new bars');
      return 0;
    }

    final db = await AppDatabase.database;
    final count = await _insertBars(db, bars);
    // ignore: avoid_print
    print('MarketDataService: Delta fetch - cached $count new bars for $ticker');
    return count;
  }

  /// Insert bars into database.
  Future<int> _insertBars(Database db, List<MarketData> bars) async {
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
    }
    await batch.commit(noResult: true);
    return bars.length;
  }

  /// Ingest historical data for a ticker (legacy, calls full).
  Future<int> ingestHistorical(String ticker, {int days = 7}) async {
    return _ingestFull(ticker, days: days);
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
