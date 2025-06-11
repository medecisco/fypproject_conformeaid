import 'package:tflite_flutter/tflite_flutter.dart';

class Model {
  Interpreter? _interpreter;

  Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset('Assets/menstrual_lstm_model.tflite');
  }

  Future<List<dynamic>> predict(List<dynamic> input) async {
    var output = List.filled(2, 0.0).reshape([1, 2]);  // Change shape as per the model's output

    //run the model
    _interpreter?.run(input, output);

    //return the prediction result
    return output;
  }
}
