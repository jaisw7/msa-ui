import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:msa_ui/services/ml/feature_engineer.dart';

void main() {
  group('FeatureEngineer.sma', () {
    test('calculates SMA correctly', () {
      final prices = [1.0, 2.0, 3.0, 4.0, 5.0];
      final sma = FeatureEngineer.sma(prices, 3);

      // First 2 values should be NaN
      expect(sma[0].isNaN, isTrue);
      expect(sma[1].isNaN, isTrue);
      // SMA values
      expect(sma[2], equals(2.0)); // (1+2+3)/3
      expect(sma[3], equals(3.0)); // (2+3+4)/3
      expect(sma[4], equals(4.0)); // (3+4+5)/3
    });

    test('handles empty list', () {
      final sma = FeatureEngineer.sma([], 3);
      expect(sma, isEmpty);
    });

    test('handles list shorter than period', () {
      final sma = FeatureEngineer.sma([1.0, 2.0], 3);
      expect(sma[0].isNaN, isTrue);
      expect(sma[1].isNaN, isTrue);
    });
  });

  group('FeatureEngineer.ema', () {
    test('first valid EMA is SMA of first [period] values', () {
      final prices = [1.0, 2.0, 3.0, 4.0, 5.0];
      final ema = FeatureEngineer.ema(prices, 3);

      expect(ema[0].isNaN, isTrue);
      expect(ema[1].isNaN, isTrue);
      expect(ema[2], equals(2.0)); // SMA of first 3: (1+2+3)/3
    });

    test('subsequent EMA uses smoothing', () {
      final prices = [1.0, 2.0, 3.0, 4.0, 5.0];
      final ema = FeatureEngineer.ema(prices, 3);

      // EMA(today) = (Price - EMA(yesterday)) * multiplier + EMA(yesterday)
      // multiplier = 2 / (3 + 1) = 0.5
      final expectedEma3 = (4.0 - 2.0) * 0.5 + 2.0; // 3.0
      final expectedEma4 = (5.0 - 3.0) * 0.5 + 3.0; // 4.0

      expect(ema[3], closeTo(expectedEma3, 0.01));
      expect(ema[4], closeTo(expectedEma4, 0.01));
    });

    test('handles empty list', () {
      final ema = FeatureEngineer.ema([], 3);
      expect(ema, isEmpty);
    });
  });

  group('FeatureEngineer.rsi', () {
    test('returns NaN for insufficient data', () {
      final prices = [1.0, 2.0, 3.0];
      final rsi = FeatureEngineer.rsi(prices, 5);

      for (final value in rsi) {
        expect(value.isNaN, isTrue);
      }
    });

    test('returns 100 when only gains', () {
      // Constantly increasing prices should yield RSI = 100
      final prices = List.generate(20, (i) => (i + 1).toDouble());
      final rsi = FeatureEngineer.rsi(prices, 14);

      // After enough data, RSI should be 100 (only gains)
      expect(rsi.last, equals(100.0));
    });

    test('RSI is between 0 and 100', () {
      final prices = [
        100.0, 102.0, 101.0, 103.5, 102.0, 104.0, 103.0, 105.0,
        104.0, 106.0, 105.0, 107.0, 106.0, 108.0, 107.0, 109.0,
      ];
      final rsi = FeatureEngineer.rsi(prices, 14);

      for (final value in rsi) {
        if (!value.isNaN) {
          expect(value, greaterThanOrEqualTo(0));
          expect(value, lessThanOrEqualTo(100));
        }
      }
    });

    test('handles single price', () {
      final rsi = FeatureEngineer.rsi([100.0], 14);
      expect(rsi.length, equals(1));
      expect(rsi[0].isNaN, isTrue);
    });
  });

  group('FeatureEngineer.macd', () {
    test('returns correct structure', () {
      final prices = List.generate(50, (i) => 100.0 + i * 0.5);
      final (macd, signal, histogram) = FeatureEngineer.macd(prices);

      expect(macd.length, equals(prices.length));
      expect(signal.length, equals(prices.length));
      expect(histogram.length, equals(prices.length));
    });

    test('early values are NaN due to EMA lookback', () {
      final prices = List.generate(50, (i) => 100.0 + i * 0.5);
      final (macd, signal, histogram) = FeatureEngineer.macd(prices);

      // slowPeriod is 26, so first 25 MACD values should be NaN
      for (int i = 0; i < 25; i++) {
        expect(macd[i].isNaN, isTrue);
      }
    });

    test('histogram equals macd minus signal', () {
      final prices = List.generate(50, (i) => 100.0 + math.sin(i * 0.1) * 5);
      final (macd, signal, histogram) = FeatureEngineer.macd(prices);

      for (int i = 0; i < prices.length; i++) {
        if (!macd[i].isNaN && !signal[i].isNaN) {
          expect(histogram[i], closeTo(macd[i] - signal[i], 0.0001));
        }
      }
    });
  });

  group('FeatureEngineer.bollingerBands', () {
    test('middle band equals SMA', () {
      final prices = List.generate(30, (i) => 100.0 + i * 0.5);
      final (upper, middle, lower) = FeatureEngineer.bollingerBands(prices);
      final sma = FeatureEngineer.sma(prices, 20);

      for (int i = 19; i < prices.length; i++) {
        expect(middle[i], equals(sma[i]));
      }
    });

    test('upper is greater than middle, lower is less', () {
      final prices = List.generate(30, (i) => 100.0 + math.sin(i * 0.2) * 5);
      final (upper, middle, lower) = FeatureEngineer.bollingerBands(prices);

      for (int i = 19; i < prices.length; i++) {
        expect(upper[i], greaterThan(middle[i]));
        expect(lower[i], lessThan(middle[i]));
      }
    });

    test('bands are symmetric around middle', () {
      final prices = List.generate(30, (i) => 100.0 + i * 0.5);
      final (upper, middle, lower) =
          FeatureEngineer.bollingerBands(prices, stdDev: 2.0);

      for (int i = 19; i < prices.length; i++) {
        final upperDiff = upper[i] - middle[i];
        final lowerDiff = middle[i] - lower[i];
        expect(upperDiff, closeTo(lowerDiff, 0.0001));
      }
    });
  });

  group('FeatureEngineer.rollingStd', () {
    test('calculates std correctly', () {
      final values = [1.0, 2.0, 3.0, 4.0, 5.0];
      final std = FeatureEngineer.rollingStd(values, 3);

      expect(std[0].isNaN, isTrue);
      expect(std[1].isNaN, isTrue);

      // std of [1,2,3] = sqrt(((1-2)^2 + (2-2)^2 + (3-2)^2) / 3) = sqrt(2/3)
      final expectedStd = math.sqrt(2 / 3);
      expect(std[2], closeTo(expectedStd, 0.0001));
    });

    test('returns 0 for constant values', () {
      final values = [5.0, 5.0, 5.0, 5.0, 5.0];
      final std = FeatureEngineer.rollingStd(values, 3);

      for (int i = 2; i < values.length; i++) {
        expect(std[i], equals(0.0));
      }
    });
  });

  group('FeatureEngineer.returns', () {
    test('calculates percentage returns', () {
      final prices = [100.0, 110.0, 99.0, 110.0];
      final returns = FeatureEngineer.returns(prices);

      expect(returns[0].isNaN, isTrue);
      expect(returns[1], closeTo(0.10, 0.0001)); // (110-100)/100
      expect(returns[2], closeTo(-0.10, 0.0001)); // (99-110)/110
      expect(returns[3], closeTo(0.1111, 0.001)); // (110-99)/99
    });

    test('handles zero price', () {
      final prices = [0.0, 100.0];
      final returns = FeatureEngineer.returns(prices);

      expect(returns[1], equals(0.0)); // Division by zero handled
    });
  });

  group('FeatureEngineer.logReturns', () {
    test('calculates log returns', () {
      final prices = [100.0, 110.0, 121.0];
      final logReturns = FeatureEngineer.logReturns(prices);

      expect(logReturns[0].isNaN, isTrue);
      expect(logReturns[1], closeTo(math.log(110 / 100), 0.0001));
      expect(logReturns[2], closeTo(math.log(121 / 110), 0.0001));
    });

    test('handles zero and negative prices', () {
      final prices = [100.0, 0.0, 100.0];
      final logReturns = FeatureEngineer.logReturns(prices);

      expect(logReturns[1], equals(0.0)); // protected from log(0)
      expect(logReturns[2], equals(0.0)); // 0/100 = 0, log(0) protected
    });
  });

  group('FeatureEngineer.lag', () {
    test('lags values correctly', () {
      final values = [1.0, 2.0, 3.0, 4.0, 5.0];
      final lagged = FeatureEngineer.lag(values, 2);

      expect(lagged[0].isNaN, isTrue);
      expect(lagged[1].isNaN, isTrue);
      expect(lagged[2], equals(1.0));
      expect(lagged[3], equals(2.0));
      expect(lagged[4], equals(3.0));
    });

    test('lag of 0 returns original values', () {
      final values = [1.0, 2.0, 3.0];
      final lagged = FeatureEngineer.lag(values, 0);

      expect(lagged, equals(values));
    });
  });

  group('FeatureEngineer.momentum', () {
    test('calculates momentum correctly', () {
      final prices = [100.0, 110.0, 120.0, 130.0, 140.0];
      final momentum = FeatureEngineer.momentum(prices, 2);

      expect(momentum[0].isNaN, isTrue);
      expect(momentum[1].isNaN, isTrue);
      expect(momentum[2], closeTo(0.20, 0.0001)); // 120/100 - 1
      expect(momentum[3], closeTo(0.1818, 0.001)); // 130/110 - 1
      expect(momentum[4], closeTo(0.1667, 0.001)); // 140/120 - 1
    });

    test('handles zero price', () {
      final prices = [0.0, 100.0, 110.0];
      final momentum = FeatureEngineer.momentum(prices, 1);

      expect(momentum[1], equals(0.0)); // Division by zero handled
    });
  });

  group('FeatureEngineer.rollingSkew', () {
    test('constant values have zero skew', () {
      final values = [5.0, 5.0, 5.0, 5.0, 5.0];
      final skew = FeatureEngineer.rollingSkew(values, 3);

      for (int i = 2; i < values.length; i++) {
        expect(skew[i], equals(0.0));
      }
    });

    test('early values are NaN', () {
      final values = [1.0, 2.0, 3.0, 4.0, 5.0];
      final skew = FeatureEngineer.rollingSkew(values, 3);

      expect(skew[0].isNaN, isTrue);
      expect(skew[1].isNaN, isTrue);
      expect(skew[2].isNaN, isFalse);
    });

    test('calculates skewness for ascending values', () {
      final values = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0];
      final skew = FeatureEngineer.rollingSkew(values, 3);

      // All windows are [n, n+1, n+2] - symmetric, skew should be ~0
      for (int i = 2; i < values.length; i++) {
        expect(skew[i], closeTo(0.0, 0.01));
      }
    });
  });
}
