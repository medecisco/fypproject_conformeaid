import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';


class DartMinMaxScaler {
  final List<double> _min;
  final List<double> _scale;

  DartMinMaxScaler(this._min, this._scale);

  factory DartMinMaxScaler.fromValues({
    required List<double> min,
    required List<double> scale,
  }) {
    return DartMinMaxScaler(min, scale);
  }

  List<double> transform(List<double> data) {
    if (_min.length != 1 || _scale.length != 1) {
      throw ArgumentError('Expected single-scaler values (1 min, 1 scale)');
    }
    return data.map((x) => (x - _min[0]) / _scale[0]).toList();
  }

  List<double> inverseTransform(List<double> data) {
    if (_min.length != 2 || _scale.length != 2) {
      throw ArgumentError('Expected two-scaler values for output (2 targets)');
    }
    return List.generate(data.length, (i) => data[i] * _scale[i] + _min[i]);
  }
}

class Model {
  Interpreter? _interpreter;
  bool _isModelLoadedSuccessfully = false;
  bool get isModelLoaded => _isModelLoadedSuccessfully;

  late DartMinMaxScaler _xScaler;
  late DartMinMaxScaler _yScaler;

  Future<void> loadModel() async {
    try {
      final modelFile = await rootBundle.load("assets/menstrual_lstm_model.tflite");
      final modelBytes = modelFile.buffer.asUint8List();

      final options = InterpreterOptions(); // forcing cpu only for model interpreter
     /* if (Platform.isAndroid || Platform.isIOS) {
        try {
          final gpuDelegate = GpuDelegateV2(options: GpuDelegateOptionsV2());
          options.addDelegate(gpuDelegate);
          print("Using GPU delegate.");
        } catch (e) {
          print("GPU delegate failed: $e");
        }
      } */

      _interpreter = Interpreter.fromBuffer(modelBytes, options: options);
      _isModelLoadedSuccessfully = true;

      // Use same scaler values as printed from Python script
      _xScaler = DartMinMaxScaler.fromValues(
        min: [18.0],
        scale: [0.02777778],
      );

      _yScaler = DartMinMaxScaler.fromValues(
        min: [18.0, 2.0],
        scale: [0.02777778, 0.07692308],
      );

      print("Model and scalers loaded.");
    } catch (e) {
      _isModelLoadedSuccessfully = false;
      print("Failed to load model: $e");
      rethrow;
    }
  }

  Future<List<double>> predict(List<double> rawInputSequence) async {
    if (!_isModelLoadedSuccessfully || _interpreter == null) {
      throw Exception("Model not loaded. Call loadModel() first.");
    }

    if (rawInputSequence.length != 5) {
      throw ArgumentError("Expected 5 input values for prediction.");
    }

    // Log model info
    final inputTensor = _interpreter!.getInputTensor(0);
    final outputTensor = _interpreter!.getOutputTensor(0);
    print("📥 Model Input Shape: ${inputTensor.shape}");
    print("📤 Model Output Shape: ${outputTensor.shape}");

    final scaledInput = _xScaler.transform(rawInputSequence);
    final modelInput = [scaledInput.map((e) => [e]).toList()]; // Shape: [1, 5, 1]
    final modelOutput = List.filled(2, 0.0).reshape([1, 2]);

    try {
      _interpreter!.run(modelInput, modelOutput);
      final outputScaled = modelOutput[0].cast<double>();
      final result = _yScaler.inverseTransform(outputScaled);

      print("✅ Input (raw): $rawInputSequence");
      print("✅ Input (scaled): $scaledInput");
      print("✅ Output (scaled): $outputScaled");
      print("✅ Final Result: $result");

      return result;
    } catch (e) {
      print("❌ Prediction error: $e");
      rethrow;
    }
  }


  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isModelLoadedSuccessfully = false;
    print("Model disposed.");
  }
}
