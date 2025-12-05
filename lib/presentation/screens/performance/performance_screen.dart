/// Performance screen with metrics and equity curve.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../data/models/trade.dart';

/// Performance screen showing equity curve and metrics.
class PerformanceScreen extends StatelessWidget {
  const PerformanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _EquityCurve(),
            const SizedBox(height: AppDimensions.paddingL),
            const _MetricsGrid(),
            const SizedBox(height: AppDimensions.paddingL),
            Text(
              'Trade History',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppDimensions.paddingM),
            const _TradeHistory(),
          ],
        ),
      ),
    );
  }
}

class _EquityCurve extends StatelessWidget {
  const _EquityCurve();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Mock equity curve data (30 days)
    final data = <double>[
      100000,
      100200,
      99800,
      100500,
      101000,
      100800,
      101500,
      102000,
      101800,
      102200,
      102500,
      102000,
      102800,
      103200,
      103000,
      103500,
      103800,
      103200,
      104000,
      104500,
      104200,
      104800,
      105000,
      104500,
      105200,
      105800,
      105500,
      106000,
      106500,
      107000,
    ];

    final minY = data.reduce((a, b) => a < b ? a : b) * 0.995;
    final maxY = data.reduce((a, b) => a > b ? a : b) * 1.005;

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
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: AppDimensions.paddingS),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY - minY) / 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AppColors.chartGrid.withOpacity(0.2),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minY: minY,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: data.asMap().entries.map((e) {
                      return FlSpot(e.key.toDouble(), e.value);
                    }).toList(),
                    isCurved: true,
                    color: AppColors.chartLine,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.chartFill,
                          AppColors.chartFill.withOpacity(0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppDimensions.paddingM,
      mainAxisSpacing: AppDimensions.paddingM,
      childAspectRatio: 1.6,
      children: const [
        _MetricCard(label: 'Total Return', value: '+7.0%', isPositive: true),
        _MetricCard(label: 'Sharpe Ratio', value: '1.42', isPositive: true),
        _MetricCard(label: 'Max Drawdown', value: '-3.2%', isPositive: false),
        _MetricCard(label: 'Win Rate', value: '58.3%', isPositive: true),
        _MetricCard(label: 'Total Trades', value: '24', isPositive: null),
        _MetricCard(label: 'Avg P&L/Trade', value: '+\$102', isPositive: true),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.isPositive,
  });

  final String label;
  final String value;
  final bool? isPositive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color valueColor;
    if (isPositive == null) {
      valueColor = theme.colorScheme.onSurface;
    } else {
      valueColor = isPositive! ? AppColors.profit : AppColors.loss;
    }

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
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: AppDimensions.paddingXS),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _TradeHistory extends StatelessWidget {
  const _TradeHistory();

  @override
  Widget build(BuildContext context) {
    // Mock trades
    final trades = [
      Trade(
        id: '1',
        ticker: 'AAPL',
        type: TradeType.buy,
        shares: 10,
        price: 173.50,
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        signal: 'momentum_20',
        pnl: 125.50,
      ),
      Trade(
        id: '2',
        ticker: 'MSFT',
        type: TradeType.sell,
        shares: 5,
        price: 378.20,
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        signal: 'rsi_14',
        pnl: -45.20,
      ),
      Trade(
        id: '3',
        ticker: 'GOOGL',
        type: TradeType.buy,
        shares: 8,
        price: 142.00,
        timestamp: DateTime.now().subtract(const Duration(days: 3)),
        signal: 'ml_xgboost',
        pnl: 230.00,
      ),
    ];

    return Column(
      children: trades.map((t) => _TradeTile(trade: t)).toList(),
    );
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
              color: (isBuy ? AppColors.buySignal : AppColors.sellSignal)
                  .withOpacity(0.15),
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
                    Text(
                      trade.ticker,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${trade.shares} shares @ ${currencyFormat.format(trade.price)}',
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
                dateFormat.format(trade.timestamp),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
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
