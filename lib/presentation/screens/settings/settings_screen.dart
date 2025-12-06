/// Settings screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_dimensions.dart';
import '../../../services/alpaca/alpaca_config.dart';
import '../../../services/auto_trading_config.dart';
import '../../providers/providers.dart';

/// Settings screen for app configuration.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  AutoTradingConfig _autoTradingConfig = AutoTradingConfig.defaultConfig;
  bool _loadingAutoTrading = true;

  @override
  void initState() {
    super.initState();
    _loadAutoTradingConfig();
  }

  Future<void> _loadAutoTradingConfig() async {
    final config = await AutoTradingConfig.load();
    if (mounted) {
      setState(() {
        _autoTradingConfig = config;
        _loadingAutoTrading = false;
      });
    }
  }

  Future<void> _saveAutoTradingConfig(AutoTradingConfig config) async {
    setState(() => _autoTradingConfig = config);
    await config.save();
  }

  @override
  Widget build(BuildContext context) {
    final alpacaConfigAsync = ref.watch(alpacaConfigProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        children: [
          _SettingsSection(
            title: 'API Configuration',
            children: [
              alpacaConfigAsync.when(
                data: (config) => _AlpacaConfigTile(
                  isConfigured: config != null,
                  isPaper: config?.isPaperTrading ?? true,
                  onTap: () => _showAlpacaConfigDialog(context, config),
                ),
                loading: () => const _SettingsTile(
                  icon: Icons.key_outlined,
                  title: 'Alpaca API Key',
                  subtitle: 'Loading...',
                  onTap: null,
                ),
                error: (e, _) => _SettingsTile(
                  icon: Icons.key_outlined,
                  title: 'Alpaca API Key',
                  subtitle: 'Error loading config',
                  onTap: () => _showAlpacaConfigDialog(context, null),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingL),
          _SettingsSection(
            title: 'Auto Trading',
            children: [
              if (_loadingAutoTrading)
                const _SettingsTile(
                  icon: Icons.auto_graph,
                  title: 'Auto Trading',
                  subtitle: 'Loading...',
                  onTap: null,
                )
              else ...[
                SwitchListTile(
                  secondary: Icon(
                    Icons.auto_graph,
                    color: _autoTradingConfig.enabled ? Colors.green : null,
                  ),
                  title: const Text('Enable Auto Trading'),
                  subtitle: Text(_autoTradingConfig.enabled
                      ? 'Trading on signals for ${_autoTradingConfig.tickers.join(", ")}'
                      : 'Disabled - trades require manual execution'),
                  value: _autoTradingConfig.enabled,
                  onChanged: (value) => _saveAutoTradingConfig(
                    _autoTradingConfig.copyWith(enabled: value),
                  ),
                ),
                _SettingsTile(
                  icon: Icons.trending_up,
                  title: 'Buy Threshold',
                  subtitle: 'Signal score > ${_autoTradingConfig.buyThreshold.toStringAsFixed(2)} triggers BUY',
                  onTap: () => _showThresholdDialog(true),
                ),
                _SettingsTile(
                  icon: Icons.trending_down,
                  title: 'Sell Threshold',
                  subtitle: 'Signal score < ${_autoTradingConfig.sellThreshold.toStringAsFixed(2)} triggers SELL',
                  onTap: () => _showThresholdDialog(false),
                ),
                _SettingsTile(
                  icon: Icons.account_balance,
                  title: 'Position Limits',
                  subtitle: 'Max ${_autoTradingConfig.maxPositionSize} shares or \$${_autoTradingConfig.maxPositionValue.toStringAsFixed(0)}',
                  onTap: () => _showPositionLimitsDialog(),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppDimensions.paddingL),
          _SettingsSection(
            title: 'Account',
            children: [
              _SettingsTile(
                icon: Icons.add_circle_outline,
                title: 'Deposit Funds',
                subtitle: 'Add capital to your account',
                onTap: () => _showDepositDialog(context),
              ),
              _SettingsTile(
                icon: Icons.remove_circle_outline,
                title: 'Withdraw Funds',
                subtitle: 'Withdraw capital from your account',
                onTap: () => _showWithdrawDialog(context),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingL),
          _SettingsSection(
            title: 'Data',
            children: [
              _SettingsTile(
                icon: Icons.sync,
                title: 'Refresh Data',
                subtitle: 'Sync positions and market data',
                onTap: () {
                  ref.read(portfolioProvider.notifier).refresh();
                  ref.invalidate(recentTradesProvider);
                  ref.invalidate(allSignalsProvider);
                  ref.invalidate(accountBalanceProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Refreshing data...')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingL),
          _SettingsSection(
            title: 'About',
            children: [
              const _SettingsTile(
                icon: Icons.info_outline,
                title: 'Version',
                subtitle: '1.0.0',
                onTap: null,
              ),
              _SettingsTile(
                icon: Icons.code,
                title: 'MSA Backend',
                subtitle: 'github.com/jaisw7/msa',
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showThresholdDialog(bool isBuy) async {
    final currentValue = isBuy ? _autoTradingConfig.buyThreshold : _autoTradingConfig.sellThreshold;
    double newValue = currentValue;

    final result = await showDialog<double>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${isBuy ? "Buy" : "Sell"} Threshold'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isBuy
                    ? 'Buy when signal score exceeds this value'
                    : 'Sell when signal score falls below this value',
              ),
              const SizedBox(height: 16),
              Slider(
                value: newValue,
                min: isBuy ? 0.5 : -1.0,
                max: isBuy ? 1.0 : -0.5,
                divisions: 10,
                label: newValue.toStringAsFixed(2),
                onChanged: (v) => setDialogState(() => newValue = v),
              ),
              Text(
                newValue.toStringAsFixed(2),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, newValue), child: const Text('Save')),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      await _saveAutoTradingConfig(
        isBuy
            ? _autoTradingConfig.copyWith(buyThreshold: result)
            : _autoTradingConfig.copyWith(sellThreshold: result),
      );
    }
  }

  Future<void> _showPositionLimitsDialog() async {
    final sizeController = TextEditingController(text: _autoTradingConfig.maxPositionSize.toString());
    final valueController = TextEditingController(text: _autoTradingConfig.maxPositionValue.toStringAsFixed(0));

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Position Limits'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: sizeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Max Shares per Position',
                hintText: '100',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: valueController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Max Value per Position (\$)',
                hintText: '10000',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );

    if (result == true && mounted) {
      await _saveAutoTradingConfig(_autoTradingConfig.copyWith(
        maxPositionSize: int.tryParse(sizeController.text) ?? _autoTradingConfig.maxPositionSize,
        maxPositionValue: double.tryParse(valueController.text) ?? _autoTradingConfig.maxPositionValue,
      ));
    }
  }

  Future<void> _showAlpacaConfigDialog(BuildContext context, AlpacaConfig? existing) async {
    final endpointController = TextEditingController(
      text: existing?.endpoint ?? 'https://paper-api.alpaca.markets/v2',
    );
    final apiKeyController = TextEditingController(text: existing?.apiKey ?? '');
    final apiSecretController = TextEditingController(text: existing?.apiSecret ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alpaca API Configuration'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: endpointController,
                decoration: const InputDecoration(
                  labelText: 'API Endpoint',
                  hintText: 'https://paper-api.alpaca.markets/v2',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: apiKeyController,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  hintText: 'PKXXXXXXXXXXXXXXXX',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: apiSecretController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'API Secret',
                  hintText: '••••••••••••••••',
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (existing != null)
            TextButton(
              onPressed: () async {
                await AlpacaConfig.clear();
                if (context.mounted) Navigator.pop(context, true);
              },
              child: const Text('Clear', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (apiKeyController.text.isNotEmpty && apiSecretController.text.isNotEmpty) {
                await AlpacaConfig.save(
                  endpoint: endpointController.text,
                  apiKey: apiKeyController.text,
                  apiSecret: apiSecretController.text,
                );
                if (context.mounted) Navigator.pop(context, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      ref.invalidate(alpacaConfigProvider);
      ref.invalidate(portfolioProvider);
    }
  }

  Future<void> _showDepositDialog(BuildContext context) async {
    final amountController = TextEditingController();
    String? errorText;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Deposit Funds'),
          content: TextField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '\$ ',
              hintText: '0.00',
              hintStyle: TextStyle(color: Theme.of(context).hintColor),
              errorText: errorText,
              labelStyle: errorText != null ? const TextStyle(color: Colors.red) : null,
              floatingLabelStyle: errorText != null ? const TextStyle(color: Colors.red) : null,
              border: const OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
              ),
              errorBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.red),
              ),
              focusedErrorBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.red, width: 2),
              ),
            ),
            autofocus: true,
            onChanged: (_) {
              if (errorText != null) {
                setDialogState(() => errorText = null);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) {
                  setDialogState(() => errorText = 'Please enter a valid amount');
                  return;
                }
                final repo = ref.read(accountRepositoryProvider);
                await repo.deposit(amount);
                if (context.mounted) Navigator.pop(context, true);
              },
              child: const Text('Deposit'),
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      final amountText = amountController.text;
      ref.invalidate(accountBalanceProvider);
      ref.invalidate(accountTransactionsProvider);
      ref.read(portfolioProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deposited \$$amountText')),
        );
      }
    }
  }

  Future<void> _showWithdrawDialog(BuildContext context) async {
    final amountController = TextEditingController();
    String? errorText;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Withdraw Funds'),
          content: TextField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '\$ ',
              hintText: '0.00',
              hintStyle: TextStyle(color: Theme.of(context).hintColor),
              errorText: errorText,
              labelStyle: errorText != null ? const TextStyle(color: Colors.red) : null,
              floatingLabelStyle: errorText != null ? const TextStyle(color: Colors.red) : null,
              border: const OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
              ),
              errorBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.red),
              ),
              focusedErrorBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.red, width: 2),
              ),
            ),
            autofocus: true,
            onChanged: (_) {
              if (errorText != null) {
                setDialogState(() => errorText = null);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) {
                  setDialogState(() => errorText = 'Please enter a valid amount');
                  return;
                }
                final repo = ref.read(accountRepositoryProvider);
                await repo.withdraw(amount);
                if (context.mounted) Navigator.pop(context, true);
              },
              child: const Text('Withdraw'),
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      final amountText = amountController.text;
      ref.invalidate(accountBalanceProvider);
      ref.invalidate(accountTransactionsProvider);
      ref.read(portfolioProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Withdrew \$$amountText')),
        );
      }
    }
  }
}

class _AlpacaConfigTile extends StatelessWidget {
  const _AlpacaConfigTile({
    required this.isConfigured,
    required this.isPaper,
    required this.onTap,
  });

  final bool isConfigured;
  final bool isPaper;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {

    return _SettingsTile(
      icon: Icons.key_outlined,
      title: 'Alpaca API Key',
      subtitle: isConfigured
          ? 'Configured (${isPaper ? "Paper" : "Live"})'
          : 'Not configured - tap to add',
      trailing: isConfigured
          ? Icon(Icons.check_circle, color: Colors.green[400], size: 20)
          : Icon(Icons.warning, color: Colors.orange[400], size: 20),
      onTap: onTap,
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppDimensions.paddingS,
            bottom: AppDimensions.paddingS,
          ),
          child: Text(
            title.toUpperCase(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Row(
          children: [
            Icon(icon, size: 24, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
            const SizedBox(width: AppDimensions.paddingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
            if (onTap != null && trailing == null)
              Icon(Icons.chevron_right, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }
}
