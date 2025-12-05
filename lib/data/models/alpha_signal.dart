/// Alpha signal data model.
library;

/// Signal type enum.
enum SignalType { buy, sell, hold }

/// Represents an alpha signal.
class AlphaSignal {
  const AlphaSignal({
    required this.alphaName,
    required this.ticker,
    required this.score,
    required this.timestamp,
  });

  /// Name of the alpha (e.g., "momentum_20", "rsi_14").
  final String alphaName;

  /// Stock ticker symbol.
  final String ticker;

  /// Signal score from -1 to +1.
  final double score;

  /// Signal generation timestamp.
  final DateTime timestamp;

  /// Derived signal type based on score.
  SignalType get signal {
    if (score > 0.5) return SignalType.buy;
    if (score < -0.5) return SignalType.sell;
    return SignalType.hold;
  }

  /// Human-readable signal label.
  String get signalLabel {
    switch (signal) {
      case SignalType.buy:
        return 'BUY';
      case SignalType.sell:
        return 'SELL';
      case SignalType.hold:
        return 'HOLD';
    }
  }

  /// Signal strength as absolute value.
  double get strength => score.abs();
}
