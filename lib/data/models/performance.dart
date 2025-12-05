/// Performance snapshot data model.
library;

/// Represents a daily performance snapshot.
class PerformanceSnapshot {
  const PerformanceSnapshot({
    required this.date,
    required this.portfolioValue,
    required this.dailyPnl,
    required this.totalReturn,
    this.sharpeRatio,
    this.maxDrawdown,
  });

  /// Snapshot date.
  final DateTime date;

  /// Total portfolio value.
  final double portfolioValue;

  /// Daily profit/loss.
  final double dailyPnl;

  /// Total return percentage.
  final double totalReturn;

  /// Sharpe ratio (optional).
  final double? sharpeRatio;

  /// Maximum drawdown percentage (optional).
  final double? maxDrawdown;

  /// Whether the day was profitable.
  bool get isProfitable => dailyPnl >= 0;

  /// Convert to map for database storage.
  Map<String, Object?> toMap() {
    return {
      'date': date.millisecondsSinceEpoch,
      'portfolio_value': portfolioValue,
      'daily_pnl': dailyPnl,
      'total_return': totalReturn,
      'sharpe_ratio': sharpeRatio,
      'max_drawdown': maxDrawdown,
    };
  }

  /// Create from database map.
  factory PerformanceSnapshot.fromMap(Map<String, Object?> map) {
    return PerformanceSnapshot(
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      portfolioValue: map['portfolio_value'] as double,
      dailyPnl: map['daily_pnl'] as double,
      totalReturn: map['total_return'] as double,
      sharpeRatio: map['sharpe_ratio'] as double?,
      maxDrawdown: map['max_drawdown'] as double?,
    );
  }
}
