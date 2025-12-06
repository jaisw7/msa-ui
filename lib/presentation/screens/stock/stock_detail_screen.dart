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
import '../../../data/models/trade.dart';
import '../../../services/market_data_service.dart';
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
  TimeRange _selectedRange = TimeRange.day;  // Default to 1D
  List<MarketData> _chartData = [];
  bool _isLoading = true;
  MarketData? _latestQuote;
  MarketData? _hoveredData;  // Track hovered point for interactive header

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Get appropriate interval and days for the selected time range.
  (DataInterval, int) _getIntervalForRange() {
    return switch (_selectedRange) {
      TimeRange.day => (DataInterval.oneMinute, 1),
      TimeRange.week => (DataInterval.oneMinute, 7),
      TimeRange.month => (DataInterval.oneHour, 30),
      TimeRange.threeMonth => (DataInterval.oneHour, 90),
      TimeRange.year => (DataInterval.oneDay, 365),
      TimeRange.all => (DataInterval.oneDay, 365 * 5),
    };
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final (interval, days) = _getIntervalForRange();

      // ignore: avoid_print
      print('StockDetailScreen: Loading ${widget.ticker} (${interval.value}, ${days}d)');

      // Use Yahoo Finance (includes pre/post market with includePrePost=true)
      final service = MarketDataService(interval: interval);
      final data = await service.getData(widget.ticker, days: days);

      // ignore: avoid_print
      print('StockDetailScreen: Got ${data.length} bars');

      final quote = data.isNotEmpty ? data.last : null;

      setState(() {
        _chartData = data;
        _latestQuote = quote;
        _isLoading = false;
      });
    } catch (e) {
      // ignore: avoid_print
      print('StockDetailScreen: Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  List<MarketData> _getFilteredData() {
    if (_chartData.isEmpty) return [];

    // For 1D range, show most recent trading day's data
    if (_selectedRange == TimeRange.day) {
      if (_chartData.isNotEmpty) {
        final lastBar = _chartData.last;
        final lastDayMidnight = DateTime(lastBar.timestamp.year, lastBar.timestamp.month, lastBar.timestamp.day);
        return _chartData.where((d) =>
          d.timestamp.isAfter(lastDayMidnight) ||
          d.timestamp.isAtSameMomentAs(lastDayMidnight)
        ).toList();
      }
      return [];
    }

    final now = DateTime.now();

    // Note: 1m data only has 7 days max, so 1M/3M/1Y will show all available data
    final cutoff = switch (_selectedRange) {
      TimeRange.day => DateTime(now.year, now.month, now.day), // Won't reach here
      TimeRange.week => now.subtract(const Duration(days: 7)),
      TimeRange.month => now.subtract(const Duration(days: 30)),
      TimeRange.threeMonth => now.subtract(const Duration(days: 90)),
      TimeRange.year => now.subtract(const Duration(days: 365)),
      TimeRange.all => DateTime(1970),
    };

    final filtered = _chartData.where((d) => d.timestamp.isAfter(cutoff)).toList();
    // If filtered is empty but we have data, show all (1m data may not cover full range)
    return filtered.isEmpty ? _chartData : filtered;
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
                  _PriceHeader(
                    ticker: widget.ticker,
                    quote: _latestQuote,
                    chartData: _getFilteredData(),
                    hoveredData: _hoveredData,
                    selectedRange: _selectedRange,
                  ),
                  const SizedBox(height: AppDimensions.paddingL),
                  _ChartSection(
                    data: _getFilteredData(),
                    selectedRange: _selectedRange,
                    onRangeChanged: (range) {
                      if (range != _selectedRange) {
                        setState(() => _selectedRange = range);
                        _loadData();  // Reload with appropriate interval
                      }
                    },
                    onHover: (data) => setState(() => _hoveredData = data),
                  ),
                  const SizedBox(height: AppDimensions.paddingL),
                  _StatsSection(quote: _latestQuote, chartData: _getFilteredData(), selectedRange: _selectedRange),
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
      bottomNavigationBar: _TradeButtons(ticker: widget.ticker, currentPrice: _latestQuote?.close),
    );
  }
}

class _PriceHeader extends StatelessWidget {
  const _PriceHeader({
    required this.ticker,
    required this.quote,
    required this.chartData,
    this.hoveredData,
    required this.selectedRange,
  });

  final String ticker;
  final MarketData? quote;
  final List<MarketData> chartData;
  final MarketData? hoveredData;
  final TimeRange selectedRange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    // Use hovered data if available, otherwise use latest quote
    final displayData = hoveredData ?? quote;
    final price = displayData?.close ?? 0;

    // Reference price: first bar of the day (12AM) for 1D, or first bar of range
    final referencePrice = chartData.isNotEmpty ? chartData.first.close : price;
    final change = price - referencePrice;
    final changePercent = referencePrice > 0 ? (change / referencePrice) * 100 : 0;
    final isPositive = change >= 0;

    // Format time for hovered point
    String? timeLabel;
    if (hoveredData != null) {
      if (selectedRange == TimeRange.day) {
        timeLabel = DateFormat('h:mm a').format(hoveredData!.timestamp);
      } else {
        timeLabel = DateFormat('h:mm a, MMM d').format(hoveredData!.timestamp);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(ticker, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
            if (timeLabel != null) ...[
              const SizedBox(width: 8),
              Text(
                timeLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ],
        ),
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
              '${isPositive ? "+" : ""}${currencyFormat.format(change)} (${isPositive ? "+" : ""}${changePercent.toStringAsFixed(2)}%)',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isPositive ? AppColors.profit : AppColors.loss,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              hoveredData != null ? 'vs Open' : 'Today',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ChartSection extends StatelessWidget {
  const _ChartSection({
    required this.data,
    required this.selectedRange,
    required this.onRangeChanged,
    required this.onHover,
  });

  final List<MarketData> data;
  final TimeRange selectedRange;
  final ValueChanged<TimeRange> onRangeChanged;
  final ValueChanged<MarketData?> onHover;

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
                handleBuiltInTouches: true,
                touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
                  // Clear hover on any end/exit event
                  if (event is FlTapUpEvent ||
                      event is FlPanEndEvent ||
                      event is FlLongPressEnd ||
                      event is FlPointerExitEvent ||
                      response == null ||
                      response.lineBarSpots == null ||
                      response.lineBarSpots!.isEmpty) {
                    onHover(null);
                    return;
                  }

                  // Touch active - update hover
                  final spot = response.lineBarSpots!.first;
                  final index = spot.x.toInt();
                  if (index >= 0 && index < data.length) {
                    onHover(data[index]);
                  }
                },
                touchTooltipData: LineTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItems: (spots) => spots.map((spot) {
                    final bar = data[spot.x.toInt()];

                    // Format time based on selected range
                    final String timeStr;
                    if (selectedRange == TimeRange.day) {
                      // 1D: Show time only (12-hour format)
                      timeStr = DateFormat('h:mm a').format(bar.timestamp);
                    } else {
                      // 1W+: Show time and date
                      timeStr = DateFormat('h:mm a, MMM d').format(bar.timestamp);
                    }

                    return LineTooltipItem(
                      timeStr,
                      TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
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
  const _StatsSection({required this.quote, required this.chartData, required this.selectedRange});

  final MarketData? quote;
  final List<MarketData> chartData;
  final TimeRange selectedRange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (quote == null || chartData.isEmpty) return const SizedBox.shrink();

    // Calculate stats from chart data (not just the last bar)
    final volumes = chartData.map((d) => d.volume).toList();
    final avgVolume = volumes.isNotEmpty ? volumes.reduce((a, b) => a + b) / volumes.length : 0;
    final totalVolume = volumes.isNotEmpty ? volumes.reduce((a, b) => a + b) : 0;

    // Open = first bar's open, High/Low = range extremes
    final rangeOpen = chartData.first.open;
    final rangeHigh = chartData.map((d) => d.high).reduce((a, b) => a > b ? a : b);
    final rangeLow = chartData.map((d) => d.low).reduce((a, b) => a < b ? a : b);
    final rangeClose = chartData.last.close;

    // Label based on selected range
    final rangeLabel = switch (selectedRange) {
      TimeRange.day => 'Day',
      TimeRange.week => 'Week',
      TimeRange.month => 'Month',
      TimeRange.threeMonth => '3M',
      TimeRange.year => '52W',
      TimeRange.all => 'All',
    };

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
              Expanded(child: _StatItem(label: 'Open', value: '\$${rangeOpen.toStringAsFixed(2)}')),
              Expanded(child: _StatItem(label: '$rangeLabel High', value: '\$${rangeHigh.toStringAsFixed(2)}')),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingS),
          Row(
            children: [
              Expanded(child: _StatItem(label: 'Close', value: '\$${rangeClose.toStringAsFixed(2)}')),
              Expanded(child: _StatItem(label: '$rangeLabel Low', value: '\$${rangeLow.toStringAsFixed(2)}')),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingS),
          Row(
            children: [
              Expanded(child: _StatItem(label: 'Volume', value: _formatVolume(totalVolume))),
              Expanded(child: _StatItem(label: 'Avg Volume', value: _formatVolume(avgVolume.toInt()))),
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
  const _TradeButtons({required this.ticker, required this.currentPrice});

  final String ticker;
  final double? currentPrice;

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
              onPressed: () => _showTradeDialog(context, ref, false),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.sellSignal),
              child: const Text('SELL'),
            ),
          ),
          const SizedBox(width: AppDimensions.paddingM),
          Expanded(
            child: FilledButton(
              onPressed: () => _showTradeDialog(context, ref, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.buySignal),
              child: const Text('BUY'),
            ),
          ),
        ],
      ),
    );
  }

  void _showTradeDialog(BuildContext context, WidgetRef ref, bool isBuy) {
    showDialog(
      context: context,
      builder: (context) => _TradeDialog(
        ticker: ticker,
        isBuy: isBuy,
        currentPrice: currentPrice,
      ),
    );
  }
}

class _TradeDialog extends ConsumerStatefulWidget {
  const _TradeDialog({
    required this.ticker,
    required this.isBuy,
    this.currentPrice,
  });

  final String ticker;
  final bool isBuy;
  final double? currentPrice;

  @override
  ConsumerState<_TradeDialog> createState() => _TradeDialogState();
}

class _TradeDialogState extends ConsumerState<_TradeDialog> {
  final _quantityController = TextEditingController(text: '1');
  bool _isSubmitting = false;
  String? _error;

  int get _quantity => int.tryParse(_quantityController.text) ?? 0;
  double get _estimatedValue => _quantity * (widget.currentPrice ?? 0);

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _submitOrder() async {
    if (_quantity <= 0) {
      setState(() => _error = 'Enter a valid quantity');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final tradingRepo = ref.read(tradingRepoProvider);
      if (tradingRepo == null) {
        throw Exception('Trading not configured');
      }

      // Create and save the trade (this submits to Alpaca)
      final trade = Trade(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        ticker: widget.ticker,
        type: widget.isBuy ? TradeType.buy : TradeType.sell,
        shares: _quantity,
        price: widget.currentPrice ?? 0,
        timestamp: DateTime.now(),
        signal: 'manual',
        pnl: null,
      );

      await tradingRepo.saveTrade(trade);

      // Refresh positions
      ref.invalidate(positionsProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.isBuy ? "Bought" : "Sold"} $_quantity shares of ${widget.ticker}'),
            backgroundColor: widget.isBuy ? AppColors.buySignal : AppColors.sellSignal,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            widget.isBuy ? Icons.arrow_upward : Icons.arrow_downward,
            color: widget.isBuy ? AppColors.buySignal : AppColors.sellSignal,
          ),
          const SizedBox(width: 8),
          Text('${widget.isBuy ? "Buy" : "Sell"} ${widget.ticker}'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current price
          if (widget.currentPrice != null)
            Text(
              'Current Price: ${currencyFormat.format(widget.currentPrice)}',
              style: theme.textTheme.bodyMedium,
            ),
          const SizedBox(height: 16),

          // Quantity input
          TextField(
            controller: _quantityController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Quantity (shares)',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // Estimated value
          Text(
            'Estimated Value: ${currencyFormat.format(_estimatedValue)}',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),

          // Error message
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submitOrder,
          style: FilledButton.styleFrom(
            backgroundColor: widget.isBuy ? AppColors.buySignal : AppColors.sellSignal,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(widget.isBuy ? 'BUY' : 'SELL'),
        ),
      ],
    );
  }
}

