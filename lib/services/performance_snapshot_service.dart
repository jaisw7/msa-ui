/// Background service for capturing daily performance snapshots.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/models/performance.dart';
import '../data/repositories/performance_repository.dart';
import '../data/repositories/trading_repository.dart';
import '../data/repositories/account_repository.dart';

/// Service that captures daily performance snapshots at midnight.
class PerformanceSnapshotService {
  PerformanceSnapshotService({
    required this.performanceRepo,
    required this.tradingRepo,
    required this.accountRepo,
  });

  final PerformanceRepository performanceRepo;
  final TradingRepository tradingRepo;
  final AccountRepository accountRepo;

  Timer? _timer;
  bool _isRunning = false;
  DateTime? _lastSnapshotDate;

  /// Whether the service is currently running.
  bool get isRunning => _isRunning;

  /// Start the background snapshot service.
  void start() {
    if (_isRunning) return;
    _isRunning = true;

    debugPrint('PerformanceSnapshotService: Starting');

    // Check immediately on start
    _checkAndCapture();

    // Check every 5 minutes if it's time for a snapshot
    _timer = Timer.periodic(const Duration(minutes: 5), (_) {
      _checkAndCapture();
    });
  }

  /// Stop the service.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    debugPrint('PerformanceSnapshotService: Stopped');
  }

  /// Check if it's time to capture a snapshot and do so if needed.
  Future<void> _checkAndCapture() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Only capture during off-hours window (11 PM - 1 AM)
    final hour = now.hour;
    if (hour < 23 && hour > 1) {
      return;
    }

    // Check if we already captured today
    if (_lastSnapshotDate != null && _lastSnapshotDate!.isAtSameMomentAs(today)) {
      return;
    }

    // Check if a snapshot already exists for today in DB
    final existing = await performanceRepo.getLatestSnapshot();
    if (existing != null) {
      final existingDate = DateTime(
        existing.date.year,
        existing.date.month,
        existing.date.day,
      );
      if (existingDate.isAtSameMomentAs(today)) {
        _lastSnapshotDate = today;
        debugPrint('PerformanceSnapshotService: Snapshot already exists for today');
        return;
      }
    }

    // Capture the snapshot
    await captureSnapshot();
    _lastSnapshotDate = today;
  }

  /// Manually capture a performance snapshot for the current moment.
  Future<void> captureSnapshot() async {
    try {
      debugPrint('PerformanceSnapshotService: Capturing snapshot');

      // Get current positions
      final positions = await tradingRepo.getAllPositions();

      // Calculate portfolio value
      double portfolioValue = 0.0;
      double positionsCost = 0.0;
      for (final pos in positions) {
        portfolioValue += pos.totalValue;
        positionsCost += pos.totalCost;
      }

      // Get cash balance
      final cashBalance = await accountRepo.getAccountBalance();
      final totalValue = cashBalance + portfolioValue;

      // Get net capital for returns calculation
      final netCapital = await accountRepo.getNetCapital();
      final initialCapital = netCapital > 0 ? netCapital : 100000.0;

      // Get realized P&L
      final realizedPnl = await accountRepo.getRealizedPnl();

      // Calculate unrealized P&L
      final unrealizedPnl = portfolioValue - positionsCost;

      // Total P&L (today's snapshot daily pnl is approximated)
      final totalPnl = realizedPnl + unrealizedPnl;
      final totalReturn = initialCapital > 0 ? (totalPnl / initialCapital) * 100 : 0.0;

      // Get previous snapshot for daily P&L calculation
      final previousSnapshot = await performanceRepo.getLatestSnapshot();
      double dailyPnl = 0.0;
      double maxDrawdown = 0.0;
      double? sharpeRatio;

      if (previousSnapshot != null) {
        dailyPnl = totalValue - previousSnapshot.portfolioValue;
        maxDrawdown = previousSnapshot.maxDrawdown ?? 0.0;

        // Update max drawdown if current is worse
        final currentDrawdown = _calculateDrawdown(previousSnapshot.portfolioValue, totalValue);
        if (currentDrawdown < maxDrawdown) {
          maxDrawdown = currentDrawdown;
        }

        // Inherit Sharpe ratio (could recalculate but that requires history)
        sharpeRatio = previousSnapshot.sharpeRatio;
      }

      final snapshot = PerformanceSnapshot(
        date: DateTime.now(),
        portfolioValue: totalValue,
        dailyPnl: dailyPnl,
        totalReturn: totalReturn,
        sharpeRatio: sharpeRatio,
        maxDrawdown: maxDrawdown,
      );

      await performanceRepo.saveSnapshot(snapshot);
      debugPrint('PerformanceSnapshotService: Saved snapshot - value: \$${totalValue.toStringAsFixed(2)}, return: ${totalReturn.toStringAsFixed(2)}%');
    } catch (e, stack) {
      debugPrint('PerformanceSnapshotService: Error capturing snapshot: $e');
      debugPrint('$stack');
    }
  }

  double _calculateDrawdown(double previousValue, double currentValue) {
    if (previousValue <= 0) return 0.0;
    if (currentValue >= previousValue) return 0.0;
    return ((currentValue - previousValue) / previousValue) * 100;
  }
}
