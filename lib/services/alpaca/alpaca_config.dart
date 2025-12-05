/// Alpaca API configuration.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Alpaca API configuration loaded from secure storage or file.
class AlpacaConfig {
  const AlpacaConfig({
    required this.endpoint,
    required this.apiKey,
    required this.apiSecret,
  });

  final String endpoint;
  final String apiKey;
  final String apiSecret;

  static const _storage = FlutterSecureStorage();
  static const _keyEndpoint = 'alpaca_endpoint';
  static const _keyApiKey = 'alpaca_api_key';
  static const _keyApiSecret = 'alpaca_api_secret';

  /// Load configuration from secure storage (mobile) or file (desktop).
  static Future<AlpacaConfig?> load() async {
    // Try secure storage first (works on all platforms)
    final fromStorage = await _loadFromSecureStorage();
    if (fromStorage != null) return fromStorage;

    // Fall back to file on desktop (for development)
    if (!kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
      return _loadFromFile();
    }

    return null;
  }

  /// Load from Flutter Secure Storage.
  static Future<AlpacaConfig?> _loadFromSecureStorage() async {
    try {
      final endpoint = await _storage.read(key: _keyEndpoint);
      final apiKey = await _storage.read(key: _keyApiKey);
      final apiSecret = await _storage.read(key: _keyApiSecret);

      if (endpoint == null || apiKey == null || apiSecret == null) {
        return null;
      }

      return AlpacaConfig(
        endpoint: endpoint,
        apiKey: apiKey,
        apiSecret: apiSecret,
      );
    } catch (e) {
      return null;
    }
  }

  /// Load from ~/.alpaca_api_key file (desktop only).
  static Future<AlpacaConfig?> _loadFromFile() async {
    try {
      final homeDir = Platform.environment['HOME'] ?? '';
      final configFile = File('$homeDir/.alpaca_api_key');

      if (!await configFile.exists()) {
        return null;
      }

      final lines = await configFile.readAsLines();
      final config = <String, String>{};

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

        final parts = trimmed.split('=');
        if (parts.length >= 2) {
          final key = parts[0].trim();
          final value = parts.sublist(1).join('=').trim();
          config[key] = value;
        }
      }

      final endpoint = config['ENDPOINT'];
      final apiKey = config['API_KEY'];
      final apiSecret = config['API_SECRET'];

      if (endpoint == null || apiKey == null || apiSecret == null) {
        return null;
      }

      return AlpacaConfig(
        endpoint: endpoint,
        apiKey: apiKey,
        apiSecret: apiSecret,
      );
    } catch (e) {
      return null;
    }
  }

  /// Save configuration to secure storage.
  static Future<void> save({
    required String endpoint,
    required String apiKey,
    required String apiSecret,
  }) async {
    await _storage.write(key: _keyEndpoint, value: endpoint);
    await _storage.write(key: _keyApiKey, value: apiKey);
    await _storage.write(key: _keyApiSecret, value: apiSecret);
  }

  /// Clear saved configuration.
  static Future<void> clear() async {
    await _storage.delete(key: _keyEndpoint);
    await _storage.delete(key: _keyApiKey);
    await _storage.delete(key: _keyApiSecret);
  }

  /// Check if configuration exists.
  static Future<bool> exists() async {
    final apiKey = await _storage.read(key: _keyApiKey);
    return apiKey != null;
  }

  /// Check if this is a paper trading account.
  bool get isPaperTrading => endpoint.contains('paper');
}
