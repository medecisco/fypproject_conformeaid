import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class ActualCycleManager {
  static const String _cycleEventsFileName = 'actual_cycles.json';
  static const String _userProfileFileName = 'user_profile.json'; // New file for user profile data

  // Define the default structure for the user_profile.json file
  static Map<String, dynamic> _defaultUserProfileDataStructure() {
    return {
      'age': null, // Stored as int or null
      'uses_contraceptive': false,
      'reminder_settings': {
        'enabled': false,
        'hour': 8,
        'minute': 0,
      },
      'ui_settings': {
        'bold_text': false,
        'font_size_scale': 1.0,
      },
    };
  }


  static Future<File> _getUserProfileFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_userProfileFileName');
  }

  static Future<File> get _getCycleEventsFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_cycleEventsFileName');
  }

  // --- Core Read/Write Operations for USER PROFILE JSON ---
  static Future<Map<String, dynamic>> _readUserProfileData() async {
    try {
      final file = await _getUserProfileFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final decoded = json.decode(content);
        final mergedData = _defaultUserProfileDataStructure();
        if (decoded is Map<String, dynamic>) {
          _deepMergeMaps(mergedData, decoded);
        }
        return mergedData;
      }
    } catch (e) {
      print("Error reading user profile data file: $e");
    }
    return _defaultUserProfileDataStructure(); // Return default if file doesn't exist or error
  }

  static Future<void> _writeUserProfileData(Map<String, dynamic> data) async {
    try {
      final file = await _getUserProfileFile();
      final encoded = json.encode(data);
      await file.writeAsString(encoded);
    } catch (e) {
      print("Error writing user profile data file: $e");
    }
  }

  // --- Helper for deep merging maps (important for merging default structure with loaded data)
  static void _deepMergeMaps(Map<String, dynamic> target, Map<String, dynamic> source) {
    source.forEach((key, value) {
      if (target.containsKey(key) && target[key] is Map && value is Map) {
        // FIXED: Explicitly cast to Map<String, dynamic> for recursive calls
        _deepMergeMaps(target[key] as Map<String, dynamic>, value as Map<String, dynamic>);
      } else {
        target[key] = value;
      }
    });
  }

  // --- UI Settings Management (using user_profile.json) ---
  static Future<Map<String, dynamic>> readUiSettings() async {
    final data = await _readUserProfileData();
    return Map<String, dynamic>.from(data['ui_settings'] ?? {});
  }

  static Future<void> saveUiSettings(bool boldText, double fontSizeScale) async {
    final data = await _readUserProfileData();
    data['ui_settings']['bold_text'] = boldText;
    data['ui_settings']['font_size_scale'] = fontSizeScale;
    await _writeUserProfileData(data);
  }


  // Reads all recorded cycle events, ensuring they are sorted by date.
  static Future<List<Map<String, dynamic>>> readActualCycles() async {
    try {
      final file = await _getCycleEventsFile;
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
    final file = await _getCycleEventsFile;
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
  static Future<void> addContraceptiveInfo(bool usesContraceptive) async {
    final data = await _readUserProfileData();
    data['uses_contraceptive'] = usesContraceptive;
    await _writeUserProfileData(data);
    print("Saved contraceptive info to user_profile.json: $usesContraceptive");
  }

  // --- Reminder Info Management (using user_profile.json) ---
  // This now reads/writes directly to the user_profile.json
  static Future<Map<String, dynamic>?> readReminderInfo() async {
    final data = await _readUserProfileData();
    final reminderSettings = data['reminder_settings'];
    if (reminderSettings != null) {
      return {
        'enabled': reminderSettings['enabled'],
        'hour': reminderSettings['hour'],
        'minute': reminderSettings['minute'],
      };
    }
    // Return null only if the 'reminder_settings' key itself is missing,
    // though _defaultUserProfileDataStructure should prevent this.
    return null;
  }

  static Future<void> addReminderInfo(TimeOfDay reminderTime, bool isReminderEnabled) async {
    final data = await _readUserProfileData();
    data['reminder_settings'] = {
      'enabled': isReminderEnabled,
      'hour': reminderTime.hour,
      'minute': reminderTime.minute,
    };
    await _writeUserProfileData(data);
    print("Saved reminder info to user_profile.json: $isReminderEnabled, ${reminderTime.hour}:${reminderTime.minute}");
  }

// --- User Age Management (using user_profile.json) ---
  static Future<void> saveUserAge(int age) async {
    final data = await _readUserProfileData();
    data['age'] = age;
    await _writeUserProfileData(data);
  }

  static Future<int?> getUserAge() async {
    final data = await _readUserProfileData();
    final ageValue = data['age'];
    if (ageValue != null && ageValue is int) {
      return ageValue;
    }
    return null;
  }

// --- Approximate Cycle Length (uses direct age from user_profile.json) ---
  static int calculateApproximateCycleLength(int age) {
    if (age < 20) {
      return 30; // Rounded from 30.3
    } else if (age >= 20 && age <= 34) {
      return 28; // Common average for prime age of menstrual cycle
    } else if (age >= 35 && age <= 39) {
      return 29; // Rounded from 28.7
    } else if (age >= 40 && age <= 44) {
      return 28; // Rounded from 28.2
    } else if (age >= 45 && age <= 49) {
      return 28; // Rounded from 28.4
    } else if (age >= 50) {
      return 31; // Rounded from 30.8
    } else {
      return 28; // Default for invalid/unmatched age
    }
  }

}
