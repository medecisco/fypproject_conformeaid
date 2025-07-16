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
import 'local_data_manager.dart'; // Import the local data manager

// Define your app's main color palette for consistency
const Color kPrimaryColor = Color(0xFFE67A82); // Soft red/pink
const Color kSecondaryColor = Color(0xFFF5C75E); // Warm yellow/orange
const Color kLightBackgroundColor = Color(0xFFFFF7F2); // Very light peach/pink for backgrounds
const Color kDarkTextColor = Color(0xFF333333); // Darker text for readability
const Color kLightTextColor = Color(0xFF757575); // Lighter text for secondary info

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ConformeAid',
      debugShowCheckedModeBanner: false, // Keep debug banner off
      theme: ThemeData(
        fontFamily: GoogleFonts.inter().fontFamily,
        // Use your defined primary color for the overall theme
        primaryColor: kPrimaryColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimaryColor, // Set seed color to your primary accent
          primary: kPrimaryColor,
          secondary: kSecondaryColor,
          background: kLightBackgroundColor,
          // Removed 'surface' as it's not for gradients and is not typically a list of colors
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent, // Make app bar background transparent
          elevation: 0, // No shadow for a flat look
          iconTheme: IconThemeData(color: kDarkTextColor), // Dark icons
          titleTextStyle: TextStyle(
            color: kDarkTextColor,
            fontSize: 20,
            fontWeight: FontWeight.bold, // Default app bar title bold
          ),
        ),
        scaffoldBackgroundColor: Colors.transparent, // Set scaffold background to transparent
        visualDensity: VisualDensity.adaptivePlatformDensity,
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
        '/calender': (context) => TimelineScreen(onNavigateToReminder: () {}),
        '/ManageReminder': (context) => ManageReminderScreen(onNavigateToTimeline: () {}),
        '/AddData': (context) => AddYourDataScreen(onSubmit: () {}),
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
    const TextStyle bodyTextStyle = TextStyle(
      fontSize: 16,
      color: kLightTextColor, // Use defined light text color
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
      // Set Scaffold background to transparent to allow the body's gradient to show through
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        // Colors and elevation are set in MyApp's ThemeData for consistency
        leading: IconButton(
          icon: const Icon(Icons.logout_rounded, color: kDarkTextColor), // Use defined dark text color
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            SystemNavigator.pop();
          },
        ),
        title: Text(
          "Conforme Aid",
          style: TextStyle(
            color: kDarkTextColor, // Use defined dark text color
            fontWeight: _boldText ? FontWeight.bold : FontWeight.normal,
            fontSize: 22, // Slightly larger title for impact
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: kDarkTextColor),
            onPressed: () async {
              await Navigator.pushNamed(context, '/Settings');
              _loadBoldTextSetting(); // Reload settings after returning from settings page
            },
          ),
        ],
      ),
      // Apply the gradient to the body of the Scaffold
      body: Container( // This container ensures the gradient fills the available space
        width: double.infinity, // Ensure it takes full width
        height: double.infinity, // Ensure it takes full height
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kLightBackgroundColor, kSecondaryColor, kPrimaryColor], // Your desired gradient colors
            stops: [0.0, 0.5, 1.0], // Optional: control where each color begins and ends
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0), // Increased padding for better breathing room
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SizedBox(height: 20),
                Text(
                  'What do you want to check today?',
                  style: bodyTextStyle.copyWith(
                    fontSize: 18, // Slightly larger for prominence
                    fontWeight: _boldText ? FontWeight.bold : FontWeight.w600, // Make it bold if setting enabled
                    color: kDarkTextColor, // Make it darker
                  ),
                ),
                const SizedBox(height: 25), // Increased spacing
                GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12, // Increased spacing
                    mainAxisSpacing: 12, // Increased spacing
                    childAspectRatio: 0.9, // Adjust aspect ratio for better fit
                  ),
                  itemCount: gridItems.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    final item = gridItems[index];
                    return GestureDetector(
                      onTap: item['onTap'],
                      child: Card( // Use Card for a nice elevated look
                        elevation: 4, // Subtle shadow
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15), // Rounded corners
                        ),
                        color: Colors.white, // White background for grid items
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Icon(
                                item['icon'],
                                size: 45, // Slightly larger icon
                                color: kPrimaryColor, // Use primary color
                              ),
                              const SizedBox(height: 10), // Increased spacing
                              Text(
                                item['title']!,
                                style: TextStyle(
                                  fontSize: 14, // Slightly larger text
                                  fontWeight: _boldText ? FontWeight.bold : FontWeight.w500, // Make text bold if setting enabled
                                  color: kDarkTextColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40), // Increased spacing before next section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Next Menstrual Cycle",
                      style: TextStyle(
                        fontSize: 22, // Adjusted font size
                        fontWeight: _boldText ? FontWeight.bold : FontWeight.w600,
                        color: kDarkTextColor,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: kLightTextColor), // Use lighter text color for icon
                      onPressed: () {
                        _predictionDisplayKey.currentState?.refreshData();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 15), // Increased spacing
                // Pass the GlobalKey to the MenstrualAndPredictionDataDisplay widget
                MenstrualAndPredictionDataDisplay(key: _predictionDisplayKey),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white, // White background for the bar
        elevation: 8, // Subtle shadow for depth
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
        selectedItemColor: kPrimaryColor, // Use primary color for selected item
        unselectedItemColor: kLightTextColor, // Use lighter text color for unselected
        currentIndex: 0,
        onTap: (index) async {
          if (index == 1) {
            await Navigator.pushNamed(context, '/Settings');
            _loadBoldTextSetting(); // Reload bold text setting after returning
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
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  void refreshData() {
    setState(() {
      isLoading = true;
      predictedStartDate = null;
      predictedEndDate = null;
    });
    _fetchData();
  }

  Future<void> _fetchData() async {
    DateTime now = DateTime.now();

    try {
      List<Map<String, dynamic>> allPredictions = await LocalDataManager.readPredictions();

      if (allPredictions.isNotEmpty) {
        allPredictions.sort((a, b) =>
            DateTime.parse(a['expectedStart']).compareTo(DateTime.parse(b['expectedStart'])));

        DateTime firstDayOfCurrentMonth = DateTime(now.year, now.month, 1);
        DateTime lastDayOfCurrentMonth = DateTime(now.year, now.month + 1, 0);

        for (var prediction in allPredictions) {
          DateTime pStart = DateTime.parse(prediction['expectedStart']);
          DateTime pEnd = DateTime.parse(prediction['expectedEnd']);

          if ((pStart.isBefore(lastDayOfCurrentMonth) || pStart.isAtSameMomentAs(lastDayOfCurrentMonth)) &&
              (pEnd.isAfter(firstDayOfCurrentMonth) || pEnd.isAtSameMomentAs(firstDayOfCurrentMonth))) {
            predictedStartDate = pStart;
            predictedEndDate = pEnd;
            break;
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
      return const Center(child: CircularProgressIndicator(color: kPrimaryColor)); // Consistent loading color
    }

    if (predictedStartDate == null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20), // More padding
        decoration: BoxDecoration(
          color: kSecondaryColor.withOpacity(0.2), // Use secondary color for "no data" alert
          borderRadius: BorderRadius.circular(15), // Rounded corners
          border: Border.all(color: kSecondaryColor, width: 1.5), // Subtle border
        ),
        child: Text(
          "No prediction data available for the current month. Please add cycle history in your Profile.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16, // Adjusted font size
            fontWeight: FontWeight.w600, // Medium bold
            color: kDarkTextColor, // Consistent text color
          ),
        ),
      );
    }

    DateTime currentDateTime = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20), // Increased padding
          decoration: BoxDecoration(
            color: Colors.white, // White background for the card
            borderRadius: BorderRadius.circular(15), // Rounded corners
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1), // Subtle shadow
                spreadRadius: 2,
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "This month's start date:",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: kDarkTextColor.withOpacity(0.8), // Slightly muted bold text
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "${predictedStartDate!.day} ${['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][predictedStartDate!.month - 1]} ${predictedStartDate!.year}",
                style: TextStyle(fontSize: 20, color: kPrimaryColor, fontWeight: FontWeight.bold), // Prominent date
              ),
              const SizedBox(height: 15), // More spacing
              Text(
                "Expected end date:",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: kDarkTextColor.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                predictedEndDate!.isAfter(currentDateTime)
                    ? "${predictedEndDate!.difference(currentDateTime).inDays} days left" // More descriptive text
                    : "${predictedEndDate!.day} ${['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][predictedEndDate!.month - 1]} ${predictedEndDate!.year} (Ended)", // Display date if already passed
                style: TextStyle(
                  fontSize: 20,
                  color: predictedEndDate!.isAfter(currentDateTime) ? kPrimaryColor : kLightTextColor, // Color based on status
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}