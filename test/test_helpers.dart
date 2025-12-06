/// Test helpers and fixtures for msa-ui tests.
library;

import 'package:msa_ui/data/models/account_transaction.dart';
import 'package:msa_ui/data/models/alpha_signal.dart';
import 'package:msa_ui/data/models/market_data.dart';
import 'package:msa_ui/data/models/performance.dart';
import 'package:msa_ui/data/models/position.dart';
import 'package:msa_ui/data/models/trade.dart';

/// Sample Position for testing.
Position createSamplePosition({
  String ticker = 'AAPL',
  int shares = 10,
  double avgCost = 150.0,
  double currentPrice = 175.0,
  DateTime? lastUpdated,
}) {
  return Position(
    ticker: ticker,
    shares: shares,
    avgCost: avgCost,
    currentPrice: currentPrice,
    lastUpdated: lastUpdated ?? DateTime(2025, 1, 15, 10, 30),
  );
}

/// Sample Trade for testing.
Trade createSampleTrade({
  String id = 'trade-001',
  String ticker = 'AAPL',
  TradeType type = TradeType.buy,
  int shares = 10,
  double price = 150.0,
  DateTime? timestamp,
  String signal = 'momentum_20',
  double? pnl,
}) {
  return Trade(
    id: id,
    ticker: ticker,
    type: type,
    shares: shares,
    price: price,
    timestamp: timestamp ?? DateTime(2025, 1, 15, 10, 30),
    signal: signal,
    pnl: pnl,
  );
}

/// Sample MarketData for testing.
MarketData createSampleMarketData({
  String ticker = 'AAPL',
  DateTime? timestamp,
  double open = 150.0,
  double high = 155.0,
  double low = 149.0,
  double close = 153.0,
  int volume = 1000000,
}) {
  return MarketData(
    ticker: ticker,
    timestamp: timestamp ?? DateTime(2025, 1, 15, 10, 30),
    open: open,
    high: high,
    low: low,
    close: close,
    volume: volume,
  );
}

/// Sample AlphaSignal for testing.
AlphaSignal createSampleAlphaSignal({
  String alphaName = 'momentum_20',
  String ticker = 'AAPL',
  double score = 0.75,
  DateTime? timestamp,
}) {
  return AlphaSignal(
    alphaName: alphaName,
    ticker: ticker,
    score: score,
    timestamp: timestamp ?? DateTime(2025, 1, 15, 10, 30),
  );
}

/// Sample PerformanceSnapshot for testing.
PerformanceSnapshot createSamplePerformance({
  DateTime? date,
  double portfolioValue = 100000.0,
  double dailyPnl = 500.0,
  double totalReturn = 5.0,
  double? sharpeRatio = 1.5,
  double? maxDrawdown = -2.5,
}) {
  return PerformanceSnapshot(
    date: date ?? DateTime(2025, 1, 15),
    portfolioValue: portfolioValue,
    dailyPnl: dailyPnl,
    totalReturn: totalReturn,
    sharpeRatio: sharpeRatio,
    maxDrawdown: maxDrawdown,
  );
}

/// Sample AccountTransaction for testing.
AccountTransaction createSampleTransaction({
  int? id,
  TransactionType type = TransactionType.deposit,
  double amount = 10000.0,
  DateTime? timestamp,
  String? notes,
}) {
  return AccountTransaction(
    id: id,
    type: type,
    amount: amount,
    timestamp: timestamp ?? DateTime(2025, 1, 15, 10, 30),
    notes: notes,
  );
}
