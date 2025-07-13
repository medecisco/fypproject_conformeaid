import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Keep if other parts of app use it
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'LogIn.dart';
import 'settings_page.dart';
import 'calender.dart';
import 'ManageReminder.dart';
import 'AddData.dart';
import 'local_data_manager.dart'; // Import the local data manager

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ConformeAid',
      theme: ThemeData(
        fontFamily: GoogleFonts.inter().fontFamily,
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/LogIn',
      routes: {
        '/LogIn': (context) => LoginScreen(
          onSubmit: () => Navigator.pushNamed(context, '/Homepage'),
          onNewUser: () => Navigator.pushNamed(context, '/Register'),
        ),
        '/Homepage': (context) => const HomeScreen(
          onNavigateToTimeline: null,
          onNavigateToReminder: null,
          onNavigateToProfile: null,
        ),
        '/Settings': (context) => const SettingsPage(),
        '/calender': (context) => TimelineScreen(onNavigateToReminder: () {  },),
        '/ManageReminder': (context) => ManageReminderScreen(onNavigateToTimeline: () {  },),
        '/AddData': (context) => AddYourDataScreen(onSubmit: () {  },),
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onNavigateToTimeline,
    required this.onNavigateToReminder,
    required this.onNavigateToProfile,
  });

  final void Function()? onNavigateToTimeline;
  final void Function()? onNavigateToReminder;
  final void Function()? onNavigateToProfile;

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _boldText = false;
  // Declare a GlobalKey for MenstrualAndPredictionDataDisplay
  final GlobalKey<_MenstrualAndPredictionDataDisplayState> _predictionDisplayKey = GlobalKey();


  @override
  void initState() {
    super.initState();
    _loadBoldTextSetting();
  }

  Future<void> _loadBoldTextSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _boldText = prefs.getBool('boldText') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFF5C75E);
    const TextStyle bodyTextStyle = TextStyle(
      fontSize: 16,
      color: Colors.black54,
    );

    final List<Map<String, dynamic>> gridItems = [
      {
        'title': 'Timeline',
        'icon': Icons.calendar_month,
        'onTap': widget.onNavigateToTimeline,
      },
      {
        'title': 'Reminder',
        'icon': Icons.alarm,
        'onTap': () async {
          await Navigator.pushNamed(context, '/ManageReminder');
        }
      },
      {
        'title': 'Profile',
        'icon': Icons.medical_information,
        'onTap': () async {
          await Navigator.pushNamed(context, '/AddData');
        }
      },
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.black87),
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            SystemNavigator.pop();
          },
        ),
        title: Text(
          "Conforme Aid",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: _boldText ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 20),
              const Text('What do you want to check today?', style: bodyTextStyle),
              const SizedBox(height: 20),
              GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: gridItems.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final item = gridItems[index];
                  return GestureDetector(
                    onTap: item['onTap'],
                    child: Column(
                      children: <Widget>[
                        Icon(
                          item['icon'],
                          size: 40,
                          color: primaryColor,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item['title']!,
                          style: const TextStyle(fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),

                  );
                },
              ),
              const SizedBox(height: 20),
              // Changed this section to include the refresh button 13/7/2025
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Next Menstrual Cycle",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.black54),
                    onPressed: () {
                      // Call the refreshData method on the MenstrualAndPredictionDataDisplayState
                      _predictionDisplayKey.currentState?.refreshData();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Pass the GlobalKey to the MenstrualAndPredictionDataDisplay widget
              MenstrualAndPredictionDataDisplay(key: _predictionDisplayKey),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        currentIndex: 0,
        onTap: (index) async {
          if (index == 1) {
            await Navigator.pushNamed(context, '/Settings');
            _loadBoldTextSetting();
          }
        },
      ),
    );
  }
}

class MenstrualAndPredictionDataDisplay extends StatefulWidget {
  // Add key to the constructor
  const MenstrualAndPredictionDataDisplay({super.key});

  @override
  _MenstrualAndPredictionDataDisplayState createState() =>
      _MenstrualAndPredictionDataDisplayState();
}

class _MenstrualAndPredictionDataDisplayState extends State<MenstrualAndPredictionDataDisplay> {
  DateTime? predictedStartDate;
  DateTime? predictedEndDate;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // Public method to be called by the parent widget
  void refreshData() {
    setState(() {
      isLoading = true; // Show loading indicator during refresh
      predictedStartDate = null; // Clear previous data
      predictedEndDate = null;
    });
    _fetchData();
  }

  Future<void> _fetchData() async {
    DateTime now = DateTime.now(); // 'now' is correctly defined here for _fetchData

    try {
      // Fetch prediction data from local JSON
      List<Map<String, dynamic>> allPredictions = await LocalDataManager.readPredictions();

      if (allPredictions.isNotEmpty) {
        // Sort predictions by start date to ensure consistency, though not strictly needed for current month overlap
        allPredictions.sort((a, b) => DateTime.parse(a['expectedStart']).compareTo(DateTime.parse(b['expectedStart'])));

        // Find the prediction that overlaps with the current month
        DateTime firstDayOfCurrentMonth = DateTime(now.year, now.month, 1);
        // Get the last day of the current month by getting the 0th day of the next month
        DateTime lastDayOfCurrentMonth = DateTime(now.year, now.month + 1, 0);

        for (var prediction in allPredictions) {
          DateTime pStart = DateTime.parse(prediction['expectedStart']);
          DateTime pEnd = DateTime.parse(prediction['expectedEnd']);

          // Check if the prediction period [pStart, pEnd] overlaps with the current month [firstDayOfCurrentMonth, lastDayOfCurrentMonth]
          // Overlap condition: (start1 <= end2) AND (end1 >= start2)
          if ((pStart.isBefore(lastDayOfCurrentMonth) || pStart.isAtSameMomentAs(lastDayOfCurrentMonth)) &&
              (pEnd.isAfter(firstDayOfCurrentMonth) || pEnd.isAtSameMomentAs(firstDayOfCurrentMonth))) {
            predictedStartDate = pStart;
            predictedEndDate = pEnd;
            break; // Found the current month's prediction, exit loop
          }
        }
      } else {
        print("No local prediction data available from JSON.");
      }
    } catch (e) {
      print('Error fetching data for HomeScreen from local JSON: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (predictedStartDate == null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          "No prediction data available for the current month.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
      );
    }

    DateTime currentDateTime = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (predictedStartDate != null && predictedEndDate != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "This month start date:",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
                const SizedBox(height: 8),
                Text(
                  predictedStartDate!.toLocal().toString().split(' ')[0], // Display only date
                  style: const TextStyle(fontSize: 20, color: Colors.blue),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Will end in:",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
                const SizedBox(height: 8),
                Text(
                  predictedEndDate!.isAfter(currentDateTime)
                      ? "${predictedEndDate!.difference(currentDateTime).inDays} days"
                      : predictedEndDate!.toLocal().toString().split(' ')[0], // Display date if already passed
                  style: const TextStyle(fontSize: 20, color: Colors.blue),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}