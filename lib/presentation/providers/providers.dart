/// Riverpod providers for the app.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/position.dart';
import '../../data/models/trade.dart';
import '../../data/models/alpha_signal.dart';
import '../../data/models/market_data.dart';
import '../../data/models/performance.dart';
import '../../data/models/account_transaction.dart';
import '../../data/repositories/trading_repository.dart';
import '../../data/repositories/market_data_repository.dart';
import '../../data/repositories/performance_repository.dart';
import '../../data/repositories/account_repository.dart';
import '../../services/alpaca/alpaca_config.dart';
import '../../services/alpaca/alpaca_client.dart';
import '../../services/alpaca/alpaca_trading_repository.dart';
import '../../services/alpaca/alpaca_market_data_repository.dart';
import '../../services/yahoo/yahoo_finance_repository.dart';

// ============================================================================
// Alpaca Config Provider
// ============================================================================

/// Alpaca configuration provider (async).
final alpacaConfigProvider = FutureProvider<AlpacaConfig?>((ref) async {
  return AlpacaConfig.load();
});

/// Alpaca client provider.
final alpacaClientProvider = Provider<AlpacaClient?>((ref) {
  final configAsync = ref.watch(alpacaConfigProvider);
  return configAsync.valueOrNull != null
      ? AlpacaClient(configAsync.valueOrNull!)
      : null;
});

/// Alpaca account provider.
final alpacaAccountProvider = FutureProvider<AlpacaAccount?>((ref) async {
  final client = ref.watch(alpacaClientProvider);
  if (client == null) return null;
  return client.getAccount();
});

// ============================================================================
// Repository Providers
// ============================================================================

/// Trading repository provider (uses Alpaca if available, else SQLite).
final tradingRepositoryProvider = Provider<TradingRepository>((ref) {
  final client = ref.watch(alpacaClientProvider);
  if (client != null) {
    return AlpacaTradingRepository(client);
  }
  return SqliteTradingRepository();
});

/// Market data repository provider.
/// Priority: Alpaca (if configured) > Yahoo Finance (default, free).
final marketDataRepositoryProvider = Provider<MarketDataRepository>((ref) {
  final client = ref.watch(alpacaClientProvider);
  if (client != null) {
    return AlpacaMarketDataRepository(client);
  }
  // Use Yahoo Finance as default - no API key required
  return YahooFinanceRepository();
});

/// Performance repository provider (using mock for now).
final performanceRepositoryProvider = Provider<PerformanceRepository>((ref) {
  return MockPerformanceRepository();
});

/// Account repository provider.
final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository();
});

/// Net capital (total deposits - withdrawals).
final netCapitalProvider = FutureProvider<double>((ref) async {
  final repo = ref.watch(accountRepositoryProvider);
  return repo.getNetCapital();
});

/// Account balance: deposits - withdrawals + realized P&L.
/// This is the available cash for trading.
final accountBalanceProvider = FutureProvider<double>((ref) async {
  final repo = ref.watch(accountRepositoryProvider);
  return repo.getAccountBalance();
});

/// Account transactions list.
final accountTransactionsProvider = FutureProvider<List<AccountTransaction>>((ref) async {
  final repo = ref.watch(accountRepositoryProvider);
  return repo.getTransactions();
});

// ============================================================================
// Portfolio State
// ============================================================================

/// Portfolio state containing positions and total value.
class PortfolioState {
  const PortfolioState({
    required this.positions,
    required this.totalValue,
    required this.dailyPnl,
    required this.isLoading,
    this.error,
  });

  final List<Position> positions;
  final double totalValue;
  final double dailyPnl;
  final bool isLoading;
  final String? error;

  PortfolioState copyWith({
    List<Position>? positions,
    double? totalValue,
    double? dailyPnl,
    bool? isLoading,
    String? error,
  }) {
    return PortfolioState(
      positions: positions ?? this.positions,
      totalValue: totalValue ?? this.totalValue,
      dailyPnl: dailyPnl ?? this.dailyPnl,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  static const initial = PortfolioState(
    positions: [],
    totalValue: 0,
    dailyPnl: 0,
    isLoading: true,
  );
}

/// Portfolio state notifier.
class PortfolioNotifier extends StateNotifier<PortfolioState> {
  PortfolioNotifier(this._tradingRepo, this._marketDataRepo)
      : super(PortfolioState.initial) {
    loadPositions();
  }

  final TradingRepository _tradingRepo;
  final MarketDataRepository _marketDataRepo;

  Future<void> loadPositions() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true);

    try {
      final positions = await _tradingRepo.getAllPositions();
      if (!mounted) return;

      // Update current prices if using SQLite (Alpaca positions already have current price)
      final updatedPositions = <Position>[];
      for (final position in positions) {
        if (!mounted) return;
        if (position.currentPrice == 0) {
          final quote = await _marketDataRepo.getLatestQuote(position.ticker);
          if (quote != null) {
            updatedPositions.add(position.copyWith(
              currentPrice: quote.close,
              lastUpdated: DateTime.now(),
            ));
          } else {
            updatedPositions.add(position);
          }
        } else {
          updatedPositions.add(position);
        }
      }

      if (!mounted) return;
      final totalValue = updatedPositions.fold<double>(
        0,
        (sum, p) => sum + p.totalValue,
      );
      final dailyPnl = updatedPositions.fold<double>(
        0,
        (sum, p) => sum + p.pnl,
      );

      state = state.copyWith(
        positions: updatedPositions,
        totalValue: totalValue,
        dailyPnl: dailyPnl,
        isLoading: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh() => loadPositions();
}

/// Portfolio provider.
final portfolioProvider =
    StateNotifierProvider<PortfolioNotifier, PortfolioState>((ref) {
  final tradingRepo = ref.watch(tradingRepositoryProvider);
  final marketDataRepo = ref.watch(marketDataRepositoryProvider);
  return PortfolioNotifier(tradingRepo, marketDataRepo);
});

// ============================================================================
// Trades State
// ============================================================================

/// Recent trades provider.
final recentTradesProvider = FutureProvider<List<Trade>>((ref) async {
  final repo = ref.watch(tradingRepositoryProvider);
  return repo.getRecentTrades(10);
});

/// All trades provider.
final allTradesProvider = FutureProvider<List<Trade>>((ref) async {
  final repo = ref.watch(tradingRepositoryProvider);
  return repo.getAllTrades();
});

// ============================================================================
// Signals State
// ============================================================================

/// Signals for a ticker provider.
final signalsProvider =
    FutureProvider.family<List<AlphaSignal>, String>((ref, ticker) async {
  final repo = ref.watch(marketDataRepositoryProvider);
  return repo.getSignals(ticker);
});

/// All recent signals provider (for all tickers in portfolio).
final allSignalsProvider = FutureProvider<List<AlphaSignal>>((ref) async {
  final portfolioState = ref.watch(portfolioProvider);
  final marketDataRepo = ref.watch(marketDataRepositoryProvider);

  final allSignals = <AlphaSignal>[];
  for (final position in portfolioState.positions) {
    final signals = await marketDataRepo.getSignals(position.ticker);
    allSignals.addAll(signals);
  }

  // Sort by timestamp descending
  allSignals.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return allSignals.take(10).toList();
});

// ============================================================================
// Performance State
// ============================================================================

/// Performance snapshots provider.
final performanceSnapshotsProvider =
    FutureProvider<List<PerformanceSnapshot>>((ref) async {
  final repo = ref.watch(performanceRepositoryProvider);
  return repo.getAllSnapshots();
});

/// Performance metrics provider.
final performanceMetricsProvider =
    FutureProvider<Map<String, double>>((ref) async {
  final repo = ref.watch(performanceRepositoryProvider);
  return repo.calculateMetrics();
});

// ============================================================================
// Market Data State
// ============================================================================

/// Latest quote for a ticker.
final quoteProvider =
    FutureProvider.family<MarketData?, String>((ref, ticker) async {
  final repo = ref.watch(marketDataRepositoryProvider);
  return repo.getLatestQuote(ticker);
});

/// Historical data for a ticker.
final historicalDataProvider =
    FutureProvider.family<List<MarketData>, String>((ref, ticker) async {
  final repo = ref.watch(marketDataRepositoryProvider);
  return repo.getHistoricalData(ticker, days: 30);
});

// ============================================================================
// Trading Providers (for buy/sell functionality)
// ============================================================================

/// Trading repository provider (nullable, returns null if Alpaca not configured).
/// Used by buy/sell buttons to check if trading is available.
final tradingRepoProvider = Provider<TradingRepository?>((ref) {
  final configAsync = ref.watch(alpacaConfigProvider);
  if (configAsync.valueOrNull == null) {
    return null;
  }
  return ref.watch(tradingRepositoryProvider);
});

/// Positions provider - fetches all positions from trading repository.
final positionsProvider = FutureProvider<List<Position>>((ref) async {
  final repo = ref.watch(tradingRepositoryProvider);
  return repo.getAllPositions();
});

