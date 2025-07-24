import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // for user profile data, but not predictions
import 'package:firebase_auth/firebase_auth.dart'; // for user ID
import 'package:shared_preferences/shared_preferences.dart';
import 'local_data_manager.dart';
import 'actual_cycle_manager.dart'; // Import ActualCycleManager (might be needed for future logic, but less for direct prediction display)

class TimelineScreen extends StatefulWidget {
  final VoidCallback onNavigateToReminder;

  const TimelineScreen({super.key, required this.onNavigateToReminder});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  int _currentMonth = DateTime.now().month;
  int _currentYear = DateTime.now().year;

  // MODIFIED: List to store multiple prediction periods, each as a list of dates
  List<List<DateTime>> _allPredictionPeriods = [];

  Future<void>_saveUpdatedPredictionDates(DateTime newStart, DateTime newEnd) async {
    final predictionData = await LocalDataManager.readPredictions();

    if (predictionData == null) return;

    predictionData[0]['expectedStart'] = newStart.toIso8601String();
    predictionData[0]['expectedEnd'] = newEnd.toIso8601String();
    predictionData[0]['mensesLength'] = newEnd.difference(newStart).inDays + 1;

    await LocalDataManager.savePredictions(predictionData);
    await _fetchPredictions();
  }

  // Shared Preferences related state variables
  bool _boldText = false;
  double _fontSizeScale = 1.0;

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  void initState() {
    super.initState();
    _loadSettings(); // NEW: Load user settings
    _fetchPredictions(); // Fetch prediction data when the screen is loaded
  }

  // NEW: Load user preferences for UI customizations like bold text and font size scaling
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _boldText = prefs.getBool('boldText') ?? false;
      _fontSizeScale = prefs.getDouble('fontSizeScale') ?? 1.0;
    });
  }


  // Fetch predictions from Local JSON (NOT Firestore anymore, will recommend this for future development)
  Future<void> _fetchPredictions() async {
    print("TimelineScreen: --- Starting _fetchPredictions ---"); // DEBUG
    try {
      // Read all prediction data from the local JSON file
      List<Map<String, dynamic>>? allRawPredictions = await LocalDataManager.readPredictions(); // Modified call
      print("TimelineScreen: Raw prediction data fetched: $allRawPredictions"); // DEBUG: Print raw data

      List<List<DateTime>> fetchedPeriods = [];
      if (allRawPredictions != null && allRawPredictions.isNotEmpty) {
        for (var predictionData in allRawPredictions) {
          if (predictionData.containsKey('expectedStart') && predictionData.containsKey('expectedEnd')) {
            DateTime start = DateTime.parse(predictionData['expectedStart']);
            DateTime end = DateTime.parse(predictionData['expectedEnd']);
            print("TimelineScreen: Parsed expectedStart: $start, expectedEnd: $end"); // DEBUG: Print parsed dates

            // Generate all dates between predicted start and end dates for this period
            List<DateTime> daysInPeriod = [];
            for (DateTime date = start; date.isBefore(end.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
              daysInPeriod.add(date);
            }
            if (daysInPeriod.isNotEmpty) {
              fetchedPeriods.add(daysInPeriod);
            }
          } else {
            print("TimelineScreen: A prediction entry is missing 'expectedStart' or 'expectedEnd' keys."); // DEBUG
          }
        }
        print("TimelineScreen: Successfully processed ${fetchedPeriods.length} prediction periods."); // DEBUG: Confirmation
      } else {
        print("TimelineScreen: No prediction data found in local storage (allRawPredictions is null or empty)."); // DEBUG
      }

      // Update the state to reflect the fetched prediction dates
      setState(() {
        _allPredictionPeriods = fetchedPeriods;
      });

    } catch (e) {
      print('TimelineScreen: Error fetching prediction from local data: $e'); // DEBUG: This will catch parsing errors too
      setState(() {
        _allPredictionPeriods = []; // Clear old predictions on error
      });
    }
    print("TimelineScreen: --- Finished _fetchPredictions ---"); // DEBUG
  }

  // Shifting the prediction window (e.g., moving start and end dates by a few days)
  // This now updates LOCAL JSON, not Firestore.
  // This method will now primarily adjust the *first* predicted cycle and re-save all predictions.
  Future<void> _shiftPrediction({required int daysToShift}) async {
    if (_allPredictionPeriods.isEmpty || _allPredictionPeriods.first.isEmpty) {
      print("No prediction to shift.");
      return;
    }

    // Get the first predicted period
    List<DateTime> firstPeriod = _allPredictionPeriods.first;
    DateTime oldStart = firstPeriod.first;
    DateTime oldEnd = firstPeriod.last;

    DateTime newStart = oldStart.add(Duration(days: daysToShift));
    DateTime newEnd = oldEnd.add(Duration(days: daysToShift));

    // Retrieve all current prediction data to re-generate/adjust
    List<Map<String, dynamic>>? currentPredictions = await LocalDataManager.readPredictions();
    if (currentPredictions == null || currentPredictions.isEmpty) {
      print("Could not retrieve current predictions for shifting.");
      return;
    }

    // Modify the first prediction in the list
    if (currentPredictions.isNotEmpty) {
      currentPredictions[0]['expectedStart'] = newStart.toIso8601String();
      currentPredictions[0]['expectedEnd'] = newEnd.toIso8601String();
      currentPredictions[0]['predictedMensesLength'] = newEnd.difference(newStart).inDays + 1; // +1 to include both start and end days
    }

    // For simplicity, we'll re-save the potentially modified list.
    // A more advanced approach would recalculate all subsequent predictions based on this shift.
    // For now, we only update the first predicted cycle in the saved list.
    await LocalDataManager.savePredictions(currentPredictions);
    print("First prediction shifted and saved locally: Start: $newStart, End: $newEnd");

    // Re-fetch and update local state to reflect changes on UI
    await _fetchPredictions();

    // Optional: Save adjustment history to Firestore if you want a cloud log of changes
    await _saveAdjustmentHistory(
      actionType: 'Shifted Prediction (Local)',
      oldStart: oldStart,
      oldEnd: oldEnd,
      newStart: newStart,
      newEnd: newEnd,
    );
  }

  // Extend the prediction window by a few extra days
  // This now updates LOCAL JSON, not Firestore.
  // This method will now primarily adjust the *first* predicted cycle and re-save all predictions.
  Future<void> _extendPrediction({required int daysToExtend}) async {
    if (_allPredictionPeriods.isEmpty || _allPredictionPeriods.first.isEmpty) {
      print("No prediction to extend.");
      return;
    }

    // Get the first predicted period
    List<DateTime> firstPeriod = _allPredictionPeriods.first;
    DateTime oldStart = firstPeriod.first;
    DateTime oldEnd = firstPeriod.last;

    DateTime newEnd = oldEnd.add(Duration(days: daysToExtend));

    // Retrieve all current prediction data to re-generate/adjust
    List<Map<String, dynamic>>? currentPredictions = await LocalDataManager.readPredictions();
    if (currentPredictions == null || currentPredictions.isEmpty) {
      print("Could not retrieve current predictions for extending.");
      return;
    }

    // Modify the first prediction in the list
    if (currentPredictions.isNotEmpty) {
      currentPredictions[0]['expectedEnd'] = newEnd.toIso8601String();
      currentPredictions[0]['predictedMensesLength'] = newEnd.difference(
          DateTime.parse(currentPredictions[0]['expectedStart']))
          .inDays + 1; // +1 to include both start and end days
    }

    // For simplicity, we'll re-save the potentially modified list.
    // A more advanced approach would recalculate all subsequent predictions based on this extension.
    await LocalDataManager.savePredictions(currentPredictions);
    print("First prediction extended and saved locally: New End: $newEnd");

    // Re-fetch and update local state to reflect changes on UI
    await _fetchPredictions();

    // Optional: Save adjustment history to Firestore if you want a cloud log of changes
    await _saveAdjustmentHistory(
      actionType: 'Extended Prediction (Local)',
      oldStart: oldStart,
      oldEnd: oldEnd,
      newStart: oldStart,
      newEnd: newEnd,
    );
  }

  // Show a dialog to adjust menstruation status (shift or extend predictions)
  void _showAdjustDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        // Applying font scaling and bold text
        title: Text("Adjust Menstruation", style: TextStyle(
          fontWeight: _boldText ? FontWeight.bold : FontWeight.normal,
          fontSize: 20 * _fontSizeScale,
        )),
        // Applying font scaling
        content: Text("Is the menstruation status correct today?", style: TextStyle(fontSize: 16 * _fontSizeScale)),
        actions: [
          TextButton(
            // Applying font scaling
            //Didn't start yet button
            child: Text("Didn't Start", style: TextStyle(fontSize: 16 * _fontSizeScale)),
            onPressed: () async {
              Navigator.pop(context);
              if (_allPredictionPeriods.isNotEmpty && _allPredictionPeriods.first.isNotEmpty) {
                     final current = _allPredictionPeriods.first;
                     final updated = current.map((d) => d.add(const Duration(days: 1))).toList();
                     setState(() {
                   _allPredictionPeriods[0] = updated; // Shift prediction by 1 day
                     });

                     await _saveUpdatedPredictionDates(updated.first, updated.last);

                     ScaffoldMessenger.of(context).showSnackBar(
                       SnackBar(content: Text('Shifted cycle forward by 1 day.', style: TextStyle(fontSize: 14 * _fontSizeScale))),
                     );
              }
            },
    ),
          TextButton(
            // Applying font scaling
            // still bleeding button
            child: Text("Still Bleeding", style: TextStyle(fontSize: 16 * _fontSizeScale)),
            onPressed: () async {
              Navigator.pop(context);
              if (_allPredictionPeriods.isNotEmpty && _allPredictionPeriods.first.isNotEmpty) {
                final current = _allPredictionPeriods.first;
                final newEnd = current.last.add(const Duration(days: 1));
                final extended = List<DateTime>.from(current)..add(newEnd);

              setState(() {
             _allPredictionPeriods[0] = extended; // Extend prediction by 1 day
          });

            await _saveUpdatedPredictionDates(extended.first, newEnd);

          ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Extended bleeding by 1 day.', style: TextStyle(fontSize: 14 * _fontSizeScale))),
    );
    }
    },
    ),
          // NEW: "Bleeding Has Started" button
          TextButton(
            // Applying font scaling
            child: Text("Bleeding Has Started", style: TextStyle(fontSize: 16 * _fontSizeScale)),
            onPressed: () async {
              Navigator.pop(context);
              final today = DateTime.now();
              const mensesLength = 5;
              final newEnd = today.add(const Duration(days: mensesLength - 1));
              final newPeriod = List.generate(mensesLength, (i) => today.add(Duration(days: i)));

              setState(() {
                if (_allPredictionPeriods.isEmpty) {
                  _allPredictionPeriods.add(newPeriod);
                } else {
                  _allPredictionPeriods[0] = newPeriod;
                }
              });

              await _saveUpdatedPredictionDates(today, newEnd);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Bleeding start updated!', style: TextStyle(fontSize: 14 * _fontSizeScale))),
              );
            },
          ),
        ],
      ),
    );
  }

  // Save the history of adjustments (shifted or extended cycle) to Firebase (optional, for logging)
  Future<void> _saveAdjustmentHistory({
    required String actionType,
    required DateTime oldStart,
    required DateTime oldEnd,
    DateTime? newStart,
    DateTime? newEnd,
  }) async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      print("Not saving adjustment history to Firebase: User not authenticated.");
      return;
    }
    CollectionReference historyRef = FirebaseFirestore.instance.collection('users').doc(userId).collection('history');
    try {
      await historyRef.add({
        'dateOfAction': DateTime.now().toIso8601String(),
        'actionType': actionType,
        'oldStart': oldStart.toIso8601String(),
        'oldEnd': oldEnd.toIso8601String(),
        'newStart': newStart?.toIso8601String(),
        'newEnd': newEnd?.toIso8601String(),
        'details': 'Action: $actionType on prediction window',
      });
      print("Adjustment history saved to Firebase.");
    } catch (e) {
      print("Error saving adjustment history to Firebase: $e");
    }
  }

  // Helper function to build day name text with consistent style
  // NEW: Updated to use _boldText and _fontSizeScale
  Widget _buildDayLabel(String day) {
    return Text(
      day,
      style: TextStyle(
        fontSize: 14 * _fontSizeScale,
        fontWeight: _boldText ? FontWeight.bold : FontWeight.normal,
        color: Colors.black,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.grey),
          onPressed: () async {
            Navigator.pop(context);
          },
        ),
        // Applying font scaling and bold text
        title: Text(
          'Timeline',
          style: TextStyle(color: Colors.black, fontWeight: _boldText ? FontWeight.bold : FontWeight.normal, fontSize: 20 * _fontSizeScale),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF5C75E),
              Color(0xFFE67A82),
            ],
            stops: [0.3, 0.7],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Calendar Container
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Date Display - Applying font scaling and bold text
                        Text(
                          DateFormat('EEE, MMM d').format(_selectedDay),
                          style: TextStyle(
                              fontSize: 20 * _fontSizeScale,
                              fontWeight: _boldText ? FontWeight.bold : FontWeight.w500),
                        ),
                        const SizedBox(height: 10),
                        // Month and Year Selection (MODIFIED to match UI image)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Left Arrow
                            IconButton(
                              onPressed: _goToPreviousMonth,
                              icon: Icon(Icons.keyboard_arrow_left, color: Colors.grey, size: 24 * _fontSizeScale),
                            ),
                            DropdownButton<int>(
                              value: _currentMonth,
                              items: List.generate(12, (index) {
                                return DropdownMenuItem<int>(
                                  value: index + 1,
                                  child: Text(DateFormat('MMMM').format(DateTime(_currentYear, index + 1)), style: TextStyle(fontSize: 14 * _fontSizeScale)),
                                );
                              }),
                              onChanged: (value) {
                                setState(() {
                                  _currentMonth = value!;
                                  _focusedDay = DateTime(_currentYear, _currentMonth);
                                  _selectedDay = DateTime(_currentYear, _currentMonth);
                                  _fetchPredictions();
                                });
                              },
                            ),
                            // Year Text
                            Text(_currentYear.toString(),
                              style: TextStyle(fontSize: 14 * _fontSizeScale),
                            ),
                            // Right Arrow
                            IconButton(
                              onPressed: _goToNextMonth,
                              icon: Icon(Icons.keyboard_arrow_right, color: Colors.grey, size: 24 * _fontSizeScale),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Day Labels (Sun, Mon, etc.) - Applying font scaling and bold text
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildDayLabel('Sun'),
                            _buildDayLabel('Mon'),
                            _buildDayLabel('Tue'),
                            _buildDayLabel('Wed'),
                            _buildDayLabel('Thu'),
                            _buildDayLabel('Fri'),
                            _buildDayLabel('Sat'),
                          ],
                        ),
                        // Removed Divider as per UI image
                        const SizedBox(height: 10),
                        // Calendar Grid - Dynamically build days of the month
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            childAspectRatio: 1.0,
                          ),
                          itemCount: DateTime(_currentYear, _currentMonth + 1, 0).day + _getFirstDayOfWeek(_currentYear, _currentMonth),
                          itemBuilder: (context, index) {
                            final int firstDayOffset = _getFirstDayOfWeek(_currentYear, _currentMonth);
                            if (index < firstDayOffset) {
                              return const SizedBox.shrink(); // Empty space for days before the 1st of the month
                            }
                            final int day = index - firstDayOffset + 1;
                            final DateTime date = DateTime(_currentYear, _currentMonth, day);
                            final bool isToday = _isSameDay(date, DateTime.now());
                            final bool isSelected = _isSameDay(date, _selectedDay);
                            // MODIFIED: Check if the date is part of *any* predicted period
                            final bool isPredictionDay = _allPredictionPeriods.any((period) =>
                                period.any((predictedDate) => _isSameDay(date, predictedDate)));

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedDay = date;
                                });
                              },
                              child: Center(
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Draw the background circle for selected or today (MODIFIED to match UI image)
                                    if (isSelected || isToday)
                                      Container(
                                        width: 35 * _fontSizeScale,
                                        height: 35 * _fontSizeScale,
                                        decoration: BoxDecoration(
                                          color: isSelected ? Colors.deepPurple.shade400 : Colors.blue.shade600, // Purple for selected, blue for today (if not selected)
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    // Day number text - Applying font scaling
                                    Text(
                                      '$day',
                                      style: TextStyle(
                                        color: isSelected || isToday ? Colors.white : Colors.black87, // White for selected/today, black for others
                                        fontWeight: _boldText ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 16 * _fontSizeScale,
                                      ),
                                    ),
                                    // Show a red dot for predicted dates (if needed, and not selected/today)
                                    if (isPredictionDay && !(isSelected || isToday))
                                      Positioned.fill(
                                        child: Center(
                                        child: Container(
                                          width: 35 * _fontSizeScale,
                                          height: 35 * _fontSizeScale,
                                          decoration: const BoxDecoration(
                                            color: Color.fromRGBO(244, 67, 54, 0.5),
                                            shape: BoxShape.circle,
                                          ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Adjust Menstruation Button
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ElevatedButton(
                    onPressed: _showAdjustDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink.shade200,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                    ),
                    child: Text(
                      'Adjust Menstruation',
                      style: TextStyle(fontSize: 18 * _fontSizeScale, color: Colors.white, fontWeight: _boldText ? FontWeight.bold : FontWeight.normal),
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
      // Bottom Navigation Bar (MODIFIED to ensure white background)
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white, // This explicitly sets the background to white
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, -5), // Shadow above the bar
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 12), // Add vertical padding
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            TextButton.icon(
              onPressed: () {}, // Current screen, no action
              icon: Icon(Icons.calendar_month, size: 24 * _fontSizeScale), // MODIFIED to match UI image icon
              label: Text('Timeline', style: TextStyle(fontWeight: _boldText ? FontWeight.bold : FontWeight.normal, fontSize: 14 * _fontSizeScale)),
              style: TextButton.styleFrom(foregroundColor: Colors.pink.shade200), // Active color
            ),
            // Reminder button - Applying icon size and font scaling/bold text
            TextButton.icon(
              onPressed: widget.onNavigateToReminder,
              icon: Icon(Icons.notifications, size: 24 * _fontSizeScale),
              label: Text('Reminder', style: TextStyle(fontWeight: _boldText ? FontWeight.bold : FontWeight.normal, fontSize: 14 * _fontSizeScale)),
              style: TextButton.styleFrom(foregroundColor: Colors.grey), // Inactive color
            ),
          ],
        ),
      ),
    );
  }

  // Get the weekday of the first day of the month (0 for Sunday, 1 for Monday, etc.)
  int _getFirstDayOfWeek(int year, int month) {
    return DateTime(year, month, 1).weekday % 7; // Adjust to make Sunday 0
  }

  // Navigate to the previous month and update predictions
  void _goToPreviousMonth() {
    setState(() {
      if (_currentMonth == 1) {
        _currentMonth = 12;
        _currentYear--;
      } else {
        _currentMonth--;
      }
      _focusedDay = DateTime(_currentYear, _currentMonth);
      _selectedDay = DateTime(_currentYear, _currentMonth);
      _fetchPredictions();
    });
  }

  // Navigate to the next month and update predictions
  void _goToNextMonth() {
    setState(() {
      if (_currentMonth == 12) {
        _currentMonth = 1;
        _currentYear++;
      } else {
        _currentMonth++;
      }
      _focusedDay = DateTime(_currentYear, _currentMonth);
      _selectedDay = DateTime(_currentYear, _currentMonth);
      _fetchPredictions();
    });
  }
}