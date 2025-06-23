import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'LogIn.dart';
import 'settings_page.dart';
import 'calender.dart';
import 'ManageReminder.dart';
import 'AddData.dart';

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
              const Text(
                "Next Menstrual Cycle",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 10),
              const MenstrualAndPredictionDataDisplay(), // Consolidated widget
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
  const MenstrualAndPredictionDataDisplay({super.key});

  @override
  _MenstrualAndPredictionDataDisplayState createState() =>
      _MenstrualAndPredictionDataDisplayState();
}

class _MenstrualAndPredictionDataDisplayState extends State<MenstrualAndPredictionDataDisplay> {
  DateTime? predictedStartDate;
  DateTime? predictedEndDate;
  DateTime? nextPeriod;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId != null) {
      try {
        DocumentSnapshot menstrualSnapshot = await FirebaseFirestore.instance
            .collection('menstrual_data')
            .doc(userId)
            .get();

        DocumentSnapshot predictionSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('predictions')
            .doc('nextCycle')
            .get();

        if (menstrualSnapshot.exists) {
          nextPeriod = menstrualSnapshot['nextPeriod']?.toDate();
        }

        if (predictionSnapshot.exists) {
          predictedStartDate = DateTime.parse(predictionSnapshot['expectedStart']);
          predictedEndDate = DateTime.parse(predictionSnapshot['expectedEnd']);
        }
      } catch (e) {
        print('Error fetching data: $e');
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    } else {
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

    if (nextPeriod == null && predictedStartDate == null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          "No menstrual or prediction data available.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (nextPeriod != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFF5C75E),
                  Color(0xFFE67A82),
                ],
                stops: [0.3, 0.7],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Your next period is in:",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  "${nextPeriod!.difference(DateTime.now()).inDays} days",
                  style: const TextStyle(fontSize: 20, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  "Date: ${nextPeriod!.toLocal().day}-${nextPeriod!.toLocal().month}-${nextPeriod!.toLocal().year}",
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
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
                  "Predicted Start of next period:",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
                const SizedBox(height: 8),
                Text(
                  predictedStartDate!.toLocal().toString().split(' ')[0], // Display only date
                  style: const TextStyle(fontSize: 20, color: Colors.blue),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Predicted End of next period:",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
                const SizedBox(height: 8),
                Text(
                  predictedEndDate!.toLocal().toString().split(' ')[0], // Display only date
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
