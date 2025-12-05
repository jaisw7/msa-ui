/// Alpaca trading repository implementation.
library;

import '../../data/models/position.dart';
import '../../data/models/trade.dart';
import '../../data/repositories/trading_repository.dart';
import 'alpaca_client.dart';
import 'alpaca_config.dart';

/// Trading repository backed by Alpaca API.
class AlpacaTradingRepository implements TradingRepository {
  AlpacaTradingRepository(this._client);

  final AlpacaClient _client;

  /// Create repository from config file.
  static Future<AlpacaTradingRepository?> create() async {
    final config = await AlpacaConfig.load();
    if (config == null) return null;
    return AlpacaTradingRepository(AlpacaClient(config));
  }

  @override
  Future<List<Position>> getAllPositions() async {
    final alpacaPositions = await _client.getPositions();

    return alpacaPositions.map((p) => Position(
      ticker: p.symbol,
      shares: p.qty.toInt(),
      avgCost: p.avgEntryPrice,
      currentPrice: p.currentPrice,
      lastUpdated: DateTime.now(),
    )).toList();
  }

  @override
  Future<Position?> getPosition(String ticker) async {
    final p = await _client.getPosition(ticker);
    if (p == null) return null;

    return Position(
      ticker: p.symbol,
      shares: p.qty.toInt(),
      avgCost: p.avgEntryPrice,
      currentPrice: p.currentPrice,
      lastUpdated: DateTime.now(),
    );
  }

  @override
  Future<void> savePosition(Position position) async {
    // Positions are managed by Alpaca, not saved locally
  }

  @override
  Future<void> updatePosition(Position position) async {
    // Positions are managed by Alpaca, not updated locally
  }

  @override
  Future<void> deletePosition(String ticker) async {
    // Would need to close position via order
  }

  @override
  Future<List<Trade>> getAllTrades() async {
    final orders = await _client.getOrders(status: 'filled', limit: 100);

    return orders.map((o) => Trade(
      id: o.id,
      ticker: o.symbol,
      type: o.side == 'buy' ? TradeType.buy : TradeType.sell,
      shares: o.filledQty?.toInt() ?? o.qty.toInt(),
      price: o.filledAvgPrice ?? 0,
      timestamp: o.createdAt,
      signal: 'alpaca',
      pnl: null, // P&L calculated separately
    )).toList();
  }

  @override
  Future<List<Trade>> getTradesForTicker(String ticker) async {
    final allTrades = await getAllTrades();
    return allTrades.where((t) => t.ticker == ticker).toList();
  }

  @override
  Future<void> saveTrade(Trade trade) async {
    // Submit order to Alpaca
    await _client.submitOrder(
      symbol: trade.ticker,
      qty: trade.shares,
      side: trade.type == TradeType.buy ? 'buy' : 'sell',
    );
  }

  @override
  Future<List<Trade>> getRecentTrades(int limit) async {
    final orders = await _client.getOrders(status: 'filled', limit: limit);

    return orders.map((o) => Trade(
      id: o.id,
      ticker: o.symbol,
      type: o.side == 'buy' ? TradeType.buy : TradeType.sell,
      shares: o.filledQty?.toInt() ?? o.qty.toInt(),
      price: o.filledAvgPrice ?? 0,
      timestamp: o.createdAt,
      signal: 'alpaca',
      pnl: null,
    )).toList();
  }
}
