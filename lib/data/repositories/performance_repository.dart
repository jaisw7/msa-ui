/// Performance repository.
library;

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
class SqlitePerformanceRepository implements PerformanceRepository {
  @override
  Future<List<PerformanceSnapshot>> getAllSnapshots() async {
    final db = await AppDatabase.database;
    final maps = await db.query('performance_snapshots', orderBy: 'date ASC');
    return maps.map((m) => PerformanceSnapshot.fromMap(m)).toList();
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
    return maps.map((m) => PerformanceSnapshot.fromMap(m)).toList();
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
    if (maps.isEmpty) return null;
    return PerformanceSnapshot.fromMap(maps.first);
  }

  @override
  Future<Map<String, double>> calculateMetrics() async {
    final snapshots = await getAllSnapshots();
    if (snapshots.isEmpty) {
      return {
        'totalReturn': 0.0,
        'sharpeRatio': 0.0,
        'maxDrawdown': 0.0,
        'winRate': 0.0,
      };
    }

    // Calculate total return
    final firstValue = snapshots.first.portfolioValue;
    final lastValue = snapshots.last.portfolioValue;
    final totalReturn = (lastValue - firstValue) / firstValue * 100;

    // Calculate win rate (days with positive P&L)
    final winDays = snapshots.where((s) => s.dailyPnl > 0).length;
    final winRate = snapshots.isNotEmpty ? winDays / snapshots.length * 100 : 0.0;

    // Get latest metrics
    final latest = snapshots.last;

    return {
      'totalReturn': totalReturn,
      'sharpeRatio': latest.sharpeRatio ?? 0.0,
      'maxDrawdown': latest.maxDrawdown ?? 0.0,
      'winRate': winRate,
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
