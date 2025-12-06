import 'package:flutter_test/flutter_test.dart';
import 'package:msa_ui/data/models/performance.dart';

import '../test_helpers.dart';

void main() {
  group('PerformanceSnapshot', () {
    test('isProfitable is true when dailyPnl >= 0', () {
      expect(createSamplePerformance(dailyPnl: 500.0).isProfitable, isTrue);
      expect(createSamplePerformance(dailyPnl: 0.0).isProfitable, isTrue);
    });

    test('isProfitable is false when dailyPnl < 0', () {
      expect(createSamplePerformance(dailyPnl: -500.0).isProfitable, isFalse);
    });

    test('toMap and fromMap round-trip correctly with all fields', () {
      final original = createSamplePerformance(
        sharpeRatio: 1.5,
        maxDrawdown: -2.5,
      );
      final map = original.toMap();
      final restored = PerformanceSnapshot.fromMap(map);

      expect(restored.portfolioValue, equals(original.portfolioValue));
      expect(restored.dailyPnl, equals(original.dailyPnl));
      expect(restored.totalReturn, equals(original.totalReturn));
      expect(restored.sharpeRatio, equals(original.sharpeRatio));
      expect(restored.maxDrawdown, equals(original.maxDrawdown));
      expect(
        restored.date.millisecondsSinceEpoch,
        equals(original.date.millisecondsSinceEpoch),
      );
    });

    test('toMap and fromMap handle null optional fields', () {
      final original = createSamplePerformance(
        sharpeRatio: null,
        maxDrawdown: null,
      );
      final map = original.toMap();
      final restored = PerformanceSnapshot.fromMap(map);

      expect(restored.sharpeRatio, isNull);
      expect(restored.maxDrawdown, isNull);
    });
  });
}
