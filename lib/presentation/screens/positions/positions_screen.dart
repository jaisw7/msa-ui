/// Positions screen showing all holdings.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/router/app_router.dart';
import '../../../data/models/position.dart';
import '../../providers/providers.dart';

/// Positions screen displaying all current holdings.
class PositionsScreen extends ConsumerWidget {
  const PositionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portfolioState = ref.watch(portfolioProvider);
    final positions = portfolioState.positions;

    if (portfolioState.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Positions')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (positions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Positions')),
        body: RefreshIndicator(
          onRefresh: () async => ref.read(portfolioProvider.notifier).refresh(),
          child: ListView(
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.3),
              Center(
                child: Column(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, size: 64, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                    const SizedBox(height: AppDimensions.paddingM),
                    Text('No positions', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
                    const SizedBox(height: AppDimensions.paddingS),
                    Text('Your holdings will appear here', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3))),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final totalValue = positions.fold<double>(0, (sum, p) => sum + p.totalValue);
    final totalPnl = positions.fold<double>(0, (sum, p) => sum + p.pnl);

    return Scaffold(
      appBar: AppBar(title: const Text('Positions')),
      body: RefreshIndicator(
        onRefresh: () async => ref.read(portfolioProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          children: [
            _SummaryCard(totalValue: totalValue, totalPnl: totalPnl),
            const SizedBox(height: AppDimensions.paddingL),
            ...positions.map((p) => _PositionCard(position: p)),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.totalValue, required this.totalPnl});

  final double totalValue;
  final double totalPnl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Value',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: AppDimensions.paddingXS),
          Text(
            currencyFormat.format(totalValue),
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppDimensions.paddingS),
          Row(
            children: [
              Icon(
                totalPnl >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                color: totalPnl >= 0 ? AppColors.profit : AppColors.loss,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                currencyFormat.format(totalPnl.abs()),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: totalPnl >= 0 ? AppColors.profit : AppColors.loss,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Unrealized P&L',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PositionCard extends StatelessWidget {
  const _PositionCard({required this.position});

  final Position position;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    return InkWell(
      onTap: () => context.push(AppRoutes.stockDetail(position.ticker)),
      borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppDimensions.paddingM),
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(position.ticker, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    '${position.shares} shares @ ${currencyFormat.format(position.avgCost)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  currencyFormat.format(position.totalValue),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${position.pnl >= 0 ? '+' : ''}${currencyFormat.format(position.pnl)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: position.isProfitable ? AppColors.profit : AppColors.loss,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (position.isProfitable ? AppColors.profit : AppColors.loss).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${position.pnlPercent >= 0 ? '+' : ''}${position.pnlPercent.toStringAsFixed(2)}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: position.isProfitable ? AppColors.profit : AppColors.loss,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

