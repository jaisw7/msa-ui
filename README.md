# MSA-UI - Stock Trading Mobile App

A Flutter mobile application for monitoring stock positions, running ML predictions, and executing trades.

## Features

- **Real-time Stock Data**: View live and historical price charts
- **Position Tracking**: Monitor your portfolio with P&L calculations
- **Alpha Signals**: Display trading signals from the MSA backend
- **ML Predictions**: Run ONNX model inference locally on device
- **Trading**: Execute buy/sell orders through Alpaca API
- **Self-Managed Trading**: Track paper trades with local database

## Getting Started

### Prerequisites

- Flutter SDK 3.10+
- Dart 3.0+
- Android Studio / Xcode (for mobile development)

### Installation

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Configuration

#### Alpaca Trading (Optional)

To enable live trading, configure Alpaca credentials:

1. Get API keys from [Alpaca](https://alpaca.markets/)
2. In the app, go to Settings > Configure Alpaca
3. Enter your API key and secret

## ML Model Integration

The app supports running ONNX model inference locally on-device.

### Exporting Models

Use the `msa` CLI to export trained models:

```bash
# In the msa directory
msa model export -p models/AAPL_xgboost.joblib -o ../msa-ui/assets/models/ -n AAPL_xgboost
```

### Using Models in Flutter

```dart
import 'package:msa_ui/services/ml/inference_service.dart';

// Initialize at app startup
await InferenceService.initializeOrt();

// Load and use a model
final service = InferenceService();
await service.loadModel('assets/models/AAPL_xgboost.onnx');

// Run inference
final prediction = await service.predict([
  150.0, 152.0, 149.0, 151.0,  // OHLC
  1000000,                      // Volume
  // ... other features
]);

print('Prediction: ${prediction.first}');

// Cleanup
service.dispose();
```

### MoE (Mixture of Experts) Models

```dart
import 'package:msa_ui/services/ml/moe_inference_service.dart';

final moeService = MoeInferenceService();
await moeService.loadModel('assets/models/AAPL_moe_config.json');

final result = await moeService.predict(
  regimeFeatures: [/* 8 regime features */],
  alphaFeatures: [/* alpha scores */],
);

print('Regime: ${result.regime}, Prediction: ${result.prediction}');
```

## Project Structure

```text
msa-ui/
├── lib/
│   ├── data/
│   │   ├── models/          # Data models
│   │   └── repositories/    # Data access layer
│   ├── presentation/
│   │   ├── providers/       # Riverpod state management
│   │   ├── screens/         # UI screens
│   │   └── widgets/         # Reusable widgets
│   └── services/
│       ├── alpaca/          # Alpaca API integration
│       ├── ml/              # ML inference services
│       └── yahoo/           # Yahoo Finance data
├── assets/
│   └── models/              # ONNX model files
└── test/                    # Unit and widget tests
```

## Screens

- **Home**: Portfolio overview with quick actions
- **Watchlist**: Track stocks of interest
- **Stock Detail**: Charts, stats, signals, and trading
- **Positions**: Current holdings with P&L
- **Performance**: Historical performance metrics
- **Settings**: App configuration

## Dependencies

Key packages:

- `flutter_riverpod` - State management
- `go_router` - Navigation
- `fl_chart` - Charting
- `dio` - HTTP client
- `sqflite` - Local database
- `onnxruntime` - ML inference

## Development

```bash
# Run tests
flutter test

# Analyze code
flutter analyze

# Format code
dart format lib/
```

## License

MIT License - See LICENSE file for details
