/// Position data model.
library;

/// Represents a stock position in the portfolio.
class Position {
  const Position({
    required this.ticker,
    required this.shares,
    required this.avgCost,
    required this.currentPrice,
    required this.lastUpdated,
  });

  /// Stock ticker symbol.
  final String ticker;

  /// Number of shares held.
  final int shares;

  /// Average cost per share.
  final double avgCost;

  /// Current price per share.
  final double currentPrice;

  /// Last time position was updated.
  final DateTime lastUpdated;

  /// Total value of the position.
  double get totalValue => shares * currentPrice;

  /// Total cost of the position.
  double get totalCost => shares * avgCost;

  /// Profit/loss in dollars.
  double get pnl => totalValue - totalCost;

  /// Profit/loss as a percentage.
  double get pnlPercent => totalCost > 0 ? (pnl / totalCost) * 100 : 0;

  /// Whether the position is profitable.
  bool get isProfitable => pnl >= 0;

  /// Create a copy with updated fields.
  Position copyWith({
    String? ticker,
    int? shares,
    double? avgCost,
    double? currentPrice,
    DateTime? lastUpdated,
  }) {
    return Position(
      ticker: ticker ?? this.ticker,
      shares: shares ?? this.shares,
      avgCost: avgCost ?? this.avgCost,
      currentPrice: currentPrice ?? this.currentPrice,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// Convert to map for database storage.
  Map<String, Object?> toMap() {
    return {
      'ticker': ticker,
      'shares': shares,
      'avg_cost': avgCost,
      'current_price': currentPrice,
      'last_updated': lastUpdated.millisecondsSinceEpoch,
    };
  }

  /// Create from database map.
  factory Position.fromMap(Map<String, Object?> map) {
    return Position(
      ticker: map['ticker'] as String,
      shares: map['shares'] as int,
      avgCost: map['avg_cost'] as double,
      currentPrice: map['current_price'] as double,
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(map['last_updated'] as int),
    );
  }
}
