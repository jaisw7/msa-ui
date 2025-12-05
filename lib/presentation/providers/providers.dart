/// Riverpod providers for the app.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/position.dart';
import '../../data/models/trade.dart';
import '../../data/models/alpha_signal.dart';
import '../../data/models/market_data.dart';
import '../../data/models/performance.dart';
import '../../data/repositories/trading_repository.dart';
import '../../data/repositories/market_data_repository.dart';
import '../../data/repositories/performance_repository.dart';

// ============================================================================
// Repository Providers
// ============================================================================

/// Trading repository provider.
final tradingRepositoryProvider = Provider<TradingRepository>((ref) {
  return SqliteTradingRepository();
});

/// Market data repository provider (using mock for now).
final marketDataRepositoryProvider = Provider<MarketDataRepository>((ref) {
  return MockMarketDataRepository();
});

/// Performance repository provider (using mock for now).
final performanceRepositoryProvider = Provider<PerformanceRepository>((ref) {
  return MockPerformanceRepository();
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
    state = state.copyWith(isLoading: true);

    try {
      final positions = await _tradingRepo.getAllPositions();

      // Update current prices
      final updatedPositions = <Position>[];
      for (final position in positions) {
        final quote = await _marketDataRepo.getLatestQuote(position.ticker);
        if (quote != null) {
          updatedPositions.add(position.copyWith(
            currentPrice: quote.close,
            lastUpdated: DateTime.now(),
          ));
        } else {
          updatedPositions.add(position);
        }
      }

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
