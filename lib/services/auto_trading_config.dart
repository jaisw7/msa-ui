/// Auto-trading service configuration.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Configuration for automated trading.
class AutoTradingConfig {
  const AutoTradingConfig({
    required this.enabled,
    required this.buyThreshold,
    required this.sellThreshold,
    required this.maxPositionSize,
    required this.maxPositionValue,
    required this.tickers,
  });

  /// Whether auto-trading is enabled.
  final bool enabled;

  /// Alpha signal score threshold for BUY signals (0.0 to 1.0).
  /// Buy when signal score > buyThreshold.
  final double buyThreshold;

  /// Alpha signal score threshold for SELL signals (-1.0 to 0.0).
  /// Sell when signal score < sellThreshold.
  final double sellThreshold;

  /// Maximum shares per position.
  final int maxPositionSize;

  /// Maximum dollar value per position.
  final double maxPositionValue;

  /// List of tickers to trade automatically.
  final List<String> tickers;

  /// Default configuration.
  static const defaultConfig = AutoTradingConfig(
    enabled: false,
    buyThreshold: 0.7,
    sellThreshold: -0.7,
    maxPositionSize: 100,
    maxPositionValue: 10000,
    tickers: ['AAPL', 'MSFT', 'GOOGL'],
  );

  // Storage keys
  static const _storage = FlutterSecureStorage();
  static const _keyEnabled = 'auto_trading_enabled';
  static const _keyBuyThreshold = 'auto_trading_buy_threshold';
  static const _keySellThreshold = 'auto_trading_sell_threshold';
  static const _keyMaxPositionSize = 'auto_trading_max_position_size';
  static const _keyMaxPositionValue = 'auto_trading_max_position_value';
  static const _keyTickers = 'auto_trading_tickers';

  /// Load configuration from secure storage.
  static Future<AutoTradingConfig> load() async {
    try {
      final enabled = await _storage.read(key: _keyEnabled);
      final buyThreshold = await _storage.read(key: _keyBuyThreshold);
      final sellThreshold = await _storage.read(key: _keySellThreshold);
      final maxPositionSize = await _storage.read(key: _keyMaxPositionSize);
      final maxPositionValue = await _storage.read(key: _keyMaxPositionValue);
      final tickers = await _storage.read(key: _keyTickers);

      return AutoTradingConfig(
        enabled: enabled == 'true',
        buyThreshold: double.tryParse(buyThreshold ?? '') ?? defaultConfig.buyThreshold,
        sellThreshold: double.tryParse(sellThreshold ?? '') ?? defaultConfig.sellThreshold,
        maxPositionSize: int.tryParse(maxPositionSize ?? '') ?? defaultConfig.maxPositionSize,
        maxPositionValue: double.tryParse(maxPositionValue ?? '') ?? defaultConfig.maxPositionValue,
        tickers: tickers?.split(',').where((t) => t.isNotEmpty).toList() ?? defaultConfig.tickers,
      );
    } catch (e) {
      return defaultConfig;
    }
  }

  /// Save configuration to secure storage.
  Future<void> save() async {
    await _storage.write(key: _keyEnabled, value: enabled.toString());
    await _storage.write(key: _keyBuyThreshold, value: buyThreshold.toString());
    await _storage.write(key: _keySellThreshold, value: sellThreshold.toString());
    await _storage.write(key: _keyMaxPositionSize, value: maxPositionSize.toString());
    await _storage.write(key: _keyMaxPositionValue, value: maxPositionValue.toString());
    await _storage.write(key: _keyTickers, value: tickers.join(','));
  }

  /// Create a copy with modified fields.
  AutoTradingConfig copyWith({
    bool? enabled,
    double? buyThreshold,
    double? sellThreshold,
    int? maxPositionSize,
    double? maxPositionValue,
    List<String>? tickers,
  }) {
    return AutoTradingConfig(
      enabled: enabled ?? this.enabled,
      buyThreshold: buyThreshold ?? this.buyThreshold,
      sellThreshold: sellThreshold ?? this.sellThreshold,
      maxPositionSize: maxPositionSize ?? this.maxPositionSize,
      maxPositionValue: maxPositionValue ?? this.maxPositionValue,
      tickers: tickers ?? this.tickers,
    );
  }
}
