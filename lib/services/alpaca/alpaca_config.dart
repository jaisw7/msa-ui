/// Alpaca API configuration.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Alpaca API configuration loaded from secure storage.
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

  /// Load configuration from secure storage.
  static Future<AlpacaConfig?> load() async {
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
