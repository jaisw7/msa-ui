import 'package:flutter_test/flutter_test.dart';
import 'package:msa_ui/data/models/account_transaction.dart';

import '../test_helpers.dart';

void main() {
  group('TransactionType', () {
    test('value returns uppercase name', () {
      expect(TransactionType.deposit.value, equals('DEPOSIT'));
      expect(TransactionType.withdrawal.value, equals('WITHDRAWAL'));
    });

    test('fromString parses correctly', () {
      expect(
        TransactionType.fromString('DEPOSIT'),
        equals(TransactionType.deposit),
      );
      expect(
        TransactionType.fromString('deposit'),
        equals(TransactionType.deposit),
      );
      expect(
        TransactionType.fromString('WITHDRAWAL'),
        equals(TransactionType.withdrawal),
      );
      expect(
        TransactionType.fromString('withdrawal'),
        equals(TransactionType.withdrawal),
      );
    });

    test('fromString defaults to deposit for unknown values', () {
      expect(
        TransactionType.fromString('UNKNOWN'),
        equals(TransactionType.deposit),
      );
      expect(
        TransactionType.fromString(''),
        equals(TransactionType.deposit),
      );
    });
  });

  group('AccountTransaction', () {
    test('toMap serializes correctly', () {
      final transaction = createSampleTransaction(
        type: TransactionType.deposit,
        amount: 10000.0,
        notes: 'Initial deposit',
      );
      final map = transaction.toMap();

      expect(map['type'], equals('DEPOSIT'));
      expect(map['amount'], equals(10000.0));
      expect(map['notes'], equals('Initial deposit'));
      expect(map['timestamp'], isA<int>());
      expect(map['created_at'], isA<int>());
    });

    test('fromMap deserializes correctly', () {
      final map = {
        'transaction_id': 1,
        'type': 'WITHDRAWAL',
        'amount': 5000.0,
        'timestamp': DateTime(2025, 1, 15).millisecondsSinceEpoch,
        'notes': 'Cash withdrawal',
      };
      final transaction = AccountTransaction.fromMap(map);

      expect(transaction.id, equals(1));
      expect(transaction.type, equals(TransactionType.withdrawal));
      expect(transaction.amount, equals(5000.0));
      expect(transaction.notes, equals('Cash withdrawal'));
    });

    test('handles null id and notes', () {
      final map = {
        'transaction_id': null,
        'type': 'DEPOSIT',
        'amount': 1000.0,
        'timestamp': DateTime(2025, 1, 15).millisecondsSinceEpoch,
        'notes': null,
      };
      final transaction = AccountTransaction.fromMap(map);

      expect(transaction.id, isNull);
      expect(transaction.notes, isNull);
    });
  });
}
