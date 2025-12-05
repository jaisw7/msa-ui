/// Positions screen showing all holdings.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../data/models/position.dart';

/// Positions screen displaying all current holdings.
class PositionsScreen extends StatelessWidget {
  const PositionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock positions
    final positions = [
      Position(
        ticker: 'AAPL',
        shares: 50,
        avgCost: 170.50,
        currentPrice: 175.23,
        lastUpdated: DateTime.now(),
      ),
      Position(
        ticker: 'MSFT',
        shares: 20,
        avgCost: 382.00,
        currentPrice: 380.45,
        lastUpdated: DateTime.now(),
      ),
      Position(
        ticker: 'GOOGL',
        shares: 15,
        avgCost: 140.00,
        currentPrice: 145.60,
        lastUpdated: DateTime.now(),
      ),
      Position(
        ticker: 'NVDA',
        shares: 10,
        avgCost: 480.00,
        currentPrice: 502.30,
        lastUpdated: DateTime.now(),
      ),
      Position(
        ticker: 'TSLA',
        shares: 25,
        avgCost: 242.00,
        currentPrice: 238.50,
        lastUpdated: DateTime.now(),
      ),
    ];

    final totalValue = positions.fold<double>(0, (sum, p) => sum + p.totalValue);
    final totalPnl = positions.fold<double>(0, (sum, p) => sum + p.pnl);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Positions'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // TODO: Implement refresh
        },
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
  const _SummaryCard({
    required this.totalValue,
    required this.totalPnl,
  });

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
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: AppDimensions.paddingXS),
          Text(
            currencyFormat.format(totalValue),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
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
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
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

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingM),
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      position.ticker,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${position.shares} shares @ ${currencyFormat.format(position.avgCost)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
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
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${position.pnl >= 0 ? '+' : ''}${currencyFormat.format(position.pnl)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: position.isProfitable
                              ? AppColors.profit
                              : AppColors.loss,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (position.isProfitable
                                  ? AppColors.profit
                                  : AppColors.loss)
                              .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${position.pnlPercent >= 0 ? '+' : ''}${position.pnlPercent.toStringAsFixed(2)}%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: position.isProfitable
                                ? AppColors.profit
                                : AppColors.loss,
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
        ],
      ),
    );
  }
}
