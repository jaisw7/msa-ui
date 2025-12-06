import 'package:flutter_test/flutter_test.dart';
import 'package:msa_ui/data/models/alpha_signal.dart';

import '../test_helpers.dart';

void main() {
  group('AlphaSignal', () {
    test('signal is BUY when score > 0.5', () {
      final signal = createSampleAlphaSignal(score: 0.75);
      expect(signal.signal, equals(SignalType.buy));
      expect(signal.signalLabel, equals('BUY'));
    });

    test('signal is SELL when score < -0.5', () {
      final signal = createSampleAlphaSignal(score: -0.75);
      expect(signal.signal, equals(SignalType.sell));
      expect(signal.signalLabel, equals('SELL'));
    });

    test('signal is HOLD when score is between -0.5 and 0.5', () {
      expect(
        createSampleAlphaSignal(score: 0.25).signal,
        equals(SignalType.hold),
      );
      expect(
        createSampleAlphaSignal(score: -0.25).signal,
        equals(SignalType.hold),
      );
      expect(
        createSampleAlphaSignal(score: 0.5).signal,
        equals(SignalType.hold),
      );
      expect(
        createSampleAlphaSignal(score: -0.5).signal,
        equals(SignalType.hold),
      );
    });

    test('strength is absolute value of score', () {
      expect(createSampleAlphaSignal(score: 0.75).strength, equals(0.75));
      expect(createSampleAlphaSignal(score: -0.75).strength, equals(0.75));
      expect(createSampleAlphaSignal(score: 0.0).strength, equals(0.0));
    });

    test('boundary conditions for signal type', () {
      // Exactly at boundary should be HOLD
      expect(
        createSampleAlphaSignal(score: 0.5).signal,
        equals(SignalType.hold),
      );
      expect(
        createSampleAlphaSignal(score: -0.5).signal,
        equals(SignalType.hold),
      );

      // Just above/below boundary should trigger
      expect(
        createSampleAlphaSignal(score: 0.51).signal,
        equals(SignalType.buy),
      );
      expect(
        createSampleAlphaSignal(score: -0.51).signal,
        equals(SignalType.sell),
      );
    });
  });
}
