/// Trade data model.
library;

/// Trade type enum.
enum TradeType { buy, sell }

/// Represents a completed trade.
class Trade {
  const Trade({
    required this.id,
    required this.ticker,
    required this.type,
    required this.shares,
    required this.price,
    required this.timestamp,
    required this.signal,
    this.pnl,
  });

  /// Unique trade identifier.
  final String id;

  /// Stock ticker symbol.
  final String ticker;

  /// Trade type (BUY or SELL).
  final TradeType type;

  /// Number of shares traded.
  final int shares;

  /// Price per share at execution.
  final double price;

  /// Trade execution timestamp.
  final DateTime timestamp;

  /// Signal that triggered the trade (e.g., "momentum_20").
  final String signal;

  /// Realized P&L (only for SELL trades).
  final double? pnl;

  /// Total trade value.
  double get totalValue => shares * price;

  /// Convert to map for database storage.
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'ticker': ticker,
      'type': type == TradeType.buy ? 'BUY' : 'SELL',
      'shares': shares,
      'price': price,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'signal': signal,
      'pnl': pnl,
    };
  }

  /// Create from database map.
  factory Trade.fromMap(Map<String, Object?> map) {
    return Trade(
      id: map['id'] as String,
      ticker: map['ticker'] as String,
      type: (map['type'] as String) == 'BUY' ? TradeType.buy : TradeType.sell,
      shares: map['shares'] as int,
      price: map['price'] as double,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      signal: map['signal'] as String,
      pnl: map['pnl'] as double?,
    );
  }
}
