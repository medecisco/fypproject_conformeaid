import 'package:tflite_flutter/tflite_flutter.dart';

class Model {
  Interpreter? _interpreter;

  Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset('C:/Users/izkan/StudioProjects/fypproject/Assets/menstrual_gru_model.pt');
  }

  Future<List<dynamic>> predict(List<dynamic> input) async {
    var output = List.filled(1, 0).reshape([1, 1]);  // Change shape as per your model's output
    _interpreter?.run(input, output);
    return output;
  }
}
