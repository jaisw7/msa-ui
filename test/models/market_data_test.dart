import 'package:flutter_test/flutter_test.dart';
import 'package:msa_ui/data/models/market_data.dart';

import '../test_helpers.dart';

void main() {
  group('MarketData', () {
    test('computed change is close minus open', () {
      final data = createSampleMarketData(open: 150.0, close: 155.0);
      expect(data.change, equals(5.0));
    });

    test('changePercent calculates correctly', () {
      final data = createSampleMarketData(open: 100.0, close: 105.0);
      expect(data.changePercent, equals(5.0));
    });

    test('changePercent handles zero open', () {
      final data = createSampleMarketData(open: 0.0, close: 105.0);
      expect(data.changePercent, equals(0.0));
    });

    test('isBullish is true when close >= open', () {
      expect(
        createSampleMarketData(open: 100.0, close: 105.0).isBullish,
        isTrue,
      );
      expect(
        createSampleMarketData(open: 100.0, close: 100.0).isBullish,
        isTrue,
      );
    });

    test('isBullish is false when close < open', () {
      expect(
        createSampleMarketData(open: 105.0, close: 100.0).isBullish,
        isFalse,
      );
    });

    test('toMap and fromMap round-trip correctly', () {
      final original = createSampleMarketData();
      final map = original.toMap();
      final restored = MarketData.fromMap(map);

      expect(restored.ticker, equals(original.ticker));
      expect(restored.open, equals(original.open));
      expect(restored.high, equals(original.high));
      expect(restored.low, equals(original.low));
      expect(restored.close, equals(original.close));
      expect(restored.volume, equals(original.volume));
      expect(
        restored.timestamp.millisecondsSinceEpoch,
        equals(original.timestamp.millisecondsSinceEpoch),
      );
    });
  });
}
