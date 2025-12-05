/// Alpaca API client for market data and trading.
library;



import 'package:dio/dio.dart';

import 'alpaca_config.dart';

/// Alpaca API client.
class AlpacaClient {
  AlpacaClient(this._config) {
    _dio = Dio(BaseOptions(
      baseUrl: _config.endpoint,
      headers: {
        'APCA-API-KEY-ID': _config.apiKey,
        'APCA-API-SECRET-KEY': _config.apiSecret,
        'Content-Type': 'application/json',
      },
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
  }

  final AlpacaConfig _config;
  late final Dio _dio;

  /// Get account information.
  Future<AlpacaAccount?> getAccount() async {
    try {
      final response = await _dio.get('/account');
      return AlpacaAccount.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  /// Get all open positions.
  Future<List<AlpacaPosition>> getPositions() async {
    try {
      final response = await _dio.get('/positions');
      final data = response.data as List<dynamic>;
      return data.map((p) => AlpacaPosition.fromJson(p as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get position for a specific symbol.
  Future<AlpacaPosition?> getPosition(String symbol) async {
    try {
      final response = await _dio.get('/positions/$symbol');
      return AlpacaPosition.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  /// Get latest quote for a symbol.
  Future<AlpacaQuote?> getLatestQuote(String symbol) async {
    try {
      // Use market data API
      final dataEndpoint = _config.endpoint.contains('paper')
          ? 'https://data.alpaca.markets/v2'
          : 'https://data.alpaca.markets/v2';

      final dataDio = Dio(BaseOptions(
        baseUrl: dataEndpoint,
        headers: {
          'APCA-API-KEY-ID': _config.apiKey,
          'APCA-API-SECRET-KEY': _config.apiSecret,
        },
      ));

      final response = await dataDio.get('/stocks/$symbol/quotes/latest');
      final quoteData = response.data['quote'] as Map<String, dynamic>;
      return AlpacaQuote.fromJson(symbol, quoteData);
    } catch (e) {
      return null;
    }
  }

  /// Get latest trade for a symbol.
  Future<AlpacaTrade?> getLatestTrade(String symbol) async {
    try {
      final dataEndpoint = 'https://data.alpaca.markets/v2';

      final dataDio = Dio(BaseOptions(
        baseUrl: dataEndpoint,
        headers: {
          'APCA-API-KEY-ID': _config.apiKey,
          'APCA-API-SECRET-KEY': _config.apiSecret,
        },
      ));

      final response = await dataDio.get('/stocks/$symbol/trades/latest');
      final tradeData = response.data['trade'] as Map<String, dynamic>;
      return AlpacaTrade.fromJson(symbol, tradeData);
    } catch (e) {
      return null;
    }
  }

  /// Get historical bars for a symbol.
  Future<List<AlpacaBar>> getBars(String symbol, {int days = 30}) async {
    try {
      final dataEndpoint = 'https://data.alpaca.markets/v2';

      final dataDio = Dio(BaseOptions(
        baseUrl: dataEndpoint,
        headers: {
          'APCA-API-KEY-ID': _config.apiKey,
          'APCA-API-SECRET-KEY': _config.apiSecret,
        },
      ));

      final end = DateTime.now();
      final start = end.subtract(Duration(days: days));

      final response = await dataDio.get('/stocks/$symbol/bars', queryParameters: {
        'start': start.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
        'timeframe': '1Day',
        'limit': days,
      });

      final bars = response.data['bars'] as List<dynamic>? ?? [];
      return bars.map((b) => AlpacaBar.fromJson(symbol, b as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get recent orders.
  Future<List<AlpacaOrder>> getOrders({String status = 'all', int limit = 50}) async {
    try {
      final response = await _dio.get('/orders', queryParameters: {
        'status': status,
        'limit': limit,
      });
      final data = response.data as List<dynamic>;
      return data.map((o) => AlpacaOrder.fromJson(o as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Submit a market order.
  Future<AlpacaOrder?> submitOrder({
    required String symbol,
    required int qty,
    required String side, // 'buy' or 'sell'
  }) async {
    try {
      final response = await _dio.post('/orders', data: {
        'symbol': symbol,
        'qty': qty.toString(),
        'side': side,
        'type': 'market',
        'time_in_force': 'day',
      });
      return AlpacaOrder.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }
}

/// Alpaca account information.
class AlpacaAccount {
  const AlpacaAccount({
    required this.id,
    required this.cash,
    required this.portfolioValue,
    required this.buyingPower,
    required this.equity,
    required this.lastEquity,
    required this.status,
  });

  final String id;
  final double cash;
  final double portfolioValue;
  final double buyingPower;
  final double equity;
  final double lastEquity;
  final String status;

  double get dailyPnl => equity - lastEquity;
  double get dailyPnlPercent => lastEquity > 0 ? (dailyPnl / lastEquity) * 100 : 0;

  factory AlpacaAccount.fromJson(Map<String, dynamic> json) {
    return AlpacaAccount(
      id: json['id'] as String,
      cash: double.parse(json['cash'] as String),
      portfolioValue: double.parse(json['portfolio_value'] as String),
      buyingPower: double.parse(json['buying_power'] as String),
      equity: double.parse(json['equity'] as String),
      lastEquity: double.parse(json['last_equity'] as String),
      status: json['status'] as String,
    );
  }
}

/// Alpaca position.
class AlpacaPosition {
  const AlpacaPosition({
    required this.symbol,
    required this.qty,
    required this.avgEntryPrice,
    required this.currentPrice,
    required this.marketValue,
    required this.unrealizedPl,
    required this.unrealizedPlpc,
  });

  final String symbol;
  final double qty;
  final double avgEntryPrice;
  final double currentPrice;
  final double marketValue;
  final double unrealizedPl;
  final double unrealizedPlpc;

  factory AlpacaPosition.fromJson(Map<String, dynamic> json) {
    return AlpacaPosition(
      symbol: json['symbol'] as String,
      qty: double.parse(json['qty'] as String),
      avgEntryPrice: double.parse(json['avg_entry_price'] as String),
      currentPrice: double.parse(json['current_price'] as String),
      marketValue: double.parse(json['market_value'] as String),
      unrealizedPl: double.parse(json['unrealized_pl'] as String),
      unrealizedPlpc: double.parse(json['unrealized_plpc'] as String),
    );
  }
}

/// Alpaca quote.
class AlpacaQuote {
  const AlpacaQuote({
    required this.symbol,
    required this.askPrice,
    required this.askSize,
    required this.bidPrice,
    required this.bidSize,
    required this.timestamp,
  });

  final String symbol;
  final double askPrice;
  final int askSize;
  final double bidPrice;
  final int bidSize;
  final DateTime timestamp;

  double get midPrice => (askPrice + bidPrice) / 2;

  factory AlpacaQuote.fromJson(String symbol, Map<String, dynamic> json) {
    return AlpacaQuote(
      symbol: symbol,
      askPrice: (json['ap'] as num).toDouble(),
      askSize: json['as'] as int,
      bidPrice: (json['bp'] as num).toDouble(),
      bidSize: json['bs'] as int,
      timestamp: DateTime.parse(json['t'] as String),
    );
  }
}

/// Alpaca trade.
class AlpacaTrade {
  const AlpacaTrade({
    required this.symbol,
    required this.price,
    required this.size,
    required this.timestamp,
  });

  final String symbol;
  final double price;
  final int size;
  final DateTime timestamp;

  factory AlpacaTrade.fromJson(String symbol, Map<String, dynamic> json) {
    return AlpacaTrade(
      symbol: symbol,
      price: (json['p'] as num).toDouble(),
      size: json['s'] as int,
      timestamp: DateTime.parse(json['t'] as String),
    );
  }
}

/// Alpaca bar (OHLCV).
class AlpacaBar {
  const AlpacaBar({
    required this.symbol,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    required this.timestamp,
  });

  final String symbol;
  final double open;
  final double high;
  final double low;
  final double close;
  final int volume;
  final DateTime timestamp;

  factory AlpacaBar.fromJson(String symbol, Map<String, dynamic> json) {
    return AlpacaBar(
      symbol: symbol,
      open: (json['o'] as num).toDouble(),
      high: (json['h'] as num).toDouble(),
      low: (json['l'] as num).toDouble(),
      close: (json['c'] as num).toDouble(),
      volume: json['v'] as int,
      timestamp: DateTime.parse(json['t'] as String),
    );
  }
}

/// Alpaca order.
class AlpacaOrder {
  const AlpacaOrder({
    required this.id,
    required this.symbol,
    required this.qty,
    required this.side,
    required this.type,
    required this.status,
    required this.createdAt,
    this.filledAvgPrice,
    this.filledQty,
  });

  final String id;
  final String symbol;
  final double qty;
  final String side;
  final String type;
  final String status;
  final DateTime createdAt;
  final double? filledAvgPrice;
  final double? filledQty;

  factory AlpacaOrder.fromJson(Map<String, dynamic> json) {
    return AlpacaOrder(
      id: json['id'] as String,
      symbol: json['symbol'] as String,
      qty: double.parse(json['qty'] as String),
      side: json['side'] as String,
      type: json['type'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      filledAvgPrice: json['filled_avg_price'] != null
          ? double.parse(json['filled_avg_price'] as String)
          : null,
      filledQty: json['filled_qty'] != null
          ? double.parse(json['filled_qty'] as String)
          : null,
    );
  }
}
