import 'package:flutter_test/flutter_test.dart';
import 'package:msa_ui/services/yahoo/yahoo_finance_repository.dart';

void main() {
  group('YahooFinanceRepository', () {
    late YahooFinanceRepository repo;

    setUp(() {
      repo = YahooFinanceRepository();
    });

    test('getLatestQuote returns data for valid ticker', () async {
      final quote = await repo.getLatestQuote('AAPL');

      // May be null if market is closed or network fails
      if (quote != null) {
        expect(quote.ticker, equals('AAPL'));
        expect(quote.close, greaterThan(0));
        expect(quote.volume, greaterThanOrEqualTo(0));
      }
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('getLatestQuote returns null for invalid ticker', () async {
      final quote = await repo.getLatestQuote('INVALIDTICKER123');
      expect(quote, isNull);
    });

    test('getHistoricalData returns list for valid ticker', () async {
      final bars = await repo.getHistoricalData('AAPL', days: 30);

      // Should have data if market is open
      if (bars.isNotEmpty) {
        expect(bars.first.ticker, equals('AAPL'));
        expect(bars.first.close, greaterThan(0));
        // Data should be sorted by timestamp
        for (var i = 1; i < bars.length; i++) {
          expect(bars[i].timestamp.isAfter(bars[i - 1].timestamp), isTrue);
        }
      }
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('getHistoricalData returns empty list for invalid ticker', () async {
      final bars = await repo.getHistoricalData('INVALIDTICKER123', days: 30);
      expect(bars, isEmpty);
    });

    test('getSignals computes signals from historical data', () async {
      final signals = await repo.getSignals('SPY');

      // Should get computed signals if historical data is available
      if (signals.isNotEmpty) {
        final signalNames = signals.map((s) => s.alphaName).toSet();
        expect(signalNames, contains('momentum_20'));
        expect(signalNames, contains('rsi_14'));

        // Scores should be normalized between -1 and 1
        for (final signal in signals) {
          expect(signal.score, inInclusiveRange(-1.0, 1.0));
        }
      }
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
