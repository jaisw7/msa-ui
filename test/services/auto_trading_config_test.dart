import 'package:flutter_test/flutter_test.dart';
import 'package:msa_ui/services/auto_trading_config.dart';

void main() {
  group('AutoTradingConfig', () {
    test('defaultConfig has expected values', () {
      const config = AutoTradingConfig.defaultConfig;

      expect(config.enabled, isFalse);
      expect(config.buyThreshold, equals(0.7));
      expect(config.sellThreshold, equals(-0.7));
      expect(config.maxPositionSize, equals(100));
      expect(config.maxPositionValue, equals(10000));
      expect(config.tickers, containsAll(['AAPL', 'GOOGL']));
    });

    test('copyWith creates modified copy', () {
      const original = AutoTradingConfig.defaultConfig;
      final modified = original.copyWith(
        enabled: true,
        buyThreshold: 0.8,
      );

      expect(modified.enabled, isTrue);
      expect(modified.buyThreshold, equals(0.8));
      // Unchanged fields
      expect(modified.sellThreshold, equals(original.sellThreshold));
      expect(modified.maxPositionSize, equals(original.maxPositionSize));
      expect(modified.maxPositionValue, equals(original.maxPositionValue));
      expect(modified.tickers, equals(original.tickers));
    });

    test('copyWith with all fields', () {
      const original = AutoTradingConfig.defaultConfig;
      final modified = original.copyWith(
        enabled: true,
        buyThreshold: 0.9,
        sellThreshold: -0.9,
        maxPositionSize: 50,
        maxPositionValue: 5000,
        tickers: ['SPY', 'QQQ'],
      );

      expect(modified.enabled, isTrue);
      expect(modified.buyThreshold, equals(0.9));
      expect(modified.sellThreshold, equals(-0.9));
      expect(modified.maxPositionSize, equals(50));
      expect(modified.maxPositionValue, equals(5000));
      expect(modified.tickers, equals(['SPY', 'QQQ']));
    });

    test('copyWith with null preserves original values', () {
      const original = AutoTradingConfig(
        enabled: true,
        buyThreshold: 0.5,
        sellThreshold: -0.5,
        maxPositionSize: 200,
        maxPositionValue: 20000,
        tickers: ['NVDA'],
      );

      final copy = original.copyWith();

      expect(copy.enabled, equals(original.enabled));
      expect(copy.buyThreshold, equals(original.buyThreshold));
      expect(copy.sellThreshold, equals(original.sellThreshold));
      expect(copy.maxPositionSize, equals(original.maxPositionSize));
      expect(copy.maxPositionValue, equals(original.maxPositionValue));
      expect(copy.tickers, equals(original.tickers));
    });
  });
}
