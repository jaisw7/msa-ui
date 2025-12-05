/// Stock detail screen with chart and stats.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../data/models/market_data.dart';
import '../../../data/models/alpha_signal.dart';
import '../../../services/yahoo/yahoo_finance_repository.dart';
import '../../providers/providers.dart';

/// Time range options for the chart.
enum TimeRange { day, week, month, threeMonth, year, all }

/// Stock detail screen showing chart, stats, and signals.
class StockDetailScreen extends ConsumerStatefulWidget {
  const StockDetailScreen({super.key, required this.ticker});

  final String ticker;

  @override
  ConsumerState<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends ConsumerState<StockDetailScreen> {
  TimeRange _selectedRange = TimeRange.month;
  List<MarketData> _chartData = [];
  bool _isLoading = true;
  MarketData? _latestQuote;
  String? _error;

  final _yahooRepo = YahooFinanceRepository();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      debugPrint('StockDetailScreen: Loading data for ${widget.ticker}');
      final data = await _yahooRepo.getHistoricalData(widget.ticker, days: 365);
      debugPrint('StockDetailScreen: Got ${data.length} bars');

      final quote = data.isNotEmpty ? data.last : null;

      setState(() {
        _chartData = data;
        _latestQuote = quote;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('StockDetailScreen: Error loading data: $e');
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  List<MarketData> _getFilteredData() {
    if (_chartData.isEmpty) return [];

    final now = DateTime.now();
    final cutoff = switch (_selectedRange) {
      TimeRange.day => now.subtract(const Duration(days: 1)),
      TimeRange.week => now.subtract(const Duration(days: 7)),
      TimeRange.month => now.subtract(const Duration(days: 30)),
      TimeRange.threeMonth => now.subtract(const Duration(days: 90)),
      TimeRange.year => now.subtract(const Duration(days: 365)),
      TimeRange.all => DateTime(1970),
    };

    return _chartData.where((d) => d.timestamp.isAfter(cutoff)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final signalsAsync = ref.watch(signalsProvider(widget.ticker));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.ticker),
        actions: [
          IconButton(icon: const Icon(Icons.star_border), onPressed: () {}),
          IconButton(icon: const Icon(Icons.share), onPressed: () {}),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                children: [
                  _PriceHeader(ticker: widget.ticker, quote: _latestQuote, chartData: _chartData),
                  const SizedBox(height: AppDimensions.paddingL),
                  _ChartSection(
                    data: _getFilteredData(),
                    selectedRange: _selectedRange,
                    onRangeChanged: (range) => setState(() => _selectedRange = range),
                  ),
                  const SizedBox(height: AppDimensions.paddingL),
                  _StatsSection(quote: _latestQuote, chartData: _chartData),
                  const SizedBox(height: AppDimensions.paddingL),
                  Text('Alpha Signals', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppDimensions.paddingS),
                  signalsAsync.when(
                    data: (signals) => _SignalsSection(signals: signals),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error: $e'),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _TradeButtons(ticker: widget.ticker),
    );
  }
}

class _PriceHeader extends StatelessWidget {
  const _PriceHeader({required this.ticker, required this.quote, required this.chartData});

  final String ticker;
  final MarketData? quote;
  final List<MarketData> chartData;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    final price = quote?.close ?? 0;
    final previousClose = chartData.length > 1 ? chartData[chartData.length - 2].close : price;
    final change = price - previousClose;
    final changePercent = previousClose > 0 ? (change / previousClose) * 100 : 0;
    final isPositive = change >= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(ticker, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: AppDimensions.paddingXS),
        Text(
          currencyFormat.format(price),
          style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppDimensions.paddingXS),
        Row(
          children: [
            Icon(
              isPositive ? Icons.arrow_upward : Icons.arrow_downward,
              color: isPositive ? AppColors.profit : AppColors.loss,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              '${currencyFormat.format(change.abs())} (${changePercent.toStringAsFixed(2)}%)',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isPositive ? AppColors.profit : AppColors.loss,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Text('Today', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
          ],
        ),
      ],
    );
  }
}

class _ChartSection extends StatelessWidget {
  const _ChartSection({required this.data, required this.selectedRange, required this.onRangeChanged});

  final List<MarketData> data;
  final TimeRange selectedRange;
  final ValueChanged<TimeRange> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (data.isEmpty) {
      return SizedBox(
        height: AppDimensions.chartHeight,
        child: const Center(child: Text('No data available')),
      );
    }

    final prices = data.map((d) => d.close).toList();
    final minY = prices.reduce((a, b) => a < b ? a : b) * 0.995;
    final maxY = prices.reduce((a, b) => a > b ? a : b) * 1.005;
    final isPositive = data.last.close >= data.first.close;

    return Column(
      children: [
        SizedBox(
          height: AppDimensions.chartHeight,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              minY: minY,
              maxY: maxY,
              lineBarsData: [
                LineChartBarData(
                  spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.close)).toList(),
                  isCurved: true,
                  color: isPositive ? AppColors.profit : AppColors.loss,
                  barWidth: 2,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        (isPositive ? AppColors.profit : AppColors.loss).withValues(alpha: 0.3),
                        (isPositive ? AppColors.profit : AppColors.loss).withValues(alpha: 0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots.map((spot) {
                    final bar = data[spot.x.toInt()];
                    return LineTooltipItem(
                      '\$${bar.close.toStringAsFixed(2)}\n${DateFormat('MMM d').format(bar.timestamp)}',
                      TextStyle(color: theme.colorScheme.onSurface),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.paddingM),
        _TimeRangeSelector(selected: selectedRange, onChanged: onRangeChanged),
      ],
    );
  }
}

class _TimeRangeSelector extends StatelessWidget {
  const _TimeRangeSelector({required this.selected, required this.onChanged});

  final TimeRange selected;
  final ValueChanged<TimeRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: TimeRange.values.map((range) {
        final label = switch (range) {
          TimeRange.day => '1D',
          TimeRange.week => '1W',
          TimeRange.month => '1M',
          TimeRange.threeMonth => '3M',
          TimeRange.year => '1Y',
          TimeRange.all => 'ALL',
        };
        return _RangeButton(label: label, isSelected: selected == range, onTap: () => onChanged(range));
      }).toList(),
    );
  }
}

class _RangeButton extends StatelessWidget {
  const _RangeButton({required this.label, required this.isSelected, required this.onTap});

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusS),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimensions.radiusS),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface.withValues(alpha: 0.7),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({required this.quote, required this.chartData});

  final MarketData? quote;
  final List<MarketData> chartData;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (quote == null) return const SizedBox.shrink();

    // Calculate stats from chart data
    final volumes = chartData.map((d) => d.volume).toList();
    final avgVolume = volumes.isNotEmpty ? volumes.reduce((a, b) => a + b) / volumes.length : 0;
    final high52w = chartData.isNotEmpty ? chartData.map((d) => d.high).reduce((a, b) => a > b ? a : b) : 0.0;
    final low52w = chartData.isNotEmpty ? chartData.map((d) => d.low).reduce((a, b) => a < b ? a : b) : 0.0;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Statistics', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppDimensions.paddingM),
          Row(
            children: [
              Expanded(child: _StatItem(label: 'Open', value: '\$${quote!.open.toStringAsFixed(2)}')),
              Expanded(child: _StatItem(label: 'High', value: '\$${quote!.high.toStringAsFixed(2)}')),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingS),
          Row(
            children: [
              Expanded(child: _StatItem(label: 'Low', value: '\$${quote!.low.toStringAsFixed(2)}')),
              Expanded(child: _StatItem(label: 'Volume', value: _formatVolume(quote!.volume))),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingS),
          Row(
            children: [
              Expanded(child: _StatItem(label: '52W High', value: '\$${high52w.toStringAsFixed(2)}')),
              Expanded(child: _StatItem(label: '52W Low', value: '\$${low52w.toStringAsFixed(2)}')),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingS),
          Row(
            children: [
              Expanded(child: _StatItem(label: 'Avg Volume', value: _formatVolume(avgVolume.toInt()))),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  String _formatVolume(int volume) {
    if (volume >= 1000000000) return '${(volume / 1000000000).toStringAsFixed(1)}B';
    if (volume >= 1000000) return '${(volume / 1000000).toStringAsFixed(1)}M';
    if (volume >= 1000) return '${(volume / 1000).toStringAsFixed(1)}K';
    return volume.toString();
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _SignalsSection extends StatelessWidget {
  const _SignalsSection({required this.signals});

  final List<AlphaSignal> signals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (signals.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        ),
        child: const Text('No signals available'),
      );
    }

    return Column(
      children: signals.map((signal) {
        final (color, icon) = switch (signal.signal) {
          SignalType.buy => (AppColors.buySignal, Icons.trending_up),
          SignalType.sell => (AppColors.sellSignal, Icons.trending_down),
          SignalType.hold => (AppColors.holdSignal, Icons.horizontal_rule),
        };

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
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: AppDimensions.paddingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(signal.alphaName, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    Text(signal.signalLabel, style: theme.textTheme.bodySmall?.copyWith(color: color)),
                  ],
                ),
              ),
              Text('${signal.score.toStringAsFixed(2)}', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _TradeButtons extends ConsumerWidget {
  const _TradeButtons({required this.ticker});

  final String ticker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alpacaConfig = ref.watch(alpacaConfigProvider);

    // Only show trade buttons if Alpaca is configured
    if (alpacaConfig.valueOrNull == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _showTradeDialog(context, false),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.sellSignal),
              child: const Text('SELL'),
            ),
          ),
          const SizedBox(width: AppDimensions.paddingM),
          Expanded(
            child: FilledButton(
              onPressed: () => _showTradeDialog(context, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.buySignal),
              child: const Text('BUY'),
            ),
          ),
        ],
      ),
    );
  }

  void _showTradeDialog(BuildContext context, bool isBuy) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${isBuy ? "Buy" : "Sell"} $ticker'),
        content: const Text('Trading feature coming soon!'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }
}
