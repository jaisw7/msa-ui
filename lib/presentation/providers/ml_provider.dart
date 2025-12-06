/// ML inference provider for stock predictions.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/ml/inference_service.dart';

/// Single global inference service instance.
final _inferenceService = InferenceService();

/// Whether the ONNX runtime has been initialized.
bool _ortInitialized = false;

/// Initialize ONNX runtime (call once at app startup).
Future<void> initializeOnnxRuntime() async {
  if (!_ortInitialized) {
    await InferenceService.initializeOrt();
    _ortInitialized = true;
  }
}

/// Provider for the inference service.
final inferenceServiceProvider = Provider<InferenceService>((ref) {
  return _inferenceService;
});

/// Whether a model is loaded for a given ticker.
final modelLoadedProvider = StateProvider.family<bool, String>((ref, ticker) {
  return false;
});

/// ML prediction result.
class MlPrediction {
  final double value;
  final String modelName;
  final DateTime timestamp;

  MlPrediction({
    required this.value,
    required this.modelName,
    required this.timestamp,
  });

  /// Interpret prediction as a signal direction.
  String get signalLabel {
    if (value > 0.5) return 'Bullish';
    if (value < -0.5) return 'Bearish';
    return 'Neutral';
  }

  /// Get signal color based on prediction.
  bool get isBullish => value > 0;
}

/// Load and run inference for a ticker.
/// Returns null if model is not available.
Future<MlPrediction?> runInference(
  InferenceService service,
  String ticker,
  List<double> features,
) async {
  try {
    // Try to load the model if not already loaded
    if (!service.isInitialized || service.modelName != '${ticker}_xgboost') {
      await service.loadModel('assets/models/${ticker}_xgboost.onnx');
    }

    final result = await service.predict(features);
    return MlPrediction(
      value: result.isNotEmpty ? result.first : 0,
      modelName: service.modelName ?? 'unknown',
      timestamp: DateTime.now(),
    );
  } catch (e) {
    // Model not available for this ticker - return null gracefully
    return null;
  }
}
