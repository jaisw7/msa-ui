/// Performance screen with metrics and equity curve.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../data/models/trade.dart';
import '../../providers/providers.dart';

/// Performance screen showing equity curve and metrics.
class PerformanceScreen extends ConsumerWidget {
  const PerformanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(performanceMetricsProvider);
    final tradesAsync = ref.watch(recentTradesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Performance')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _EquityCurve(),
            const SizedBox(height: AppDimensions.paddingL),
            metricsAsync.when(
              data: (metrics) => _MetricsGrid(metrics: metrics),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
            const SizedBox(height: AppDimensions.paddingL),
            Text(
              'Trade History',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppDimensions.paddingM),
            tradesAsync.when(
              data: (trades) => _TradeHistory(trades: trades),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ],
        ),
      ),
    );
  }
}

class _EquityCurve extends ConsumerWidget {
  const _EquityCurve();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final snapshotsAsync = ref.watch(performanceSnapshotsProvider);

    return Container(
      height: AppDimensions.chartHeight,
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Equity Curve',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: AppDimensions.paddingS),
          Expanded(
            child: snapshotsAsync.when(
              data: (snapshots) {
                final data = snapshots.map((s) => s.portfolioValue).toList();
                if (data.isEmpty) {
                  return const Center(child: Text('No data'));
                }

                final minY = data.reduce((a, b) => a < b ? a : b) * 0.995;
                final maxY = data.reduce((a, b) => a > b ? a : b) * 1.005;

                return LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: (maxY - minY) / 4,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: AppColors.chartGrid.withValues(alpha: 0.2),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    minY: minY,
                    maxY: maxY,
                    lineBarsData: [
                      LineChartBarData(
                        spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                        isCurved: true,
                        color: AppColors.chartLine,
                        barWidth: 2,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [AppColors.chartFill, AppColors.chartFill.withValues(alpha: 0)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.metrics});

  final Map<String, double> metrics;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppDimensions.paddingM,
      mainAxisSpacing: AppDimensions.paddingM,
      childAspectRatio: 1.6,
      children: [
        _MetricCard(
          label: 'Total Return',
          value: '${metrics['totalReturn']?.toStringAsFixed(1) ?? '0.0'}%',
          isPositive: (metrics['totalReturn'] ?? 0) >= 0,
        ),
        _MetricCard(
          label: 'Sharpe Ratio',
          value: metrics['sharpeRatio']?.toStringAsFixed(2) ?? '0.00',
          isPositive: (metrics['sharpeRatio'] ?? 0) >= 1.0,
        ),
        _MetricCard(
          label: 'Max Drawdown',
          value: '${metrics['maxDrawdown']?.toStringAsFixed(1) ?? '0.0'}%',
          isPositive: false,
        ),
        _MetricCard(
          label: 'Win Rate',
          value: '${metrics['winRate']?.toStringAsFixed(1) ?? '0.0'}%',
          isPositive: (metrics['winRate'] ?? 0) >= 50,
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.isPositive});

  final String label;
  final String value;
  final bool isPositive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: AppDimensions.paddingXS),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: isPositive ? AppColors.profit : AppColors.loss,
            ),
          ),
        ],
      ),
    );
  }
}

class _TradeHistory extends StatelessWidget {
  const _TradeHistory({required this.trades});

  final List<Trade> trades;

  @override
  Widget build(BuildContext context) {
    if (trades.isEmpty) {
      return Center(
        child: Column(
          children: [
            const SizedBox(height: AppDimensions.paddingL),
            Icon(Icons.receipt_long_outlined, size: 48, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: AppDimensions.paddingM),
            Text('No trades yet', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
          ],
        ),
      );
    }

    return Column(children: trades.map((t) => _TradeTile(trade: t)).toList());
  }
}

class _TradeTile extends StatelessWidget {
  const _TradeTile({required this.trade});

  final Trade trade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MM/dd');
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    final isBuy = trade.type == TradeType.buy;
    final isProfitable = trade.pnl != null && trade.pnl! >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingS),
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (isBuy ? AppColors.buySignal : AppColors.sellSignal).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isBuy ? Icons.arrow_upward : Icons.arrow_downward,
              color: isBuy ? AppColors.buySignal : AppColors.sellSignal,
              size: 20,
            ),
          ),
          const SizedBox(width: AppDimensions.paddingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isBuy ? 'BUY' : 'SELL',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isBuy ? AppColors.buySignal : AppColors.sellSignal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(trade.ticker, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${trade.shares} shares @ ${currencyFormat.format(trade.price)}',
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
                dateFormat.format(trade.timestamp),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              if (trade.pnl != null)
                Text(
                  '${isProfitable ? '+' : ''}${currencyFormat.format(trade.pnl)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isProfitable ? AppColors.profit : AppColors.loss,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
