/// Settings screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_dimensions.dart';
import '../../../services/alpaca/alpaca_config.dart';
import '../../providers/providers.dart';

/// Settings screen for app configuration.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
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
