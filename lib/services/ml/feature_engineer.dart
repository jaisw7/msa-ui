import 'dart:math' as math;

/// Feature engineering utilities for ML model inputs.
///
/// This mirrors the Python feature engineering logic from msa.
class FeatureEngineer {
  /// Calculate Simple Moving Average (SMA).
  static List<double> sma(List<double> prices, int period) {
    final result = <double>[];
    for (int i = 0; i < prices.length; i++) {
      if (i < period - 1) {
        result.add(double.nan);
      } else {
        double sum = 0;
        for (int j = i - period + 1; j <= i; j++) {
          sum += prices[j];
        }
        result.add(sum / period);
      }
    }
    return result;
  }

  /// Calculate Exponential Moving Average (EMA).
  static List<double> ema(List<double> prices, int period) {
    final result = <double>[];
    final multiplier = 2 / (period + 1);

    if (prices.isEmpty) return result;

    // Start with SMA for first value
    double smaValue = 0;
    for (int i = 0; i < period && i < prices.length; i++) {
      smaValue += prices[i];
    }
    smaValue /= period;

    for (int i = 0; i < prices.length; i++) {
      if (i < period - 1) {
        result.add(double.nan);
      } else if (i == period - 1) {
        result.add(smaValue);
      } else {
        final prevEma = result[i - 1];
        result.add((prices[i] - prevEma) * multiplier + prevEma);
      }
    }
    return result;
  }

  /// Calculate Relative Strength Index (RSI).
  static List<double> rsi(List<double> prices, int period) {
    if (prices.length < 2) return List.filled(prices.length, double.nan);

    final result = <double>[];
    final gains = <double>[];
    final losses = <double>[];

    // Calculate price changes
    for (int i = 0; i < prices.length; i++) {
      if (i == 0) {
        gains.add(0);
        losses.add(0);
      } else {
        final change = prices[i] - prices[i - 1];
        gains.add(change > 0 ? change : 0);
        losses.add(change < 0 ? -change : 0);
      }
    }

    // Calculate RSI
    for (int i = 0; i < prices.length; i++) {
      if (i < period) {
        result.add(double.nan);
      } else {
        double avgGain = 0;
        double avgLoss = 0;

        // First RSI uses simple average
        if (i == period) {
          for (int j = i - period + 1; j <= i; j++) {
            avgGain += gains[j];
            avgLoss += losses[j];
          }
          avgGain /= period;
          avgLoss /= period;
        } else {
          // Subsequent values use smoothed average
          final prevRsi = result[i - 1];
          final prevAvgGain =
              (prevRsi == 100 ? 1 : (100 - prevRsi) / (100 / prevRsi - 1));
          final prevAvgLoss = prevAvgGain * (100 / prevRsi - 1);

          avgGain = (prevAvgGain * (period - 1) + gains[i]) / period;
          avgLoss = (prevAvgLoss * (period - 1) + losses[i]) / period;
        }

        if (avgLoss == 0) {
          result.add(100);
        } else {
          final rs = avgGain / avgLoss;
          result.add(100 - (100 / (1 + rs)));
        }
      }
    }
    return result;
  }

  /// Calculate MACD (Moving Average Convergence Divergence).
  ///
  /// Returns (macd, signal, histogram)
  static (List<double>, List<double>, List<double>) macd(
    List<double> prices, {
    int fastPeriod = 12,
    int slowPeriod = 26,
    int signalPeriod = 9,
  }) {
    final emaFast = ema(prices, fastPeriod);
    final emaSlow = ema(prices, slowPeriod);

    // MACD line
    final macdLine = <double>[];
    for (int i = 0; i < prices.length; i++) {
      if (emaFast[i].isNaN || emaSlow[i].isNaN) {
        macdLine.add(double.nan);
      } else {
        macdLine.add(emaFast[i] - emaSlow[i]);
      }
    }

    // Signal line (EMA of MACD)
    final signalLine = ema(macdLine, signalPeriod);

    // Histogram
    final histogram = <double>[];
    for (int i = 0; i < prices.length; i++) {
      if (macdLine[i].isNaN || signalLine[i].isNaN) {
        histogram.add(double.nan);
      } else {
        histogram.add(macdLine[i] - signalLine[i]);
      }
    }

    return (macdLine, signalLine, histogram);
  }

  /// Calculate Bollinger Bands.
  ///
  /// Returns (upper, middle, lower)
  static (List<double>, List<double>, List<double>) bollingerBands(
    List<double> prices, {
    int period = 20,
    double stdDev = 2.0,
  }) {
    final middle = sma(prices, period);
    final upper = <double>[];
    final lower = <double>[];

    for (int i = 0; i < prices.length; i++) {
      if (i < period - 1) {
        upper.add(double.nan);
        lower.add(double.nan);
      } else {
        // Calculate standard deviation
        double sum = 0;
        for (int j = i - period + 1; j <= i; j++) {
          sum += (prices[j] - middle[i]) * (prices[j] - middle[i]);
        }
        final std = math.sqrt(sum / period);
        upper.add(middle[i] + stdDev * std);
        lower.add(middle[i] - stdDev * std);
      }
    }

    return (upper, middle, lower);
  }

  /// Calculate standard deviation over a rolling window.
  static List<double> rollingStd(List<double> values, int period) {
    final result = <double>[];
    for (int i = 0; i < values.length; i++) {
      if (i < period - 1) {
        result.add(double.nan);
      } else {
        double sum = 0;
        double sumSq = 0;
        for (int j = i - period + 1; j <= i; j++) {
          sum += values[j];
          sumSq += values[j] * values[j];
        }
        final mean = sum / period;
        final variance = sumSq / period - mean * mean;
        result.add(variance > 0 ? math.sqrt(variance) : 0);
      }
    }
    return result;
  }

  /// Calculate percentage returns.
  static List<double> returns(List<double> prices) {
    final result = <double>[double.nan];
    for (int i = 1; i < prices.length; i++) {
      if (prices[i - 1] == 0) {
        result.add(0);
      } else {
        result.add((prices[i] - prices[i - 1]) / prices[i - 1]);
      }
    }
    return result;
  }

  /// Calculate log returns.
  static List<double> logReturns(List<double> prices) {
    final result = <double>[double.nan];
    for (int i = 1; i < prices.length; i++) {
      if (prices[i - 1] <= 0 || prices[i] <= 0) {
        result.add(0);
      } else {
        result.add(math.log(prices[i] / prices[i - 1]));
      }
    }
    return result;
  }

  /// Get the lagged value of a series.
  static List<double> lag(List<double> values, int periods) {
    final result = <double>[];
    for (int i = 0; i < values.length; i++) {
      if (i < periods) {
        result.add(double.nan);
      } else {
        result.add(values[i - periods]);
      }
    }
    return result;
  }

  /// Calculate price momentum (price / lagged_price - 1).
  static List<double> momentum(List<double> prices, int period) {
    final result = <double>[];
    for (int i = 0; i < prices.length; i++) {
      if (i < period) {
        result.add(double.nan);
      } else {
        if (prices[i - period] == 0) {
          result.add(0);
        } else {
          result.add(prices[i] / prices[i - period] - 1);
        }
      }
    }
    return result;
  }

  /// Calculate rolling skewness.
  static List<double> rollingSkew(List<double> values, int period) {
    final result = <double>[];
    for (int i = 0; i < values.length; i++) {
      if (i < period - 1) {
        result.add(double.nan);
      } else {
        // Get window
        final window = values.sublist(i - period + 1, i + 1);

        // Calculate mean
        double sum = 0;
        for (final v in window) {
          sum += v;
        }
        final mean = sum / period;

        // Calculate std
        double sumSq = 0;
        for (final v in window) {
          sumSq += (v - mean) * (v - mean);
        }
        final std = math.sqrt(sumSq / period);

        if (std == 0) {
          result.add(0);
        } else {
          // Calculate skewness
          double sumCube = 0;
          for (final v in window) {
            sumCube += math.pow((v - mean) / std, 3);
          }
          result.add(sumCube / period);
        }
      }
    }
    return result;
  }
}
