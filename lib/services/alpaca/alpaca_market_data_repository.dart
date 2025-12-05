/// Alpaca market data repository implementation.
library;

import '../../data/models/alpha_signal.dart';
import '../../data/models/market_data.dart';
import '../../data/repositories/market_data_repository.dart';
import 'alpaca_client.dart';
import 'alpaca_config.dart';

/// Market data repository backed by Alpaca API.
class AlpacaMarketDataRepository implements MarketDataRepository {
  AlpacaMarketDataRepository(this._client);

  final AlpacaClient _client;

  /// Create repository from config file.
  static Future<AlpacaMarketDataRepository?> create() async {
    final config = await AlpacaConfig.load();
    if (config == null) return null;
    return AlpacaMarketDataRepository(AlpacaClient(config));
  }

  @override
  Future<MarketData?> getLatestQuote(String ticker) async {
    final trade = await _client.getLatestTrade(ticker);
    if (trade == null) return null;

    return MarketData(
      ticker: ticker,
      timestamp: trade.timestamp,
      open: trade.price,
      high: trade.price,
      low: trade.price,
      close: trade.price,
      volume: trade.size,
    );
  }

  @override
  Future<List<MarketData>> getHistoricalData(String ticker, {int days = 100}) async {
    final bars = await _client.getBars(ticker, days: days);

    return bars.map((bar) => MarketData(
      ticker: ticker,
      timestamp: bar.timestamp,
      open: bar.open,
      high: bar.high,
      low: bar.low,
      close: bar.close,
      volume: bar.volume,
    )).toList();
  }

  @override
  Future<void> refreshData(String ticker) async {
    // Alpaca data is always fresh, no caching needed
  }

  @override
  Future<List<AlphaSignal>> getSignals(String ticker) async {
    // Generate signals based on recent price action
    final bars = await _client.getBars(ticker, days: 20);
    if (bars.length < 20) return [];

    final signals = <AlphaSignal>[];
    final now = DateTime.now();

    // Simple momentum signal (20-day)
    final firstClose = bars.first.close;
    final lastClose = bars.last.close;
    final momentum = (lastClose - firstClose) / firstClose;

    signals.add(AlphaSignal(
      alphaName: 'momentum_20',
      ticker: ticker,
      score: momentum.clamp(-1.0, 1.0),
      timestamp: now,
    ));

    // Simple RSI-like signal
    var gains = 0.0;
    var losses = 0.0;
    for (var i = 1; i < bars.length; i++) {
      final change = bars[i].close - bars[i - 1].close;
      if (change > 0) {
        gains += change;
      } else {
        losses -= change;
      }
    }
    final avgGain = gains / bars.length;
    final avgLoss = losses / bars.length;
    final rs = avgLoss > 0 ? avgGain / avgLoss : 100;
    final rsi = 100 - (100 / (1 + rs));
    final rsiScore = (rsi - 50) / 50; // Normalize to -1 to 1

    signals.add(AlphaSignal(
      alphaName: 'rsi_14',
      ticker: ticker,
      score: rsiScore.clamp(-1.0, 1.0),
      timestamp: now.subtract(const Duration(hours: 1)),
    ));

    return signals;
  }
}
