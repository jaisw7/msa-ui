/// Yahoo Finance market data repository using official package.
library;

import 'package:yahoo_finance_data_reader/yahoo_finance_data_reader.dart';

import '../../data/models/alpha_signal.dart';
import '../../data/models/market_data.dart';
import '../../data/repositories/market_data_repository.dart';

/// Market data repository using Yahoo Finance (no API key required).
class YahooFinanceRepository implements MarketDataRepository {
  final _reader = YahooFinanceDailyReader();

  @override
  Future<MarketData?> getLatestQuote(String ticker) async {
    try {
      final response = await _reader.getDailyDTOs(ticker);

      if (response.candlesData.isEmpty) return null;

      final candle = response.candlesData.last;
      return MarketData(
        ticker: ticker,
        timestamp: candle.date,
        open: candle.open,
        high: candle.high,
        low: candle.low,
        close: candle.close,
        volume: candle.volume.toInt(),
      );
    } catch (e) {
      debugPrint('YahooFinance getLatestQuote error: $e');
      return null;
    }
  }

  @override
  Future<List<MarketData>> getHistoricalData(String ticker, {int days = 100}) async {
    try {
      final response = await _reader.getDailyDTOs(ticker);
      final now = DateTime.now();
      final cutoff = now.subtract(Duration(days: days));

      return response.candlesData
          .where((c) => c.date.isAfter(cutoff))
          .map((candle) => MarketData(
                ticker: ticker,
                timestamp: candle.date,
                open: candle.open,
                high: candle.high,
                low: candle.low,
                close: candle.close,
                volume: candle.volume.toInt(),
              ))
          .toList();
    } catch (e) {
      debugPrint('YahooFinance getHistoricalData error: $e');
      return [];
    }
  }

  @override
  Future<void> refreshData(String ticker) async {
    // Yahoo data is always fresh
  }

  @override
  Future<List<AlphaSignal>> getSignals(String ticker) async {
    // Compute signals from historical data
    final bars = await getHistoricalData(ticker, days: 20);
    if (bars.length < 14) return [];

    final signals = <AlphaSignal>[];
    final now = DateTime.now();

    // Momentum signal (price change over period)
    final firstClose = bars.first.close;
    final lastClose = bars.last.close;
    final momentum = (lastClose - firstClose) / firstClose;

    signals.add(AlphaSignal(
      alphaName: 'momentum_20',
      ticker: ticker,
      score: momentum.clamp(-1.0, 1.0),
      timestamp: now,
    ));

    // RSI-like signal
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
    final rsiScore = (rsi - 50) / 50;

    signals.add(AlphaSignal(
      alphaName: 'rsi_14',
      ticker: ticker,
      score: rsiScore.clamp(-1.0, 1.0),
      timestamp: now.subtract(const Duration(hours: 1)),
    ));

    // Moving average signal
    if (bars.length >= 10) {
      final ma10 = bars.sublist(bars.length - 10).fold<double>(0, (s, b) => s + b.close) / 10;
      final maSignal = (lastClose - ma10) / ma10;

      signals.add(AlphaSignal(
        alphaName: 'ma_crossover',
        ticker: ticker,
        score: maSignal.clamp(-1.0, 1.0),
        timestamp: now.subtract(const Duration(hours: 2)),
      ));
    }

    return signals;
  }
}

void debugPrint(String message) {
  // ignore: avoid_print
  print(message);
}
