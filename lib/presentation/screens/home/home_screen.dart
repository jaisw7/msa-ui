/// Home screen with portfolio overview.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../data/models/alpha_signal.dart';
import '../../../data/models/position.dart';

/// Home screen showing portfolio value and positions summary.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MSA'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // TODO: Implement refresh
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PortfolioValueCard(),
              const SizedBox(height: AppDimensions.paddingL),
              const _SparklineChart(),
              const SizedBox(height: AppDimensions.paddingL),
              _SectionHeader(
                title: 'Positions',
                onSeeAll: () {},
              ),
              const SizedBox(height: AppDimensions.paddingS),
              const _PositionsList(),
              const SizedBox(height: AppDimensions.paddingL),
              _SectionHeader(
                title: 'Recent Signals',
                onSeeAll: () {},
              ),
              const SizedBox(height: AppDimensions.paddingS),
              const _SignalsList(),
            ],
          ),
        ),
      ),
    );
  }
}

class _PortfolioValueCard extends StatelessWidget {
  const _PortfolioValueCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Mock data
    const portfolioValue = 102450.67;
    const dailyPnl = 2450.67;
    const dailyPnlPercent = 2.45;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Portfolio Value',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: AppDimensions.paddingXS),
        Text(
          NumberFormat.currency(symbol: '\$').format(portfolioValue),
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: AppDimensions.paddingXS),
        Row(
          children: [
            Icon(
              dailyPnl >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
              color: dailyPnl >= 0 ? AppColors.profit : AppColors.loss,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              '${NumberFormat.currency(symbol: '\$').format(dailyPnl.abs())} (${dailyPnlPercent.toStringAsFixed(2)}%)',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: dailyPnl >= 0 ? AppColors.profit : AppColors.loss,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Today',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SparklineChart extends StatelessWidget {
  const _SparklineChart();

  @override
  Widget build(BuildContext context) {
    // Mock 7-day data
    final data = [
      100000.0,
      100500.0,
      99800.0,
      101200.0,
      100800.0,
      102000.0,
      102450.0,
    ];

    final minY = data.reduce((a, b) => a < b ? a : b) * 0.998;
    final maxY = data.reduce((a, b) => a > b ? a : b) * 1.002;

    return SizedBox(
      height: AppDimensions.sparklineHeight,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
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
                color: AppColors.chartFill,
              ),
            ),
          ],
          lineTouchData: const LineTouchData(enabled: false),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.onSeeAll,
  });

  final String title;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        TextButton(
          onPressed: onSeeAll,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'See all',
                style: TextStyle(color: theme.colorScheme.primary),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PositionsList extends StatelessWidget {
  const _PositionsList();

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
    ];

    return Column(
      children: positions.map((p) => _PositionTile(position: p)).toList(),
    );
  }
}

class _PositionTile extends StatelessWidget {
  const _PositionTile({required this.position});

  final Position position;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingS),
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
                Text(
                  position.ticker,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${position.shares} shares',
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
                currencyFormat.format(position.currentPrice),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${position.pnlPercent >= 0 ? '+' : ''}${position.pnlPercent.toStringAsFixed(2)}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: position.isProfitable ? AppColors.profit : AppColors.loss,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SignalsList extends StatelessWidget {
  const _SignalsList();

  @override
  Widget build(BuildContext context) {
    // Mock signals
    final signals = [
      AlphaSignal(
        alphaName: 'momentum_20',
        ticker: 'AAPL',
        score: 0.82,
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      AlphaSignal(
        alphaName: 'rsi_14',
        ticker: 'TSLA',
        score: -0.65,
        timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      ),
    ];

    return Column(
      children: signals.map((s) => _SignalTile(signal: s)).toList(),
    );
  }
}

class _SignalTile extends StatelessWidget {
  const _SignalTile({required this.signal});

  final AlphaSignal signal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color signalColor;
    IconData signalIcon;
    switch (signal.signal) {
      case SignalType.buy:
        signalColor = AppColors.buySignal;
        signalIcon = Icons.trending_up;
        break;
      case SignalType.sell:
        signalColor = AppColors.sellSignal;
        signalIcon = Icons.trending_down;
        break;
      case SignalType.hold:
        signalColor = AppColors.holdSignal;
        signalIcon = Icons.horizontal_rule;
        break;
    }

    final timeAgo = _formatTimeAgo(signal.timestamp);

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
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: signalColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              signalIcon,
              color: signalColor,
              size: 18,
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
                      signal.signalLabel,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: signalColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      signal.ticker,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${signal.alphaName} • $timeAgo',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '(${signal.score.toStringAsFixed(2)})',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inHours < 1) {
      return '${diff.inMinutes} min ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hours ago';
    } else {
      return '${diff.inDays} days ago';
    }
  }
}
