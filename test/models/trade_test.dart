import 'package:flutter_test/flutter_test.dart';
import 'package:msa_ui/data/models/trade.dart';

import '../test_helpers.dart';

void main() {
  group('Trade', () {
    test('totalValue calculates correctly', () {
      final trade = createSampleTrade(shares: 10, price: 150.0);
      expect(trade.totalValue, equals(1500.0));
    });

    test('toMap and fromMap round-trip correctly for BUY', () {
      final original = createSampleTrade(type: TradeType.buy);
      final map = original.toMap();
      final restored = Trade.fromMap(map);

      expect(restored.id, equals(original.id));
      expect(restored.ticker, equals(original.ticker));
      expect(restored.type, equals(TradeType.buy));
      expect(restored.shares, equals(original.shares));
      expect(restored.price, equals(original.price));
      expect(restored.signal, equals(original.signal));
      expect(
        restored.timestamp.millisecondsSinceEpoch,
        equals(original.timestamp.millisecondsSinceEpoch),
      );
    });

    test('toMap and fromMap round-trip correctly for SELL', () {
      final original = createSampleTrade(
        type: TradeType.sell,
        pnl: 250.0,
      );
      final map = original.toMap();
      final restored = Trade.fromMap(map);

      expect(restored.type, equals(TradeType.sell));
      expect(restored.pnl, equals(250.0));
    });

    test('handles null pnl correctly', () {
      final trade = createSampleTrade(pnl: null);
      final map = trade.toMap();
      final restored = Trade.fromMap(map);

      expect(restored.pnl, isNull);
    });

    test('TradeType enum serializes correctly', () {
      final buyTrade = createSampleTrade(type: TradeType.buy);
      final sellTrade = createSampleTrade(type: TradeType.sell);

      expect(buyTrade.toMap()['type'], equals('BUY'));
      expect(sellTrade.toMap()['type'], equals('SELL'));
    });
  });
}
