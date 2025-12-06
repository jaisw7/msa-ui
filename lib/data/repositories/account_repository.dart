/// Repository for account transactions (deposits/withdrawals).
library;

import 'package:flutter/foundation.dart';

import '../datasources/local/database.dart';
import '../models/account_transaction.dart';

/// Repository for managing account transactions.
class AccountRepository {
  /// Get all transactions.
  Future<List<AccountTransaction>> getTransactions() async {
    if (kIsWeb) return [];

    final db = await AppDatabase.database;
    final result = await db.query(
      'account_transactions',
      orderBy: 'timestamp DESC',
    );

    return result.map((r) => AccountTransaction.fromMap(r)).toList();
  }

  /// Add a transaction.
  Future<void> addTransaction(AccountTransaction txn) async {
    if (kIsWeb) return;

    final db = await AppDatabase.database;
    await db.insert('account_transactions', txn.toMap());
  }

  /// Get total deposits.
  Future<double> getTotalDeposits() async {
    if (kIsWeb) return 0.0;

    final db = await AppDatabase.database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM account_transactions
      WHERE type = 'DEPOSIT'
    ''');

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Get total withdrawals.
  Future<double> getTotalWithdrawals() async {
    if (kIsWeb) return 0.0;

    final db = await AppDatabase.database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM account_transactions
      WHERE type = 'WITHDRAWAL'
    ''');

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Get net capital invested (deposits - withdrawals).
  Future<double> getNetCapital() async {
    final deposits = await getTotalDeposits();
    final withdrawals = await getTotalWithdrawals();
    return deposits - withdrawals;
  }

  /// Get realized P&L from all closed trades.
  Future<double> getRealizedPnl() async {
    if (kIsWeb) return 0.0;

    final db = await AppDatabase.database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(pnl), 0) as total
      FROM trades
      WHERE pnl IS NOT NULL
    ''');

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Get account balance: deposits - withdrawals + realized P&L.
  /// This is the available cash for trading.
  Future<double> getAccountBalance() async {
    final netCapital = await getNetCapital();
    final realizedPnl = await getRealizedPnl();
    return netCapital + realizedPnl;
  }

  /// Seed initial capital (convenience method).
  Future<void> seedInitialCapital(double amount, {String? notes}) async {
    await addTransaction(AccountTransaction(
      type: TransactionType.deposit,
      amount: amount,
      timestamp: DateTime.now(),
      notes: notes ?? 'Initial capital',
    ));
  }

  /// Record a deposit.
  Future<void> deposit(double amount, {String? notes}) async {
    if (amount <= 0) throw ArgumentError('Amount must be positive');
    await addTransaction(AccountTransaction(
      type: TransactionType.deposit,
      amount: amount,
      timestamp: DateTime.now(),
      notes: notes,
    ));
  }

  /// Record a withdrawal.
  Future<void> withdraw(double amount, {String? notes}) async {
    if (amount <= 0) throw ArgumentError('Amount must be positive');
    await addTransaction(AccountTransaction(
      type: TransactionType.withdrawal,
      amount: amount,
      timestamp: DateTime.now(),
      notes: notes,
    ));
  }
}

