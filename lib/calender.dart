import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  final List<DateTime> _predictionDates = [
    DateTime(DateTime.now().year, DateTime.now().month, 6),
    DateTime(DateTime.now().year, DateTime.now().month, 7),
    DateTime(DateTime.now().year, DateTime.now().month, 8),
    DateTime(DateTime.now().year, DateTime.now().month, 9),
    DateTime(DateTime.now().year, DateTime.now().month, 10),
  ];

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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                // Title Bar
                Padding(
                  padding: const EdgeInsets.only(top: 10.0, bottom: 20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.bookmark_border, color: Color(0xFFE67A82), size: 30),
                      SizedBox(width: 8),
                      Text(
                        'Timeline',
                        style: TextStyle(
                          color: Color(0xFFE67A82),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Calendar Container
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
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
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
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
                                  child: Text(DateFormat('MMMM').format(DateTime(_currentYear, index + 1))),
                                );
                              }),
                              onChanged: (value) {
                                setState(() {
                                  _currentMonth = value!;
                                  _focusedDay = DateTime(_currentYear, _currentMonth);
                                  _selectedDay = DateTime(_currentYear, _currentMonth);
                                });
                              },
                            ),
                            Text(_currentYear.toString()),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(onPressed: _goToPreviousMonth, icon: const Icon(Icons.chevron_left)),
                            IconButton(onPressed: _goToNextMonth, icon: const Icon(Icons.chevron_right)),
                          ],
                        ),

                        // Calendar Grid
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
                          itemCount: DateTime(_currentYear, _currentMonth + 1, 0).day +
                              DateTime(_currentYear, _currentMonth, 1).weekday - 1,
                          itemBuilder: (context, index) {
                            if (index < DateTime(_currentYear, _currentMonth, 1).weekday - 1) {
                              return const SizedBox(); // Empty spaces before first day
                            }

                            final day = index - DateTime(_currentYear, _currentMonth, 1).weekday + 2;
                            final currentDate = DateTime(_currentYear, _currentMonth, day);
                            final isPredictionDay = _predictionDates.any((date) =>
                            date.year == currentDate.year &&
                                date.month == currentDate.month &&
                                date.day == currentDate.day);
                            final isSelected = _selectedDay.year == currentDate.year &&
                                _selectedDay.month == currentDate.month &&
                                _selectedDay.day == currentDate.day;

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
                                        color: isSelected ? Colors.white : Colors.black,
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
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        // Day Names Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: const [Text("S"), Text("M"), Text("T"), Text("W"), Text("T"), Text("F"), Text("S")],
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Bottom Navigation Bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.bookmark_border),
                            onPressed: () {
                              // You are already on Timeline
                            },
                          ),
                          const Text('Timeline'),
                        ],
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications_none),
                            onPressed: widget.onNavigateToReminder,
                          ),
                          const Text('Reminder'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
