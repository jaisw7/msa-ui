/// Market data model.
library;

/// Represents OHLCV market data for a ticker.
class MarketData {
  const MarketData({
    required this.ticker,
    required this.timestamp,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  /// Stock ticker symbol.
  final String ticker;

  /// Bar timestamp.
  final DateTime timestamp;

  /// Open price.
  final double open;

  /// High price.
  final double high;

  /// Low price.
  final double low;

  /// Close price.
  final double close;

  /// Trading volume.
  final int volume;

  /// Price change from open to close.
  double get change => close - open;

  /// Price change as percentage.
  double get changePercent => open > 0 ? (change / open) * 100 : 0;

  /// Whether the bar was bullish.
  bool get isBullish => close >= open;

  /// Convert to map for database storage.
  Map<String, Object?> toMap() {
    return {
      'ticker': ticker,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'open': open,
      'high': high,
      'low': low,
      'close': close,
      'volume': volume,
    };
  }

  /// Create from database map.
  factory MarketData.fromMap(Map<String, Object?> map) {
    return MarketData(
      ticker: map['ticker'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      open: map['open'] as double,
      high: map['high'] as double,
      low: map['low'] as double,
      close: map['close'] as double,
      volume: map['volume'] as int,
    );
  }
}
