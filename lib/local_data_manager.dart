import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LocalDataManager {
  // Get the local path for the application's documents directory
  static Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  // Get a reference to the local file for a given file name
  static Future<File> _localFile(String fileName) async {
    final path = await _localPath;
    return File('$path/$fileName');
  }

  // Define file names for different data types
  static const String _predictionFileName = 'menstrual_predictions.json';
  static const String _cycleHistoryFileName = 'actual_cycles.json';
  // Add other file names if needed, e.g., 'user_profile.json'

  // --- Methods for Prediction Data (menstrual_predictions.json) ---

  /// Reads prediction data from the local JSON file.
  /// Returns a List<Map<String, dynamic>> if data exists, otherwise an empty list.
  // MODIFIED: Changed method name and return type to match expectation of List
  static Future<List<Map<String, dynamic>>> readPredictions() async {
    try {
      final file = await _localFile(_predictionFileName);
      if (!await file.exists()) {
        print("Prediction file does not exist. Returning empty list.");
        return []; // Return empty list if file does not exist
      }
      final contents = await file.readAsString();
      // MODIFIED: Decode as List<dynamic> and cast to List<Map<String, dynamic>>
      final List<dynamic> jsonList = jsonDecode(contents);
      return jsonList.map((item) => item as Map<String, dynamic>).toList();
    } catch (e) {
      print("Error reading prediction data: $e");
      // If there's an error (e.g., malformed JSON), return an empty list
      return [];
    }
  }

  /// Saves prediction data to the local JSON file.
  static Future<void> savePredictions(List<Map<String, dynamic>> predictions) async {
    try {
      final file = await _localFile(_predictionFileName);
      await file.writeAsString(jsonEncode(predictions));
      print("Prediction data saved successfully to $_predictionFileName");
    } catch (e) {
      print("Error saving prediction data: $e");
      // Consider throwing the error or handling it more gracefully in production
    }
  }

  // --- Methods for Cycle History Data (actual_cycles.json) ---

  /// Reads actual cycle history from the local JSON file.
  /// Returns a List of Maps, or an empty list if the file doesn't exist or an error occurs.
  static Future<List<Map<String, dynamic>>> readCycleHistory() async {
    try {
      final file = await _localFile(_cycleHistoryFileName);
      if (!await file.exists()) {
        print("Cycle history file does not exist. Returning empty list.");
        return []; // Return empty list if file doesn't exist
      }
      final contents = await file.readAsString();
      // Ensure the decoding handles potential empty file or non-list JSON gracefully
      List<dynamic> jsonList = json.decode(contents);
      List<Map<String, dynamic>> cycles = jsonList.cast<Map<String, dynamic>>();

      // Sort by date to ensure correct chronological order
      cycles.sort((a, b) {
        DateTime dateA = DateTime.parse(a['date']);
        DateTime dateB = DateTime.parse(b['date']);
        return dateA.compareTo(dateB);
      });
      return cycles;
    } catch (e) {
      print("Error reading actual cycles: $e");
      return [];
    }
  }

  /// Saves actual cycle history to the local JSON file.
  static Future<void> saveCycleHistory(List<Map<String, dynamic>> cycleHistory) async {
    try {
      final file = await _localFile(_cycleHistoryFileName);
      await file.writeAsString(jsonEncode(cycleHistory));
      print("Cycle history saved successfully to $_cycleHistoryFileName");
    } catch (e) {
      print("Error saving cycle history: $e");
    }
  }
}