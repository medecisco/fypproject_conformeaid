import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  List<DateTime> _predictionDates = []; // List to store prediction dates

  @override
  void initState() {
    super.initState(); // initiate the firestore to fetch data from firestore
    _fetchPredictions();
  }

  Future<void> _fetchPredictions() async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) return;

    try {
      DocumentSnapshot predictionDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('predictions')
          .doc('nextCycle')
          .get();

      if (predictionDoc.exists) {
        Map<String, dynamic> predictionData =
        predictionDoc.data() as Map<String, dynamic>;
        DateTime start = DateTime.parse(predictionData['expectedStart']);
        DateTime end = DateTime.parse(predictionData['expectedEnd']);

        List<DateTime> days = [];
        for (DateTime date = start;
        date.isBefore(end);
        date = date.add(const Duration(days: 1))) {
          days.add(date);
        }

        setState(() {
          _predictionDates = days;
        });
      }
    } catch (e) {
      print('Error fetching prediction: $e');
    }
  }

  Future<void> _shiftPrediction({required int daysToShift}) async {
    DateTime newStart = _predictionDates.first.add(Duration(days: daysToShift));
    DateTime newEnd = _predictionDates.last.add(Duration(days: daysToShift));

    // Save the adjustment history
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    // Call to save history of the adjustment
    await _saveAdjustmentHistory(
      actionType: 'Shifted Cycle',
      oldStart: _predictionDates.first,
      oldEnd: _predictionDates.last,
      newStart: newStart,
      newEnd: newEnd,
    );

    // Update Firestore with new start and end dates
    FirebaseFirestore.instance.collection('users').doc(userId).collection('predictions').doc('nextCycle').set({
      'expectedStart': newStart.toIso8601String(),
      'expectedEnd': newEnd.toIso8601String(),
    });

    // Update local prediction dates
    setState(() {
      _predictionDates = List.generate(
          newEnd.difference(newStart).inDays + 1, (i) => newStart.add(Duration(days: i)));
    });
  }

  Future<void> _extendPrediction({required int daysToExtend}) async {
    DateTime newEnd = _predictionDates.last.add(Duration(days: daysToExtend));

    // Update Firestore with the extended end date
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    FirebaseFirestore.instance.collection('users').doc(userId).collection('predictions').doc('nextCycle').update({
      'expectedEnd': newEnd.toIso8601String(),
    });

    // Update local prediction dates
    setState(() {
      _predictionDates.addAll(List.generate(
          daysToExtend, (i) => newEnd.add(Duration(days: i + 1))));
    });
  }

  void _showAdjustDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Adjust Menstruation"),
        content: const Text("Is the menstruation status correct today?"),
        actions: [
          TextButton(
            child: const Text("Didn't Start"),
            onPressed: () {
              Navigator.pop(context);
              _shiftPrediction(daysToShift: 1); // Shift cycle by 1 day
            },
          ),
          TextButton(
            child: const Text("Still Bleeding"),
            onPressed: () {
              Navigator.pop(context);
              _extendPrediction(
                  daysToExtend: 1); // Extend bleeding by 1 day
            },
          ),
        ],
      ),
    );
  }

  Future<void> _saveAdjustmentHistory({
    required String actionType,
    required DateTime oldStart,
    required DateTime oldEnd,
    DateTime? newStart,
    DateTime? newEnd,
  }) async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    CollectionReference historyRef =
    FirebaseFirestore.instance.collection('users').doc(userId).collection('history');

    await historyRef.add({
      'dateOfAction': DateTime.now().toIso8601String(),
      'actionType': actionType,
      'oldStart': oldStart.toIso8601String(),
      'oldEnd': oldEnd.toIso8601String(),
      'newStart': newStart?.toIso8601String(),
      'newEnd': newEnd?.toIso8601String(),
      'details': 'Action: $actionType on prediction window',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        // BACK BUTTON
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.grey),
          onPressed: () {
            Navigator.pushNamed(context, '/Homepage');// This will pop the current screen
          },
        ),
        title: const Text(
          'Timeline',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
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
                // REMOVED: The custom title bar is removed from here
                // to avoid redundancy with the new AppBar.

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
                        // Date Display
                        Text(
                          DateFormat('EEE, MMM d').format(_selectedDay),
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 10),

                        // Month and Year Selection
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            DropdownButton<int>(
                              value: _currentMonth,
                              items: List.generate(12, (index) {
                                return DropdownMenuItem<int>(
                                  value: index + 1,
                                  child: Text(DateFormat('MMMM')
                                      .format(DateTime(_currentYear, index + 1))),
                                );
                              }),
                              onChanged: (value) {
                                setState(() {
                                  _currentMonth = value!;
                                  _focusedDay =
                                      DateTime(_currentYear, _currentMonth);
                                  _selectedDay =
                                      DateTime(_currentYear, _currentMonth);
                                });
                              },
                            ),
                            Text(_currentYear.toString()),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                                onPressed: _goToPreviousMonth,
                                icon: const Icon(Icons.chevron_left)),
                            IconButton(
                                onPressed: _goToNextMonth,
                                icon: const Icon(Icons.chevron_right)),
                          ],
                        ),

                        // Calendar Grid
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7),
                          itemCount: DateTime(
                              _currentYear, _currentMonth + 1, 0).day +
                              DateTime(_currentYear, _currentMonth, 1).weekday -
                              1,
                          itemBuilder: (context, index) {
                            if (index <
                                DateTime(_currentYear, _currentMonth, 1)
                                    .weekday -
                                    1) {
                              return const SizedBox(); // Empty spaces before first day
                            }

                            final day = index -
                                DateTime(_currentYear, _currentMonth, 1)
                                    .weekday +
                                2;
                            final currentDate =
                            DateTime(_currentYear, _currentMonth, day);
                            final isPredictionDay = _predictionDates.any(
                                    (date) =>
                                date.year == currentDate.year &&
                                    date.month == currentDate.month &&
                                    date.day == currentDate.day);
                            final isSelected = _selectedDay.year ==
                                currentDate.year &&
                                _selectedDay.month == currentDate.month &&
                                _selectedDay.day == currentDate.day;

                            final isToday =
                                _focusedDay.year == currentDate.year &&
                                    _focusedDay.month == currentDate.month &&
                                    _focusedDay.day == currentDate.day;

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedDay = currentDate;
                                });
                              },
                              child: Center(
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    if (isSelected)
                                      Container(
                                        width: 35,
                                        height: 35,
                                        decoration: BoxDecoration(
                                          color: Colors.deepPurple.shade400,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    Text(
                                      day.toString(),
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                    if (isPredictionDay)
                                      Positioned(
                                        bottom: 2,
                                        child: Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    // anchor for today's date
                                    if (isToday)
                                      Container(
                                        width: 35,
                                        height: 35,
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade600,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    Text(day.toString(),
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.black,
                                        )),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        // Day Names Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: const [
                            Text("S"),
                            Text("M"),
                            Text("T"),
                            Text("W"),
                            Text("T"),
                            Text("F"),
                            Text("S")
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Adjust Menstruation Button
                ElevatedButton(
                  onPressed: _showAdjustDialog,
                  child: const Text('Adjust Menstruation'),
                ),
              ],
            ),
          ),
        ),
      ),
      // Bottom Navigation Bar
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            // Timeline button (now TextButton.icon)
            TextButton.icon(
              onPressed: () {
                // You are already on Timeline, so this is just a visual indicator
              },
              icon: const Icon(Icons.calendar_month),
              label: const Text('Timeline'),
              style: TextButton.styleFrom(
                  foregroundColor: Colors.pink.shade200), // Active color
            ),
            // Reminder button (now TextButton.icon)
            TextButton.icon(
              onPressed: widget.onNavigateToReminder,
              icon: const Icon(Icons.notifications), // Changed to solid bell
              label: const Text('Reminder'),
              style: TextButton.styleFrom(
                  foregroundColor: Colors.grey), // Inactive color
            ),
          ],
        ),
      ),
    );
  }

  //to navigate the calender and update it to show what have been predicted, well that is my understanding of it...
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
      _fetchPredictions(); // Ensure predictions are updated as well
    });
  }

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
      _fetchPredictions(); // Ensure predictions are updated as well
    });
  }
}
