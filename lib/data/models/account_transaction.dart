/// Account transaction model for deposits/withdrawals.
library;

/// Type of account transaction.
enum TransactionType {
  deposit,
  withdrawal;

  String get value => name.toUpperCase();

  static TransactionType fromString(String value) {
    return TransactionType.values.firstWhere(
      (t) => t.value == value.toUpperCase(),
      orElse: () => TransactionType.deposit,
    );
  }
}

/// Account transaction for tracking capital.
class AccountTransaction {
  const AccountTransaction({
    this.id,
    required this.type,
    required this.amount,
    required this.timestamp,
    this.notes,
  });

  final int? id;
  final TransactionType type;
  final double amount;
  final DateTime timestamp;
  final String? notes;

  Map<String, dynamic> toMap() => {
    'type': type.value,
    'amount': amount,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'notes': notes,
    'created_at': DateTime.now().millisecondsSinceEpoch,
  };

  factory AccountTransaction.fromMap(Map<String, dynamic> map) {
    return AccountTransaction(
      id: map['transaction_id'] as int?,
      type: TransactionType.fromString(map['type'] as String),
      amount: map['amount'] as double,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      notes: map['notes'] as String?,
    );
  }
}
