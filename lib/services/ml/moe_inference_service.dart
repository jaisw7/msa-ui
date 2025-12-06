import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

/// Configuration for a Mixture of Experts model.
class MoeConfig {
  final int nRegimes;
  final String gatingModelPath;
  final List<String> gatingFeatures;
  final Map<int, String> expertPaths;
  final List<String> alphaFeatures;
  final Map<String, RegimeStats> regimeStats;

  MoeConfig({
    required this.nRegimes,
    required this.gatingModelPath,
    required this.gatingFeatures,
    required this.expertPaths,
    required this.alphaFeatures,
    required this.regimeStats,
  });

  factory MoeConfig.fromJson(Map<String, dynamic> json, String basePath) {
    final experts = (json['experts'] as Map<String, dynamic>)
        .map((key, value) => MapEntry(int.parse(key), '$basePath/$value'));

    final stats = (json['regime_stats'] as Map<String, dynamic>)
        .map((key, value) => MapEntry(key, RegimeStats.fromJson(value)));

    return MoeConfig(
      nRegimes: json['n_regimes'] as int,
      gatingModelPath: '$basePath/${json['gating_model']}',
      gatingFeatures: List<String>.from(json['gating_features'] as List),
      expertPaths: experts,
      alphaFeatures: List<String>.from(json['alpha_features'] as List),
      regimeStats: stats,
    );
  }
}

/// Statistics for a regime.
class RegimeStats {
  final int count;
  final double meanReturn;
  final double stdReturn;
  final double dispersionAvg;

  RegimeStats({
    required this.count,
    required this.meanReturn,
    required this.stdReturn,
    required this.dispersionAvg,
  });

  factory RegimeStats.fromJson(Map<String, dynamic> json) {
    return RegimeStats(
      count: json['count'] as int,
      meanReturn: (json['mean_return'] as num).toDouble(),
      stdReturn: (json['std_return'] as num).toDouble(),
      dispersionAvg: (json['dispersion_avg'] as num).toDouble(),
    );
  }
}

/// Service for running Mixture of Experts inference.
///
/// The MoE model consists of:
/// - A gating network that predicts which regime/expert to use
/// - Multiple expert models, one per regime
class MoeInferenceService {
  MoeConfig? _config;
  OrtSession? _gatingSession;
  Map<int, OrtSession> _expertSessions = {};
  bool _isInitialized = false;

  /// Whether the service is ready for inference.
  bool get isInitialized => _isInitialized;

  /// The MoE configuration.
  MoeConfig? get config => _config;

  /// Load an MoE model from assets.
  ///
  /// [configPath] - Path to the _config.json file
  Future<void> loadModel(String configPath) async {
    // Load config
    final configJson = await rootBundle.loadString(configPath);
    final configData = jsonDecode(configJson) as Map<String, dynamic>;
    final basePath = configPath.substring(0, configPath.lastIndexOf('/'));
    _config = MoeConfig.fromJson(configData, basePath);

    final sessionOptions = OrtSessionOptions();

    // Load gating network
    final gatingBytes = await rootBundle.load(_config!.gatingModelPath);
    _gatingSession = OrtSession.fromBuffer(
      gatingBytes.buffer.asUint8List(),
      sessionOptions,
    );

    // Load expert models
    _expertSessions = {};
    for (final entry in _config!.expertPaths.entries) {
      final expertBytes = await rootBundle.load(entry.value);
      _expertSessions[entry.key] = OrtSession.fromBuffer(
        expertBytes.buffer.asUint8List(),
        sessionOptions,
      );
    }

    _isInitialized = true;
  }

  /// Run the gating network to determine the regime.
  ///
  /// [regimeFeatures] - Features for regime detection (8 features by default)
  Future<int> predictRegime(List<double> regimeFeatures) async {
    if (!_isInitialized || _gatingSession == null) {
      throw StateError('Model not loaded. Call loadModel() first.');
    }

    final inputShape = [1, regimeFeatures.length];
    final inputData = Float32List.fromList(regimeFeatures);
    final inputTensor = OrtValueTensor.createTensorWithDataList(
      inputData,
      inputShape,
    );

    final inputName = _gatingSession!.inputNames.first;
    final runOptions = OrtRunOptions();
    final outputs = await _gatingSession!.runAsync(
      runOptions,
      {inputName: inputTensor},
    );

    // KMeans outputs cluster assignment
    final outputTensor = outputs?.first?.value;
    int regime;
    if (outputTensor is List) {
      regime = (outputTensor.first as num).toInt();
    } else {
      regime = (outputTensor as num).toInt();
    }

    // Cleanup
    inputTensor.release();
    outputs?.forEach((e) => e?.release());
    runOptions.release();

    return regime;
  }

  /// Run a specific expert model.
  ///
  /// [regime] - The regime/expert index
  /// [alphaFeatures] - The alpha scores to feed to the expert
  Future<double> runExpert(int regime, List<double> alphaFeatures) async {
    if (!_isInitialized) {
      throw StateError('Model not loaded. Call loadModel() first.');
    }

    final session = _expertSessions[regime];
    if (session == null) {
      throw ArgumentError('No expert for regime $regime');
    }

    final inputShape = [1, alphaFeatures.length];
    final inputData = Float32List.fromList(alphaFeatures);
    final inputTensor = OrtValueTensor.createTensorWithDataList(
      inputData,
      inputShape,
    );

    final inputName = session.inputNames.first;
    final runOptions = OrtRunOptions();
    final outputs = await session.runAsync(
      runOptions,
      {inputName: inputTensor},
    );

    // Extract prediction
    final outputTensor = outputs?.first?.value as List<dynamic>;
    final prediction = (outputTensor.first as num).toDouble();

    // Cleanup
    inputTensor.release();
    outputs?.forEach((e) => e?.release());
    runOptions.release();

    return prediction;
  }

  /// Run the full MoE inference pipeline.
  ///
  /// [regimeFeatures] - Features for regime detection
  /// [alphaFeatures] - Alpha scores for the expert
  Future<MoePrediction> predict({
    required List<double> regimeFeatures,
    required List<double> alphaFeatures,
  }) async {
    final regime = await predictRegime(regimeFeatures);
    final prediction = await runExpert(regime, alphaFeatures);

    return MoePrediction(
      regime: regime,
      prediction: prediction,
      regimeStats: _config?.regimeStats[regime.toString()],
    );
  }

  /// Dispose of all loaded models.
  void dispose() {
    _gatingSession?.release();
    _gatingSession = null;
    for (final session in _expertSessions.values) {
      session.release();
    }
    _expertSessions = {};
    _isInitialized = false;
  }
}

/// Result of MoE inference.
class MoePrediction {
  final int regime;
  final double prediction;
  final RegimeStats? regimeStats;

  MoePrediction({
    required this.regime,
    required this.prediction,
    this.regimeStats,
  });

  @override
  String toString() {
    return 'MoePrediction(regime: $regime, prediction: $prediction)';
  }
}
