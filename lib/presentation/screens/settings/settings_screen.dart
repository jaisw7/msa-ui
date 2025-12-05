/// Settings screen.
library;

import 'package:flutter/material.dart';

import '../../../core/constants/app_dimensions.dart';

/// Settings screen for app configuration.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        children: [
          _SettingsSection(
            title: 'API Configuration',
            children: [
              _SettingsTile(
                icon: Icons.key_outlined,
                title: 'Alpaca API Key',
                subtitle: 'Configure your paper trading credentials',
                onTap: () {
                  // TODO: Implement API key configuration
                },
              ),
              _SettingsTile(
                icon: Icons.refresh,
                title: 'Refresh Interval',
                subtitle: '5 minutes',
                onTap: () {
                  // TODO: Implement refresh interval picker
                },
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingL),
          _SettingsSection(
            title: 'Appearance',
            children: [
              _SettingsTile(
                icon: Icons.dark_mode_outlined,
                title: 'Theme',
                subtitle: 'Dark',
                onTap: () {
                  // TODO: Implement theme switcher
                },
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingL),
          _SettingsSection(
            title: 'Data',
            children: [
              _SettingsTile(
                icon: Icons.sync,
                title: 'Sync with Alpaca',
                subtitle: 'Last synced: Never',
                onTap: () {
                  // TODO: Implement sync
                },
              ),
              _SettingsTile(
                icon: Icons.delete_outline,
                title: 'Clear Local Data',
                subtitle: 'Remove all cached data',
                onTap: () {
                  // TODO: Implement clear data
                },
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingL),
          _SettingsSection(
            title: 'About',
            children: [
              _SettingsTile(
                icon: Icons.info_outline,
                title: 'Version',
                subtitle: '1.0.0',
                onTap: null,
              ),
              _SettingsTile(
                icon: Icons.code,
                title: 'MSA Backend',
                subtitle: 'github.com/jaisw7/msa',
                onTap: () {
                  // TODO: Open link
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.children,
  });

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
              color: theme.colorScheme.onSurface.withOpacity(0.5),
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
          child: Column(
            children: children,
          ),
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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

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
            Icon(
              icon,
              size: 24,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
            const SizedBox(width: AppDimensions.paddingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withOpacity(0.3),
              ),
          ],
        ),
      ),
    );
  }
}
