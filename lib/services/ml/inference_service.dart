import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

/// Service for running ONNX model inference.
///
/// Supports both individual models (XGBoost, LinearModel)
/// and Mixture of Experts (MoE) models.
class InferenceService {
  OrtSession? _session;
  List<String>? _featureNames;
  String? _modelName;
  bool _isInitialized = false;

  /// Whether the service is ready for inference.
  bool get isInitialized => _isInitialized;

  /// The list of feature names expected by the model.
  List<String>? get featureNames => _featureNames;

  /// The name of the loaded model.
  String? get modelName => _modelName;

  /// Initialize the ONNX environment (call once at app startup).
  static Future<void> initializeOrt() async {
    OrtEnv.instance.init();
  }

  /// Dispose of the ONNX environment (call at app shutdown).
  static void disposeOrt() {
    OrtEnv.instance.release();
  }

  /// Load an ONNX model from assets.
  ///
  /// [modelPath] - Path to the .onnx file (e.g., 'assets/models/AAPL_xgboost.onnx')
  /// [featuresPath] - Path to the _features.json file (optional, auto-detected if not provided)
  Future<void> loadModel(String modelPath, {String? featuresPath}) async {
    // Load ONNX model
    final modelBytes = await rootBundle.load(modelPath);
    final modelData = modelBytes.buffer.asUint8List();

    final sessionOptions = OrtSessionOptions();
    _session = OrtSession.fromBuffer(modelData, sessionOptions);

    // Load feature names
    featuresPath ??= modelPath.replaceAll('.onnx', '_features.json');
    try {
      final featuresJson = await rootBundle.loadString(featuresPath);
      final features = jsonDecode(featuresJson) as Map<String, dynamic>;
      _featureNames = List<String>.from(features['features'] as List);
    } catch (e) {
      // Feature names not available - user must provide input in correct order
      _featureNames = null;
    }

    _modelName = modelPath.split('/').last.replaceAll('.onnx', '');
    _isInitialized = true;
  }

  /// Run inference on the model.
  ///
  /// [inputFeatures] - Map of feature name to value, or list of values in order.
  /// Returns the model prediction(s).
  Future<List<double>> predict(dynamic inputFeatures) async {
    if (!_isInitialized || _session == null) {
      throw StateError('Model not loaded. Call loadModel() first.');
    }

    // Convert input to ordered list of floats
    List<double> inputList;
    if (inputFeatures is Map<String, double>) {
      if (_featureNames == null) {
        throw StateError(
            'Feature names not loaded. Provide input as ordered list.');
      }
      inputList = _featureNames!.map((name) {
        if (!inputFeatures.containsKey(name)) {
          throw ArgumentError('Missing feature: $name');
        }
        return inputFeatures[name]!;
      }).toList();
    } else if (inputFeatures is List<double>) {
      inputList = inputFeatures;
    } else {
      throw ArgumentError(
          'Input must be Map<String, double> or List<double>');
    }

    // Create input tensor
    final inputShape = [1, inputList.length];
    final inputData = Float32List.fromList(inputList);
    final inputTensor = OrtValueTensor.createTensorWithDataList(
      inputData,
      inputShape,
    );

    // Run inference
    final inputName = _session!.inputNames.first;
    final runOptions = OrtRunOptions();
    final outputs = await _session!.runAsync(
      runOptions,
      {inputName: inputTensor},
    );

    // Extract output
    final outputTensor = outputs?.first?.value as List<dynamic>;
    final result = outputTensor.map((e) => (e as num).toDouble()).toList();

    // Cleanup
    inputTensor.release();
    outputs?.forEach((e) => e?.release());
    runOptions.release();

    return result;
  }

  /// Dispose of the loaded model.
  void dispose() {
    _session?.release();
    _session = null;
    _isInitialized = false;
  }
}
