/// Auto-trading service that executes trades based on alpha signals.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/models/alpha_signal.dart';
import '../data/models/trade.dart';
import '../data/repositories/market_data_repository.dart';
import '../data/repositories/trading_repository.dart';
import 'alpaca/alpaca_client.dart';
import 'auto_trading_config.dart';

/// Trade decision made by the auto-trading service.
class TradeDecision {
  const TradeDecision({
    required this.ticker,
    required this.action,
    required this.shares,
    required this.signal,
    required this.reason,
  });

  final String ticker;
  final TradeAction action;
  final int shares;
  final AlphaSignal signal;
  final String reason;
}

/// Action to take for a trade.
enum TradeAction { buy, sell, hold }

/// Service that automatically trades based on alpha signals.
class AutoTradingService {
  AutoTradingService({
    required this.tradingRepo,
    required this.marketDataRepo,
    required this.alpacaClient,
  });

  final TradingRepository tradingRepo;
  final MarketDataRepository marketDataRepo;
  final AlpacaClient alpacaClient;

  Timer? _timer;
  AutoTradingConfig _config = AutoTradingConfig.defaultConfig;
  final List<TradeDecision> _recentDecisions = [];

  /// Recent trade decisions for logging/display.
  List<TradeDecision> get recentDecisions => List.unmodifiable(_recentDecisions);

  /// Current configuration.
  AutoTradingConfig get config => _config;

  /// Start the auto-trading service.
  Future<void> start() async {
    _config = await AutoTradingConfig.load();

    if (!_config.enabled) {
      debugPrint('AutoTradingService: Disabled, not starting');
      return;
    }

    debugPrint('AutoTradingService: Starting with config:');
    debugPrint('  Buy threshold: ${_config.buyThreshold}');
    debugPrint('  Sell threshold: ${_config.sellThreshold}');
    debugPrint('  Tickers: ${_config.tickers.join(", ")}');

    // Run immediately, then every 5 minutes
    await _evaluateAndTrade();
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _evaluateAndTrade());
  }

  /// Stop the auto-trading service.
  void stop() {
    _timer?.cancel();
    _timer = null;
    debugPrint('AutoTradingService: Stopped');
  }

  /// Reload configuration.
  Future<void> reloadConfig() async {
    _config = await AutoTradingConfig.load();

    if (_config.enabled && _timer == null) {
      await start();
    } else if (!_config.enabled && _timer != null) {
      stop();
    }
  }

  /// Evaluate all configured tickers and execute trades if signals are strong.
  Future<void> _evaluateAndTrade() async {
    if (!_config.enabled) return;

    debugPrint('AutoTradingService: Evaluating ${_config.tickers.length} tickers');

    for (final ticker in _config.tickers) {
      try {
        final decision = await evaluate(ticker);
        _recentDecisions.add(decision);

        // Keep only last 20 decisions
        if (_recentDecisions.length > 20) {
          _recentDecisions.removeAt(0);
        }

        if (decision.action != TradeAction.hold) {
          await _executeTrade(decision);
        }
      } catch (e) {
        debugPrint('AutoTradingService: Error evaluating $ticker: $e');
      }
    }
  }

  /// Evaluate a single ticker and return a trade decision.
  Future<TradeDecision> evaluate(String ticker) async {
    // Get signals for the ticker
    final signals = await marketDataRepo.getSignals(ticker);
    if (signals.isEmpty) {
      return TradeDecision(
        ticker: ticker,
        action: TradeAction.hold,
        shares: 0,
        signal: AlphaSignal(
          alphaName: 'none',
          ticker: ticker,
          score: 0,
          timestamp: DateTime.now(),
        ),
        reason: 'No signals available',
      );
    }

    // Find the strongest signal
    final strongestSignal = signals.reduce((a, b) => a.score.abs() > b.score.abs() ? a : b);

    // Get current position
    final position = await tradingRepo.getPosition(ticker);
    final currentShares = position?.shares ?? 0;

    // Evaluate BUY signal
    if (strongestSignal.score > _config.buyThreshold) {
      // Calculate shares to buy
      final quote = await marketDataRepo.getLatestQuote(ticker);
      if (quote == null) {
        return TradeDecision(
          ticker: ticker,
          action: TradeAction.hold,
          shares: 0,
          signal: strongestSignal,
          reason: 'Cannot get quote',
        );
      }

      final maxSharesByValue = (_config.maxPositionValue / quote.close).floor();
      final maxSharesByLimit = _config.maxPositionSize - currentShares;
      final sharesToBuy = maxSharesByValue.clamp(0, maxSharesByLimit);

      if (sharesToBuy <= 0) {
        return TradeDecision(
          ticker: ticker,
          action: TradeAction.hold,
          shares: 0,
          signal: strongestSignal,
          reason: 'Position limit reached',
        );
      }

      return TradeDecision(
        ticker: ticker,
        action: TradeAction.buy,
        shares: sharesToBuy,
        signal: strongestSignal,
        reason: 'Strong buy signal (${strongestSignal.alphaName}: ${strongestSignal.score.toStringAsFixed(2)})',
      );
    }

    // Evaluate SELL signal
    if (strongestSignal.score < _config.sellThreshold) {
      if (currentShares <= 0) {
        return TradeDecision(
          ticker: ticker,
          action: TradeAction.hold,
          shares: 0,
          signal: strongestSignal,
          reason: 'No position to sell',
        );
      }

      // Sell entire position on strong sell signal
      return TradeDecision(
        ticker: ticker,
        action: TradeAction.sell,
        shares: currentShares,
        signal: strongestSignal,
        reason: 'Strong sell signal (${strongestSignal.alphaName}: ${strongestSignal.score.toStringAsFixed(2)})',
      );
    }

    // HOLD
    return TradeDecision(
      ticker: ticker,
      action: TradeAction.hold,
      shares: 0,
      signal: strongestSignal,
      reason: 'Signal not strong enough (${strongestSignal.score.toStringAsFixed(2)})',
    );
  }

  /// Execute a trade decision.
  Future<Trade?> _executeTrade(TradeDecision decision) async {
    if (decision.action == TradeAction.hold || decision.shares <= 0) {
      return null;
    }

    debugPrint('AutoTradingService: Executing ${decision.action.name} ${decision.shares} ${decision.ticker}');
    debugPrint('  Reason: ${decision.reason}');

    try {
      // Submit order to Alpaca
      final order = await alpacaClient.submitOrder(
        symbol: decision.ticker,
        qty: decision.shares,
        side: decision.action == TradeAction.buy ? 'buy' : 'sell',
      );

      if (order == null) {
        debugPrint('AutoTradingService: Order submission failed');
        return null;
      }

      // Create trade record
      final trade = Trade(
        id: order.id,
        ticker: decision.ticker,
        type: decision.action == TradeAction.buy ? TradeType.buy : TradeType.sell,
        shares: decision.shares,
        price: order.filledAvgPrice ?? 0,
        timestamp: DateTime.now(),
        signal: decision.signal.alphaName,
        pnl: null,
      );

      debugPrint('AutoTradingService: Trade executed - ${trade.type.name} ${trade.shares} ${trade.ticker}');
      return trade;
    } catch (e) {
      debugPrint('AutoTradingService: Trade execution error: $e');
      return null;
    }
  }
}
