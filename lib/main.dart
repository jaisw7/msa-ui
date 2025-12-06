/// MSA Mobile App entry point.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'services/alpaca/alpaca_config.dart';
import 'services/auto_trading_config.dart';
import 'presentation/providers/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Seed Alpaca config from environment variables (for dev)
  await _seedAlpacaConfigFromEnv();

  runApp(
    ProviderScope(
      child: _AppWithServices(),
    ),
  );
}

/// Wrapper widget that initializes background services.
class _AppWithServices extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AppWithServices> createState() => _AppWithServicesState();
}

class _AppWithServicesState extends ConsumerState<_AppWithServices>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Start background services after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startBackgroundServices();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopBackgroundServices();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startBackgroundServices();
    } else if (state == AppLifecycleState.paused) {
      _stopBackgroundServices();
    }
  }

  void _startBackgroundServices() {
    final snapshotService = ref.read(performanceSnapshotServiceProvider);
    snapshotService.start();
    debugPrint('Background services started');
  }

  void _stopBackgroundServices() {
    final snapshotService = ref.read(performanceSnapshotServiceProvider);
    snapshotService.stop();
    debugPrint('Background services stopped');
  }

  @override
  Widget build(BuildContext context) {
    return const MsaApp();
  }
}

/// Seed Alpaca configuration from environment variables if not already set.
/// This allows dev builds to auto-configure from .env via Makefile.
/// Only runs in debug mode for security.
Future<void> _seedAlpacaConfigFromEnv() async {
  // Only seed in debug mode (dev builds)
  if (!kDebugMode) return;

  // Skip on web (no Platform.environment)
  if (kIsWeb) return;

  // Check if already configured
  if (await AlpacaConfig.exists()) return;

  // Check for env vars
  final env = Platform.environment;
  final endpoint = env['ALPACA_ENDPOINT'];
  final apiKey = env['ALPACA_API_KEY'];
  final apiSecret = env['ALPACA_API_SECRET'];

  if (endpoint != null && apiKey != null && apiSecret != null) {
    await AlpacaConfig.save(
      endpoint: endpoint,
      apiKey: apiKey,
      apiSecret: apiSecret,
    );
    // ignore: avoid_print
    print('AlpacaConfig: Seeded from environment variables');
  }
}
