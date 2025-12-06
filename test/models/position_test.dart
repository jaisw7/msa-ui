import 'package:flutter_test/flutter_test.dart';
import 'package:msa_ui/data/models/position.dart';

import '../test_helpers.dart';

void main() {
  group('Position', () {
    test('computed properties calculate correctly', () {
      final position = createSamplePosition(
        shares: 10,
        avgCost: 150.0,
        currentPrice: 175.0,
      );

      expect(position.totalValue, equals(1750.0));
      expect(position.totalCost, equals(1500.0));
      expect(position.pnl, equals(250.0));
      expect(position.pnlPercent, closeTo(16.67, 0.01));
      expect(position.isProfitable, isTrue);
    });

    test('handles negative PnL correctly', () {
      final position = createSamplePosition(
        shares: 10,
        avgCost: 175.0,
        currentPrice: 150.0,
      );

      expect(position.pnl, equals(-250.0));
      expect(position.pnlPercent, closeTo(-14.29, 0.01));
      expect(position.isProfitable, isFalse);
    });

    test('handles zero shares', () {
      final position = createSamplePosition(shares: 0);

      expect(position.totalValue, equals(0.0));
      expect(position.totalCost, equals(0.0));
      expect(position.pnl, equals(0.0));
      expect(position.pnlPercent, equals(0.0));
      expect(position.isProfitable, isTrue);
    });

    test('toMap and fromMap round-trip correctly', () {
      final original = createSamplePosition();
      final map = original.toMap();
      final restored = Position.fromMap(map);

      expect(restored.ticker, equals(original.ticker));
      expect(restored.shares, equals(original.shares));
      expect(restored.avgCost, equals(original.avgCost));
      expect(restored.currentPrice, equals(original.currentPrice));
      expect(
        restored.lastUpdated.millisecondsSinceEpoch,
        equals(original.lastUpdated.millisecondsSinceEpoch),
      );
    });

    test('copyWith creates modified copy', () {
      final original = createSamplePosition();
      final modified = original.copyWith(shares: 20, currentPrice: 200.0);

      expect(modified.ticker, equals(original.ticker));
      expect(modified.shares, equals(20));
      expect(modified.avgCost, equals(original.avgCost));
      expect(modified.currentPrice, equals(200.0));
    });
  });
}
