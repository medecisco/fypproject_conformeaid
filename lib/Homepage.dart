import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // For Firebase integration
import 'package:google_fonts/google_fonts.dart';// for Google Fonts

import 'LogIn.dart';

void main() {
  runApp(const MyApp());
}

class MyHomeScreen extends StatelessWidget {
  const MyHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Homepage',
      theme: ThemeData(
        fontFamily: GoogleFonts.inter().fontFamily, // Define the main font using Google Fonts
        primarySwatch: Colors.blue, // Customize as needed
        visualDensity: VisualDensity.adaptivePlatformDensity,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onNavigateToTimeline,
    required this.onNavigateToReminder,
    required this.onNavigateToProfile,
  });

  final void Function() onNavigateToTimeline;
  final void Function() onNavigateToReminder;
  final void Function() onNavigateToProfile;

  @override
  Widget build(BuildContext context) {
    // Define reusable colors and styles
    const Color primaryColor = Color(0xFFF5C75E);
    const TextStyle titleTextStyle = TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: Colors.black87,
    );
    const TextStyle bodyTextStyle = TextStyle(
      fontSize: 16,
      color: Colors.black54,
    );

    // Define grid items with appropriate navigation actions
    final List<Map<String, dynamic>> gridItems = [
      {
        'title': 'Timeline',
        'icon': Icons.calendar_month, // Using MaterialApp Icons
        'onTap': onNavigateToTimeline, // Navigate to Timeline
      },
      {
        'title': 'Reminder',
        'icon': Icons.alarm, // Using MaterialApp Icons
        'onTap': onNavigateToReminder, // Navigate to Reminder
      },
      {
        'title': 'Profile',
        'icon': Icons.medical_information, // Using MaterialApp Icons
        'onTap': onNavigateToProfile, // Navigate to Profile
      },
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0, // Remove shadow
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black87),
          onPressed: () {
            // Handle menu button press
          },
        ),
        title: const Text(
          "Conforme Aid",
          style: TextStyle(color: Colors.black87),
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
              const Text('What do you want to learn today?', style: bodyTextStyle),
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

              // Menstrual Data Display (Show days until next period)
              const Text(
                "Next Menstrual Cycle",
                style: titleTextStyle,
              ),
              const SizedBox(height: 10),
              const MenstrualDataDisplay(), // Custom widget to fetch and display data
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
        onTap: (index) {
          // Handle bottom navigation item taps
        },
      ),
    );
  }
}

class MenstrualDataDisplay extends StatefulWidget {
  const MenstrualDataDisplay({super.key});

  @override
  _MenstrualDataDisplayState createState() => _MenstrualDataDisplayState();
}

class _MenstrualDataDisplayState extends State<MenstrualDataDisplay> {
  String? userId;
  DateTime? nextPeriod;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      _fetchMenstrualData();
    }
  }

  // Fetch menstrual data from Firestore
  Future<void> _fetchMenstrualData() async {
    try {
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('menstrual_data')
          .doc(userId)
          .get();

      if (snapshot.exists) {
        setState(() {
          nextPeriod = snapshot['nextPeriod']?.toDate(); // Convert to DateTime
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      // Handle error
      setState(() {
        isLoading = false;
      });
      print("Error fetching menstrual data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const CircularProgressIndicator();
    }

    if (nextPeriod == null) {
      return const Text("No menstrual data available.");
    }

    // Calculate days until the next period
    final daysUntilNextPeriod = nextPeriod!.difference(DateTime.now()).inDays;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey,
            spreadRadius: 2,
            blurRadius: 4,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Your next period is in:",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "$daysUntilNextPeriod days",
            style: const TextStyle(fontSize: 20, color: Colors.blue),
          ),
          const SizedBox(height: 8),
          Text(
            "Date: ${nextPeriod!.toLocal().day}-${nextPeriod!.toLocal().month}-${nextPeriod!.toLocal().year}",
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}