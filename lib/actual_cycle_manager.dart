import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ActualCycleManager {
  static const String _fileName = 'actual_cycles.json';

  static Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  static Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/$_fileName');
  }

  // Reads all recorded cycle events, ensuring they are sorted by date.
  static Future<List<Map<String, dynamic>>> readActualCycles() async {
    try {
      final file = await _localFile;
      if (!await file.exists()) {
        return [];
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
      // Return empty list on error to prevent app crash
      return [];
    }
  }

  // Internal helper to save a list of cycle events to the file.
  // This method now expects the *complete and unique* list to be saved.
  static Future<void> _writeActualCycles(List<Map<String, dynamic>> cyclesToSave) async {
    final file = await _localFile;
    // Ensure the list is sorted before saving for consistency
    cyclesToSave.sort((a, b) {
      DateTime dateA = DateTime.parse(a['date']);
      DateTime dateB = DateTime.parse(b['date']);
      return dateA.compareTo(dateB);
    });
    await file.writeAsString(json.encode(cyclesToSave));
  }

  // Adds a new cycle event (start or end) and handles duplicates.
  static Future<void> _addAndSaveCycleEvent(DateTime date, String type) async {
    final newEntry = {'date': date.toIso8601String(), 'type': type};
    List<Map<String, dynamic>> existingCycles = await readActualCycles();

    // Check for duplicates to avoid adding the exact same event again
    bool isDuplicate = existingCycles.any((e) =>
    e['date'] == newEntry['date'] && e['type'] == newEntry['type']);

    if (!isDuplicate) {
      existingCycles.add(newEntry);
      await _writeActualCycles(existingCycles);
      print("Marked cycle $type: ${date.toIso8601String()}");
    } else {
      print("Duplicate cycle $type event for ${date.toIso8601String()}. Not saving.");
    }
  }

  // Marks the start of a cycle (period start date)
  static Future<void> markCycleStart(DateTime date) async {
    await _addAndSaveCycleEvent(date, 'start');
  }

  // Marks the end of a cycle (period end date)
  static Future<void> markCycleEnd(DateTime date) async {
    await _addAndSaveCycleEvent(date, 'end');
  }

  // Function to mark when bleeding has started (synonym for markCycleStart)
  static Future<void> markBleedingHasStarted(DateTime date) async {
    await markCycleStart(date);
  }

  // Calculates historical cycle lengths from a list of all events.
  // A cycle length is typically calculated from the start of one period
  // to the start of the next.
  static List<double> calculateHistoricalCycleLengths(List<Map<String, dynamic>> events, int desiredCount) {
    // Ensure events are sorted by date. Important if this function is called directly
    // with an unsorted list for some reason, though `readActualCycles` already sorts.
    events.sort((a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));

    List<double> cycleLengths = [];
    DateTime? previousCycleStartDate;

    for (var event in events) {
      if (event['type'] == 'start') {
        DateTime currentCycleStartDate = DateTime.parse(event['date']);
        if (previousCycleStartDate != null) {
          // Calculate days between previous start and current start
          int length = currentCycleStartDate.difference(previousCycleStartDate).inDays;
          // Ensure length is positive and reasonable (e.g., > 0)
          if (length > 0) {
            cycleLengths.add(length.toDouble());
          } else {
            print("Warning: Calculated non-positive cycle length ($length days) between $previousCycleStartDate and $currentCycleStartDate. Skipping.");
          }
        }
        previousCycleStartDate = currentCycleStartDate;
      }
    }

    // Return only the most recent 'desiredCount' lengths, or fewer if not enough.
    if (cycleLengths.length > desiredCount) {
      return cycleLengths.sublist(cycleLengths.length - desiredCount);
    }
    return cycleLengths;
  }
}
