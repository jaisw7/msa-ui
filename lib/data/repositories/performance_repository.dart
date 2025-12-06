/// Performance repository.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../datasources/local/database.dart';
import '../models/performance.dart';

/// Repository interface for performance data.
abstract class PerformanceRepository {
  /// Get all performance snapshots.
  Future<List<PerformanceSnapshot>> getAllSnapshots();

  /// Get snapshots for a date range.
  Future<List<PerformanceSnapshot>> getSnapshotsInRange(DateTime start, DateTime end);

  /// Save a performance snapshot.
  Future<void> saveSnapshot(PerformanceSnapshot snapshot);

  /// Get the latest snapshot.
  Future<PerformanceSnapshot?> getLatestSnapshot();

  /// Calculate current metrics.
  Future<Map<String, double>> calculateMetrics();
}

/// SQLite implementation of PerformanceRepository.
/// Falls back to live calculation from trades/positions when no snapshots exist.
class SqlitePerformanceRepository implements PerformanceRepository {
  @override
  Future<List<PerformanceSnapshot>> getAllSnapshots() async {
    final db = await AppDatabase.database;
    final maps = await db.query('performance_snapshots', orderBy: 'date ASC');

    // If we have stored snapshots, return them
    if (maps.isNotEmpty) {
      return maps.map((m) => PerformanceSnapshot.fromMap(m)).toList();
    }

    // Otherwise, generate synthetic snapshots from trade history
    return _generateSnapshotsFromTrades();
  }

  /// Generate synthetic performance snapshots from trade history.
  Future<List<PerformanceSnapshot>> _generateSnapshotsFromTrades() async {
    final db = await AppDatabase.database;

    // Get all trades ordered by date
    final trades = await db.query('trades', orderBy: 'timestamp ASC');
    if (trades.isEmpty) {
      debugPrint('PerformanceRepo: No trades found, returning empty snapshots');
      return [];
    }

    // Get initial capital (sum of deposits - withdrawals at trade start)
    final capitalResult = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN type = 'DEPOSIT' THEN amount ELSE 0 END), 0) -
        COALESCE(SUM(CASE WHEN type = 'WITHDRAWAL' THEN amount ELSE 0 END), 0) as net
      FROM account_transactions
    ''');
    double initialCapital = (capitalResult.first['net'] as num?)?.toDouble() ?? 100000.0;
    if (initialCapital <= 0) initialCapital = 100000.0; // Default if no deposits

    // Build daily P&L from trades
    final dailyPnl = <DateTime, double>{};

    for (final trade in trades) {
      final timestamp = DateTime.fromMillisecondsSinceEpoch(trade['timestamp'] as int);
      final date = DateTime(timestamp.year, timestamp.month, timestamp.day);
      final pnl = (trade['pnl'] as num?)?.toDouble() ?? 0.0;

      dailyPnl[date] = (dailyPnl[date] ?? 0.0) + pnl;
    }

    if (dailyPnl.isEmpty) {
      debugPrint('PerformanceRepo: No daily P&L data from trades');
      return [];
    }

    // Sort dates and generate snapshots
    final sortedDates = dailyPnl.keys.toList()..sort();
    final snapshots = <PerformanceSnapshot>[];
    double cumulativePnl = 0.0;
    double peakValue = initialCapital;
    final dailyReturns = <double>[];

    for (final date in sortedDates) {
      final dayPnl = dailyPnl[date]!;
      cumulativePnl += dayPnl;
      final portfolioValue = initialCapital + cumulativePnl;
      final totalReturn = (portfolioValue - initialCapital) / initialCapital * 100;

      // Track peak for drawdown
      if (portfolioValue > peakValue) {
        peakValue = portfolioValue;
      }
      final drawdown = peakValue > 0 ? (portfolioValue - peakValue) / peakValue * 100 : 0.0;

      // Calculate daily return
      final prevValue = snapshots.isNotEmpty ? snapshots.last.portfolioValue : initialCapital;
      if (prevValue > 0) {
        dailyReturns.add((portfolioValue - prevValue) / prevValue);
      }

      // Calculate Sharpe ratio (annualized)
      double? sharpeRatio;
      if (dailyReturns.length >= 5) {
        final avgReturn = dailyReturns.reduce((a, b) => a + b) / dailyReturns.length;
        final variance = dailyReturns.map((r) => math.pow(r - avgReturn, 2)).reduce((a, b) => a + b) / dailyReturns.length;
        final stdDev = math.sqrt(variance);
        if (stdDev > 0) {
          sharpeRatio = (avgReturn / stdDev) * math.sqrt(252); // Annualized
        }
      }

      snapshots.add(PerformanceSnapshot(
        date: date,
        portfolioValue: portfolioValue,
        dailyPnl: dayPnl,
        totalReturn: totalReturn,
        sharpeRatio: sharpeRatio,
        maxDrawdown: drawdown,
      ));
    }

    debugPrint('PerformanceRepo: Generated ${snapshots.length} synthetic snapshots from trades');
    return snapshots;
  }

  @override
  Future<List<PerformanceSnapshot>> getSnapshotsInRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await AppDatabase.database;
    final maps = await db.query(
      'performance_snapshots',
      where: 'date >= ? AND date <= ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'date ASC',
    );

    if (maps.isNotEmpty) {
      return maps.map((m) => PerformanceSnapshot.fromMap(m)).toList();
    }

    // Fall back to synthetic snapshots filtered by range
    final allSnapshots = await _generateSnapshotsFromTrades();
    return allSnapshots.where((s) =>
      s.date.isAfter(start.subtract(const Duration(days: 1))) &&
      s.date.isBefore(end.add(const Duration(days: 1)))
    ).toList();
  }

  @override
  Future<void> saveSnapshot(PerformanceSnapshot snapshot) async {
    final db = await AppDatabase.database;
    await db.insert(
      'performance_snapshots',
      snapshot.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<PerformanceSnapshot?> getLatestSnapshot() async {
    final db = await AppDatabase.database;
    final maps = await db.query(
      'performance_snapshots',
      orderBy: 'date DESC',
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return PerformanceSnapshot.fromMap(maps.first);
    }

    // Fall back to latest synthetic snapshot
    final synthetics = await _generateSnapshotsFromTrades();
    return synthetics.isNotEmpty ? synthetics.last : null;
  }

  @override
  Future<Map<String, double>> calculateMetrics() async {
    final db = await AppDatabase.database;

    // Get current positions value
    final positionsResult = await db.rawQuery('''
      SELECT COALESCE(SUM(shares * current_price), 0) as total_value,
             COALESCE(SUM(shares * avg_cost), 0) as total_cost
      FROM positions
      WHERE shares > 0
    ''');

    final positionsValue = (positionsResult.first['total_value'] as num?)?.toDouble() ?? 0.0;
    final positionsCost = (positionsResult.first['total_cost'] as num?)?.toDouble() ?? 0.0;

    // Get net capital and realized P&L
    final capitalResult = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN type = 'DEPOSIT' THEN amount ELSE 0 END), 0) -
        COALESCE(SUM(CASE WHEN type = 'WITHDRAWAL' THEN amount ELSE 0 END), 0) as net_capital
      FROM account_transactions
    ''');
    double netCapital = (capitalResult.first['net_capital'] as num?)?.toDouble() ?? 0.0;

    final pnlResult = await db.rawQuery('''
      SELECT COALESCE(SUM(pnl), 0) as realized_pnl
      FROM trades
      WHERE pnl IS NOT NULL
    ''');
    final realizedPnl = (pnlResult.first['realized_pnl'] as num?)?.toDouble() ?? 0.0;

    // Unrealized P&L from positions
    final unrealizedPnl = positionsValue - positionsCost;

    // Total P&L
    final totalPnl = realizedPnl + unrealizedPnl;

    // Current portfolio value = cash + positions
    final cashBalance = netCapital + realizedPnl - positionsCost;
    final portfolioValue = cashBalance + positionsValue;

    // Total return %
    final initialCapital = netCapital > 0 ? netCapital : 100000.0;
    final totalReturn = initialCapital > 0 ? (totalPnl / initialCapital) * 100 : 0.0;

    // Win rate from trades
    final winRateResult = await db.rawQuery('''
      SELECT
        COUNT(*) as total,
        SUM(CASE WHEN pnl > 0 THEN 1 ELSE 0 END) as wins
      FROM trades
      WHERE pnl IS NOT NULL
    ''');
    final totalTrades = (winRateResult.first['total'] as num?)?.toDouble() ?? 0.0;
    final winningTrades = (winRateResult.first['wins'] as num?)?.toDouble() ?? 0.0;
    final winRate = totalTrades > 0 ? (winningTrades / totalTrades) * 100 : 0.0;

    // Get Sharpe and drawdown from latest snapshot (if available)
    final latestSnapshot = await getLatestSnapshot();

    return {
      'totalReturn': totalReturn,
      'sharpeRatio': latestSnapshot?.sharpeRatio ?? 0.0,
      'maxDrawdown': latestSnapshot?.maxDrawdown ?? 0.0,
      'winRate': winRate,
      'portfolioValue': portfolioValue,
      'realizedPnl': realizedPnl,
      'unrealizedPnl': unrealizedPnl,
    };
  }
}

/// Mock implementation for development.
class MockPerformanceRepository implements PerformanceRepository {
  @override
  Future<List<PerformanceSnapshot>> getAllSnapshots() async {
    await Future.delayed(const Duration(milliseconds: 100));

    final now = DateTime.now();
    final snapshots = <PerformanceSnapshot>[];
    var value = 100000.0;

    for (var i = 29; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final dailyChange = (i.hashCode % 500 - 200).toDouble();
      value += dailyChange;

      snapshots.add(PerformanceSnapshot(
        date: date,
        portfolioValue: value,
        dailyPnl: dailyChange,
        totalReturn: (value - 100000) / 100000 * 100,
        sharpeRatio: 1.42,
        maxDrawdown: -3.2,
      ));
    }

    return snapshots;
  }

  @override
  Future<List<PerformanceSnapshot>> getSnapshotsInRange(
    DateTime start,
    DateTime end,
  ) async {
    final all = await getAllSnapshots();
    return all.where((s) =>
      s.date.isAfter(start.subtract(const Duration(days: 1))) &&
      s.date.isBefore(end.add(const Duration(days: 1)))
    ).toList();
  }

  @override
  Future<void> saveSnapshot(PerformanceSnapshot snapshot) async {
    // Mock - no-op
  }

  @override
  Future<PerformanceSnapshot?> getLatestSnapshot() async {
    final all = await getAllSnapshots();
    return all.isNotEmpty ? all.last : null;
  }

  @override
  Future<Map<String, double>> calculateMetrics() async {
    return {
      'totalReturn': 7.0,
      'sharpeRatio': 1.42,
      'maxDrawdown': -3.2,
      'winRate': 58.3,
    };
  }
}
