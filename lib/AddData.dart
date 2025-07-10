// lib/add_data.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'local_data_manager.dart'; // Import the local data manager for predictions
import 'actual_cycle_manager.dart'; // Import the actual cycle data manager
import 'package:intl/intl.dart'; // For date formatting

// NEW: Custom class to hold historical period start and end dates
class HistoricalPeriodEntry {
  TextEditingController startController;
  TextEditingController endController;
  DateTime? startDate;
  DateTime? endDate;

  HistoricalPeriodEntry({
    TextEditingController? startController,
    TextEditingController? endController,
    this.startDate,
    this.endDate,
  }) : startController = startController ?? TextEditingController(),
        endController = endController ?? TextEditingController();

  void dispose() {
    startController.dispose();
    endController.dispose();
  }
}

class AddYourDataScreen extends StatefulWidget {
  final VoidCallback onSubmit;

  const AddYourDataScreen({super.key, required this.onSubmit});

  @override
  State<AddYourDataScreen> createState() => _AddYourDataScreenState();
}

class _AddYourDataScreenState extends State<AddYourDataScreen> {
  final TextEditingController ageController = TextEditingController();
  List<String> selectedSymptoms = [];
  String selectedContraception = '';

  // MODIFIED: List to hold multiple HistoricalPeriodEntry objects
  List<HistoricalPeriodEntry> _historicalPeriodEntries = [];
  final int maxHistoricalInputs = 10; // Allow up to 10 months of data

  final Model _model = Model();
  String predictedStart = '';
  String predictedEnd = '';

  // State variables for rule-based prediction
  String _ruleBasedPredictionMessage = '';
  int _ruleBasedPredictedCycleLength = 28; // Default value

  // Predefined list of common menstrual cycle symptoms
  final List<String> menstrualCycleSymptoms = [
    'Cramps',
    'Bloating',
    'Acne',
    'Headache',
    'Fatigue',
    'Mood swings',
    'Breast tenderness',
    'Backache',
    'Nausea',
    'Diarrhea/Constipation',
    'Food cravings',
    'Irritability', // CORRECTED THIS LINE
    'Anxiety',
    'Depression',
    'Difficulty concentrating',
  ];

  bool _boldText = false;
  double _fontSizeScale = 1.0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _model.loadModel(); // Load the TFLite model when the screen initializes

    // Initialize with one historical period input field (start and end)
    _addHistoricalPeriodEntry();
  }

  @override
  void dispose() {
    ageController.dispose();
    // Dispose all controllers in historical period entries
    for (var entry in _historicalPeriodEntries) {
      entry.dispose();
    }
    super.dispose();
  }

  // MODIFIED: Helper to add a new historical period input field pair
  void _addHistoricalPeriodEntry() {
    if (_historicalPeriodEntries.length < maxHistoricalInputs) {
      setState(() {
        _historicalPeriodEntries.add(HistoricalPeriodEntry());
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 10 historical period inputs reached.')),
      );
    }
  }

  // MODIFIED: Helper to remove a historical period input field pair
  void _removeHistoricalPeriodEntry(int index) {
    setState(() {
      _historicalPeriodEntries[index].dispose(); // Dispose controllers for the removed entry
      _historicalPeriodEntries.removeAt(index);
    });
  }

  // --- ADJUSTED RULE-BASED PREDICTION METHODS BASED ON HARVARD DATA (with variability) ---
  String _earlyPeriodPrediction(int age) {
    String predictionMessage = '';
    if (age < 20) {
      predictionMessage = 'You are under 20. Menstrual cycles average around 30.3 days and can be quite variable, typically by about 5.3 days.';
    } else if (age >= 20 && age <= 34) {
      predictionMessage = 'You are in a common reproductive stage. Cycles are often around 28-29 days, with moderate variation.';
    } else if (age >= 35 && age <= 39) {
      predictionMessage = 'For your age group, menstrual cycles average around 28.7 days, with the smallest variation, typically about 3.8 days.';
    } else if (age >= 40 && age <= 44) {
      predictionMessage = 'For your age group (40-44), menstrual cycles average around 28.2 days. After age 40, cycles tend to vary more.';
    } else if (age >= 45 && age <= 49) {
      predictionMessage = 'Approaching 50 (45-49), cycles average around 28.4 days and continue to show increased variability (often 4-11 days).';
    } else if (age >= 50) {
      predictionMessage = 'You are 50 or over. Cycles may become longer, averaging around 30.8 days, and show the highest variability, typically about 11.2 days, or cease entirely due to menopause.';
    } else {
      predictionMessage = 'Please enter a valid age for a more accurate prediction message.';
    }
    return predictionMessage;
  }

  int _calculateApproximateCycleLength(int age) {
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
  // --- END ADJUSTED RULE-BASED PREDICTION METHODS ---


  void selectContraception(String type) {
    setState(() {
      selectedContraception = type;
    });
  }

  // This method saves user input (age, symptoms, contraception) to Firebase
  Future<void> _saveUserInputToFirebase() async {
    print("Firebase Save: Starting save process.");
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      print("Firebase Save: User not authenticated. Returning.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Please log in to save your data.')),
      );
      return;
    }

    try {
      print("Firebase Save: User ID found: $userId. Initializing Firebase (if needed).");
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
        print("Firebase Save: Firebase initialized.");
      }

      print("Firebase Save: Attempting to set document for user $userId.");
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'age': ageController.text.isNotEmpty ? int.tryParse(ageController.text) : null,
        'symptoms': selectedSymptoms,
        'contraception': selectedContraception,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print("User input (age, symptoms, contraception) saved to Firebase successfully!");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User data saved to cloud!')),
      );
    } catch (e) {
      print("Error saving user input to Firebase: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving user data to cloud: $e')),
      );
    }
    print("Firebase Save: _saveUserInputToFirebase finished.");
  }

  Widget _buildTimelineInputSection({
    required IconData dotIcon,
    required Widget content,
    required bool showTopLine,
    required bool showBottomLine,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 2.0,
                height: 20.0,
                color: showTopLine ? Colors.white70 : Colors.transparent,
              ),
              Container(
                width: 28.0,
                height: 28.0,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red.shade400, width: 2.0),
                ),
                child: Center(
                  child: Icon(dotIcon, size: 16.0, color: Colors.red.shade400),
                ),
              ),
              Expanded(
                child: Container(
                  width: 2.0,
                  color: showBottomLine ? Colors.white70 : Colors.transparent,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16.0),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: content,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _boldText = prefs.getBool('boldText') ?? false;
      _fontSizeScale = prefs.getDouble('fontSizeScale') ?? 1.0;
    });
  }

  // NEW: Method to calculate average cycle length from historical data
  double _calculateAverageCycleLength(List<HistoricalPeriodEntry> entries) {
    if (entries.length < 2) {
      return _ruleBasedPredictedCycleLength.toDouble(); // Fallback to rule-based if not enough data
    }

    // Sort entries by start date to ensure correct calculation
    entries.sort((a, b) => a.startDate!.compareTo(b.startDate!));

    List<double> cycleLengths = [];
    for (int i = 0; i < entries.length - 1; i++) {
      if (entries[i].startDate != null && entries[i + 1].startDate != null) {
        final cycleLength = entries[i + 1].startDate!.difference(entries[i].startDate!).inDays;
        if (cycleLength > 0) {
          cycleLengths.add(cycleLength.toDouble());
        }
      }
    }

    if (cycleLengths.isEmpty) {
      return _ruleBasedPredictedCycleLength.toDouble(); // Fallback if no valid cycle lengths
    }
    return cycleLengths.reduce((a, b) => a + b) / cycleLengths.length;
  }

  // NEW: Method to calculate average menses length from historical data
  double _calculateAverageMensesLength(List<HistoricalPeriodEntry> entries) {
    List<double> mensesLengths = [];
    for (var entry in entries) {
      if (entry.startDate != null && entry.endDate != null) {
        final mensesLength = entry.endDate!.difference(entry.startDate!).inDays + 1; // +1 to include both start and end days
        if (mensesLength > 0) {
          mensesLengths.add(mensesLength.toDouble());
        }
      }
    }

    if (mensesLengths.isEmpty) {
      return 5.0; // Default to 5 days if no historical menses length
    }
    return mensesLengths.reduce((a, b) => a + b) / mensesLengths.length;
  }


  // NEW: This method will run predictions and save them locally
  Future<void> _runPredictionAndSaveLocally() async {
    print("AddYourDataScreen: --- Starting _runPredictionAndSaveLocally ---");

    // Filter valid historical entries (both start and end dates must be present)
    final validHistoricalEntries = _historicalPeriodEntries
        .where((entry) => entry.startDate != null && entry.endDate != null)
        .toList();

    if (validHistoricalEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least one complete historical period to make predictions.')),
      );
      print("AddYourDataScreen: No valid historical period data for prediction.");
      return;
    }

    // Calculate average cycle length and menses length
    final double avgCycleLength = _calculateAverageCycleLength(validHistoricalEntries);
    final double avgMensesLength = _calculateAverageMensesLength(validHistoricalEntries);

    print("AddYourDataScreen: Calculated Avg Cycle Length: $avgCycleLength days");
    print("AddYourDataScreen: Calculated Avg Menses Length: $avgMensesLength days");

    // Get the most recent period's end date as the starting point for the next prediction
    validHistoricalEntries.sort((a, b) => b.startDate!.compareTo(a.startDate!)); // Sort descending for most recent
    DateTime lastPeriodEndDate = validHistoricalEntries.first.endDate!;
    print("AddYourDataScreen: Last recorded period end date: $lastPeriodEndDate");


    List<Map<String, dynamic>> allPredictions = [];
    DateTime currentPredictedStart = lastPeriodEndDate.add(const Duration(days: 1)); // Next cycle starts day after previous ends

    // Generate predictions for the next N months (e.g., 6 months)
    const int numberOfFuturePredictions = 6;
    for (int i = 0; i < numberOfFuturePredictions; i++) {
      // For the first prediction, use the last period's end date + 1 day as start.
      // For subsequent predictions, use the previous predicted cycle start + avgCycleLength.
      if (i > 0) {
        currentPredictedStart = currentPredictedStart.add(Duration(days: avgCycleLength.round()));
      }

      DateTime predictedEnd = currentPredictedStart.add(Duration(days: avgMensesLength.round() - 1)); // -1 because start day is included

      // Ensure prediction doesn't go too far into the past or is invalid
      if (predictedEnd.isBefore(currentPredictedStart)) {
        predictedEnd = currentPredictedStart.add(Duration(days: avgMensesLength.round())); // Ensure end is at least one day after start if menses is 1 day.
      }


      Map<String, dynamic> predictionEntry = {
        'expectedStart': currentPredictedStart.toIso8601String(),
        'expectedEnd': predictedEnd.toIso8601String(),
        'predictedMensesLength': predictedEnd.difference(currentPredictedStart).inDays + 1, // +1 to be accurate
        'predictedCycleLength': avgCycleLength.round(), // Storing average cycle length for this prediction
      };
      allPredictions.add(predictionEntry);
      print("AddYourDataScreen: Generated prediction ${i+1}: Start: ${predictionEntry['expectedStart']}, End: ${predictionEntry['expectedEnd']}");
    }

    // Save the list of all predictions
    await LocalDataManager.savePredictions(allPredictions);
    print("AddYourDataScreen: All predictions saved locally.");

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Predictions updated successfully!')),
    );
    print("AddYourDataScreen: --- Finished _runPredictionAndSaveLocally ---");
  }


  InputDecoration _inputDecoration(String hintText, {Widget? suffixIcon}) {
    return InputDecoration(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15.0),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: Colors.white.withOpacity(0.8),
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.black45),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      suffixIcon: suffixIcon,
    );
  }

  Widget _buildContraceptionOption({required IconData icon, required String label}) {
    final isSelected = selectedContraception == label;
    return GestureDetector(
      onTap: () => selectContraception(label),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: isSelected ? Colors.pink.shade100.withOpacity(0.8) : Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(25.0),
              border: isSelected ? Border.all(color: Colors.pink, width: 2) : null,
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: Colors.pink.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Icon(icon, size: 30, color: Colors.pink.shade200),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14 * _fontSizeScale,
              color: isSelected ? Colors.pink : Colors.black54,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text('Add Your Data', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 20 * _fontSizeScale,)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // This will take you back
            },
            child: Text('Cancel', style: TextStyle(color: Colors.black54, fontSize: 16 * _fontSizeScale,)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.orange.shade300,
              Colors.red.shade400,
            ],
          ),
        ),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Age Input Section
                    _buildTimelineInputSection(
                      dotIcon: Icons.calendar_today,
                      showTopLine: false,
                      showBottomLine: true,
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Age', style: TextStyle(fontSize: 16 * _fontSizeScale, color: Colors.black54)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: ageController,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration('Enter your age'),
                            onChanged: (text) {
                              final int age = int.tryParse(text) ?? 0;
                              if (age > 0) {
                                setState(() {
                                  _ruleBasedPredictionMessage = _earlyPeriodPrediction(age);
                                  _ruleBasedPredictedCycleLength = _calculateApproximateCycleLength(age);
                                });
                              } else {
                                setState(() {
                                  _ruleBasedPredictionMessage = '';
                                  _ruleBasedPredictedCycleLength = 28;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          if (_ruleBasedPredictionMessage.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _ruleBasedPredictionMessage,
                                  style: TextStyle(fontSize: 16 * _fontSizeScale, fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Approximate Cycle Length: $_ruleBasedPredictedCycleLength days',
                                  style: TextStyle(fontSize: 14 * _fontSizeScale, color: Colors.black54),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    // MODIFIED: Historical Cycle Data Input Section (Start and End Dates)
                    _buildTimelineInputSection(
                      dotIcon: Icons.history,
                      showTopLine: true,
                      showBottomLine: true,
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Historical Period Dates (most recent first, up to 10 months)',
                            style: TextStyle(fontSize: 16 * _fontSizeScale, color: Colors.black54),
                          ),
                          const SizedBox(height: 8),
                          ..._historicalPeriodEntries.asMap().entries.map((entry) {
                            int index = entry.key;
                            HistoricalPeriodEntry periodEntry = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0), // Added more space between entries
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Period ${index + 1}', style: TextStyle(fontSize: 14 * _fontSizeScale, fontWeight: FontWeight.bold, color: Colors.black87)),
                                  const SizedBox(height: 4),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: periodEntry.startController,
                                          readOnly: true,
                                          decoration: _inputDecoration(
                                            'Start Date (YYYY-MM-DD)',
                                            suffixIcon: IconButton(
                                              icon: const Icon(Icons.calendar_today, size: 20),
                                              onPressed: () async {
                                                DateTime? pickedDate = await showDatePicker(
                                                  context: context,
                                                  initialDate: periodEntry.startDate ?? DateTime.now(),
                                                  firstDate: DateTime(2000),
                                                  lastDate: DateTime.now(),
                                                );
                                                if (pickedDate != null) {
                                                  setState(() {
                                                    periodEntry.startDate = pickedDate;
                                                    periodEntry.startController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
                                                  });
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          controller: periodEntry.endController,
                                          readOnly: true,
                                          decoration: _inputDecoration(
                                            'End Date (YYYY-MM-DD)',
                                            suffixIcon: IconButton(
                                              icon: const Icon(Icons.calendar_today, size: 20),
                                              onPressed: () async {
                                                DateTime? pickedDate = await showDatePicker(
                                                  context: context,
                                                  initialDate: periodEntry.endDate ?? (periodEntry.startDate ?? DateTime.now()),
                                                  firstDate: periodEntry.startDate ?? DateTime(2000), // End date shouldn't be before start date
                                                  lastDate: DateTime.now(),
                                                );
                                                if (pickedDate != null) {
                                                  setState(() {
                                                    periodEntry.endDate = pickedDate;
                                                    periodEntry.endController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
                                                  });
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (_historicalPeriodEntries.length > 1)
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 28),
                                          onPressed: () => _removeHistoricalPeriodEntry(index),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          const SizedBox(height: 8),
                          if (_historicalPeriodEntries.length < maxHistoricalInputs)
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton.icon(
                                onPressed: _addHistoricalPeriodEntry,
                                icon: const Icon(Icons.add, color: Colors.white),
                                label: Text('Add Another Period', style: TextStyle(color: Colors.white, fontSize: 14 * _fontSizeScale)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade400,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Symptom Checkbox Section
                    _buildTimelineInputSection(
                      dotIcon: Icons.sick_outlined,
                      showTopLine: true,
                      showBottomLine: true,
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Symptoms', style: TextStyle(fontSize: 16 * _fontSizeScale, color: Colors.black54)),
                          const SizedBox(height: 8),
                          ...menstrualCycleSymptoms.map((symptom) {
                            return CheckboxListTile(
                              title: Text(symptom, style: const TextStyle(color: Colors.black87)),
                              value: selectedSymptoms.contains(symptom),
                              onChanged: (bool? isChecked) {
                                setState(() {
                                  if (isChecked == true) {
                                    selectedSymptoms.add(symptom);
                                  } else {
                                    selectedSymptoms.remove(symptom);
                                  }
                                });
                              },
                              activeColor: Colors.red.shade400,
                              checkColor: Colors.white,
                              tileColor: Colors.white.withOpacity(0.6),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                    // Contraception Type Section
                    _buildTimelineInputSection(
                      dotIcon: Icons.medication_outlined,
                      showTopLine: true,
                      showBottomLine: false,
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Type of contraception', style: TextStyle(fontSize: 16 * _fontSizeScale, fontWeight: _boldText ? FontWeight.bold : FontWeight.normal, color: Colors.black)),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: <Widget>[
                              _buildContraceptionOption(icon: Icons.medication_rounded, label: 'ORAL PILL'),
                              _buildContraceptionOption(icon: Icons.calendar_month, label: 'SELF REGULATION'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  // Save user input to Firebase first ( this one will be put in the recommendation part for future improvement )
                  // await _saveUserInputToFirebase(); // This line is intentionally commented out for now.
                  // Then, run model prediction and save all prediction data locally
                  await _runPredictionAndSaveLocally();
                  // Finally, call the onSubmit callback to dismiss/navigate
                  widget.onSubmit(); // This should trigger navigation
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.lightBlue.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                ),
                child: Text('SUBMIT', style: TextStyle(fontSize: 18 * _fontSizeScale, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}