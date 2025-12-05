/// Yahoo Finance market data repository with interval support.
library;

import 'dart:convert';

import 'package:dio/dio.dart';

import '../../data/models/alpha_signal.dart';
import '../../data/models/market_data.dart';
import '../../data/repositories/market_data_repository.dart';

/// Supported data intervals.
enum DataInterval {
  oneMinute('1m'),
  fiveMinutes('5m'),
  fifteenMinutes('15m'),
  thirtyMinutes('30m'),
  oneHour('1h'),
  oneDay('1d');

  const DataInterval(this.value);
  final String value;

  /// Max days of data available for each interval (Yahoo limits)
  int get maxDays => switch (this) {
    DataInterval.oneMinute => 7,
    DataInterval.fiveMinutes => 60,
    DataInterval.fifteenMinutes => 60,
    DataInterval.thirtyMinutes => 60,
    DataInterval.oneHour => 730,
    DataInterval.oneDay => 365 * 20,
  };
}

/// Market data repository using Yahoo Finance (no API key required).
/// Based on yahoo_finance_data_reader package approach.
class YahooFinanceRepository implements MarketDataRepository {
  YahooFinanceRepository({DataInterval interval = DataInterval.oneMinute})
      : _interval = interval,
        _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'content-type': 'application/json',
            'charset': 'utf-8',
          },
        ));

  final DataInterval _interval;
  final Dio _dio;

  @override
  Future<MarketData?> getLatestQuote(String ticker) async {
    try {
      final data = await getHistoricalData(ticker, days: 1);
      return data.isNotEmpty ? data.last : null;
    } catch (e) {
      // ignore: avoid_print
      print('YahooFinance getLatestQuote error: $e');
      return null;
    }
  }

  @override
  Future<List<MarketData>> getHistoricalData(String ticker, {int days = 100}) async {
    try {
      final effectiveDays = days > _interval.maxDays ? _interval.maxDays : days;

      final now = DateTime.now();
      final start = now.subtract(Duration(days: effectiveDays));

      final period1 = (start.millisecondsSinceEpoch / 1000).floor();
      final period2 = (now.millisecondsSinceEpoch / 1000).floor();

      final tickerUpper = ticker.toUpperCase().trim();
      final url = 'https://query2.finance.yahoo.com/v8/finance/chart/$tickerUpper'
          '?period1=$period1&period2=$period2&interval=${_interval.value}'
          '&includePrePost=false&events=div,splits';

      // ignore: avoid_print
      print('YahooFinance: Fetching $tickerUpper (${_interval.value}, ${effectiveDays}d)');

      final response = await _dio.get(url);

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      // Parse response (same pattern as yahoo_finance_data_reader)
      final json = response.data is String
          ? jsonDecode(response.data as String) as Map<String, dynamic>
          : response.data as Map<String, dynamic>;

      final chart = json['chart'] as Map<String, dynamic>?;
      final results = chart?['result'] as List<dynamic>?;
      final result = results?.firstOrNull as Map<String, dynamic>?;

      if (result == null) {
        // ignore: avoid_print
        print('YahooFinance: No data for $tickerUpper');
        return [];
      }

      final timestamps = (result['timestamp'] as List<dynamic>?)?.cast<int>() ?? [];
      final indicators = result['indicators'] as Map<String, dynamic>?;
      final quote = (indicators?['quote'] as List<dynamic>?)?.firstOrNull as Map<String, dynamic>?;

      if (quote == null || timestamps.isEmpty) {
        return [];
      }

      final opens = (quote['open'] as List<dynamic>?)?.cast<num?>() ?? [];
      final highs = (quote['high'] as List<dynamic>?)?.cast<num?>() ?? [];
      final lows = (quote['low'] as List<dynamic>?)?.cast<num?>() ?? [];
      final closes = (quote['close'] as List<dynamic>?)?.cast<num?>() ?? [];
      final volumes = (quote['volume'] as List<dynamic>?)?.cast<num?>() ?? [];

      final bars = <MarketData>[];
      for (var i = 0; i < timestamps.length; i++) {
        final open = opens.length > i ? opens[i] : null;
        final high = highs.length > i ? highs[i] : null;
        final low = lows.length > i ? lows[i] : null;
        final close = closes.length > i ? closes[i] : null;
        final volume = volumes.length > i ? volumes[i] : null;

        // Skip bars with null values
        if (open == null || high == null || low == null || close == null) continue;

        bars.add(MarketData(
          ticker: tickerUpper,
          timestamp: DateTime.fromMillisecondsSinceEpoch(timestamps[i] * 1000),
          open: open.toDouble(),
          high: high.toDouble(),
          low: low.toDouble(),
          close: close.toDouble(),
          volume: volume?.toInt() ?? 0,
        ));
      }

      // ignore: avoid_print
      print('YahooFinance: Got ${bars.length} bars for $tickerUpper');
      return bars;
    } catch (e) {
      // ignore: avoid_print
      print('YahooFinance getHistoricalData error: $e');
      return [];
    }
  }

  @override
  Future<void> refreshData(String ticker) async {
    // Yahoo data is always fresh
  }

  @override
  Future<List<AlphaSignal>> getSignals(String ticker) async {
    // Compute signals from historical data - use daily for signals
    final dailyRepo = YahooFinanceRepository(interval: DataInterval.oneDay);
    final bars = await dailyRepo.getHistoricalData(ticker, days: 20);
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
