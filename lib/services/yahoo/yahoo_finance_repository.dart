/// Yahoo Finance market data repository.
library;

import 'package:dio/dio.dart';

import '../../data/models/alpha_signal.dart';
import '../../data/models/market_data.dart';
import '../../data/repositories/market_data_repository.dart';

/// Market data repository using Yahoo Finance (no API key required).
class YahooFinanceRepository implements MarketDataRepository {
  YahooFinanceRepository() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
  }

  late final Dio _dio;

  // Yahoo Finance query API endpoint
  static const _baseUrl = 'https://query1.finance.yahoo.com/v8/finance/chart';

  @override
  Future<MarketData?> getLatestQuote(String ticker) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/$ticker',
        queryParameters: {
          'interval': '1d',
          'range': '1d',
        },
      );

      final data = response.data as Map<String, dynamic>;
      final result = data['chart']?['result']?[0] as Map<String, dynamic>?;
      if (result == null) return null;

      final meta = result['meta'] as Map<String, dynamic>;
      final quote = result['indicators']?['quote']?[0] as Map<String, dynamic>?;

      final price = meta['regularMarketPrice'] as num?;
      if (price == null) return null;

      return MarketData(
        ticker: ticker,
        timestamp: DateTime.now(),
        open: (quote?['open']?.last as num?)?.toDouble() ?? price.toDouble(),
        high: (quote?['high']?.last as num?)?.toDouble() ?? price.toDouble(),
        low: (quote?['low']?.last as num?)?.toDouble() ?? price.toDouble(),
        close: price.toDouble(),
        volume: (quote?['volume']?.last as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<MarketData>> getHistoricalData(String ticker, {int days = 100}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/$ticker',
        queryParameters: {
          'interval': '1d',
          'range': '${days}d',
        },
      );

      final data = response.data as Map<String, dynamic>;
      final result = data['chart']?['result']?[0] as Map<String, dynamic>?;
      if (result == null) return [];

      final timestamps = (result['timestamp'] as List<dynamic>?)?.cast<int>() ?? [];
      final quote = result['indicators']?['quote']?[0] as Map<String, dynamic>?;
      if (quote == null) return [];

      final opens = (quote['open'] as List<dynamic>?)?.cast<num?>() ?? [];
      final highs = (quote['high'] as List<dynamic>?)?.cast<num?>() ?? [];
      final lows = (quote['low'] as List<dynamic>?)?.cast<num?>() ?? [];
      final closes = (quote['close'] as List<dynamic>?)?.cast<num?>() ?? [];
      final volumes = (quote['volume'] as List<dynamic>?)?.cast<num?>() ?? [];

      final bars = <MarketData>[];
      for (var i = 0; i < timestamps.length; i++) {
        final close = closes.length > i ? closes[i]?.toDouble() : null;
        if (close == null) continue;

        bars.add(MarketData(
          ticker: ticker,
          timestamp: DateTime.fromMillisecondsSinceEpoch(timestamps[i] * 1000),
          open: opens.length > i ? opens[i]?.toDouble() ?? close : close,
          high: highs.length > i ? highs[i]?.toDouble() ?? close : close,
          low: lows.length > i ? lows[i]?.toDouble() ?? close : close,
          close: close,
          volume: volumes.length > i ? volumes[i]?.toInt() ?? 0 : 0,
        ));
      }

      return bars;
    } catch (e) {
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
