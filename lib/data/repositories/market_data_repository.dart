/// Market data repository.
library;

import '../models/market_data.dart';
import '../models/alpha_signal.dart';

/// Repository interface for market data operations.
abstract class MarketDataRepository {
  /// Get latest market data for a ticker.
  Future<MarketData?> getLatestQuote(String ticker);

  /// Get historical data for a ticker.
  Future<List<MarketData>> getHistoricalData(String ticker, {int days = 100});

  /// Refresh market data from API.
  Future<void> refreshData(String ticker);

  /// Get alpha signals for a ticker.
  Future<List<AlphaSignal>> getSignals(String ticker);
}

/// Mock implementation for development.
class MockMarketDataRepository implements MarketDataRepository {
  // Mock current prices
  static final Map<String, double> _mockPrices = {
    'AAPL': 175.23,
    'MSFT': 380.45,
    'GOOGL': 145.60,
    'NVDA': 502.30,
    'TSLA': 238.50,
  };

  @override
  Future<MarketData?> getLatestQuote(String ticker) async {
    await Future.delayed(const Duration(milliseconds: 100));

    final price = _mockPrices[ticker];
    if (price == null) return null;

    return MarketData(
      ticker: ticker,
      timestamp: DateTime.now(),
      open: price * 0.995,
      high: price * 1.01,
      low: price * 0.99,
      close: price,
      volume: 1000000 + (ticker.hashCode % 500000),
    );
  }

  @override
  Future<List<MarketData>> getHistoricalData(String ticker, {int days = 100}) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final basePrice = _mockPrices[ticker] ?? 100.0;
    final now = DateTime.now();
    final data = <MarketData>[];

    for (var i = days - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      // Simple random walk simulation
      final variation = (i.hashCode % 100 - 50) / 1000;
      final price = basePrice * (1 + variation * (days - i) / days);

      data.add(MarketData(
        ticker: ticker,
        timestamp: date,
        open: price * 0.998,
        high: price * 1.005,
        low: price * 0.995,
        close: price,
        volume: 1000000 + (date.day * 10000),
      ));
    }

    return data;
  }

  @override
  Future<void> refreshData(String ticker) async {
    // Simulate API call
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<List<AlphaSignal>> getSignals(String ticker) async {
    await Future.delayed(const Duration(milliseconds: 150));

    final now = DateTime.now();

    // Generate mock signals based on ticker
    final signals = <AlphaSignal>[];

    // Momentum signal
    final momentumScore = (ticker.hashCode % 200 - 100) / 100;
    signals.add(AlphaSignal(
      alphaName: 'momentum_20',
      ticker: ticker,
      score: momentumScore,
      timestamp: now.subtract(const Duration(hours: 1)),
    ));

    // RSI signal
    final rsiScore = (ticker.hashCode % 150 - 75) / 100;
    signals.add(AlphaSignal(
      alphaName: 'rsi_14',
      ticker: ticker,
      score: rsiScore,
      timestamp: now.subtract(const Duration(hours: 2)),
    ));

    // ML model signal
    final mlScore = (ticker.hashCode % 180 - 90) / 100;
    signals.add(AlphaSignal(
      alphaName: 'ml_xgboost',
      ticker: ticker,
      score: mlScore,
      timestamp: now.subtract(const Duration(hours: 3)),
    ));

    return signals;
  }
}
