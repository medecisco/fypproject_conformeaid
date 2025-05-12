import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'AddData.dart';
import 'Homepage.dart';
import 'LogIn.dart';
import 'ManageReminder.dart';
import 'Register.dart';
import 'calender.dart';
import 'model.dart'; // Import the model.dart file

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  tz.initializeTimeZones();
  runApp(const ConformeAidApp());
}

class ConformeAidApp extends StatefulWidget {
  const ConformeAidApp({super.key});

  @override
  State<ConformeAidApp> createState() => _ConformeAidAppState();
}

class _ConformeAidAppState extends State<ConformeAidApp> {
  Model _model = Model();  // Create an instance of your model

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    await _model.loadModel();  // Load the model when the app starts
    print('Model Loaded');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ConformeAid',
      theme: ThemeData(
        primarySwatch: Colors.pink,
      ),
      initialRoute: '/LogIn',
      routes: {
        '/LogIn': (context) => LoginScreen(
          onSubmit: () => Navigator.pushNamed(context, '/Homepage'),
          onNewUser: () => Navigator.pushNamed(context, '/Register'),
        ),
        '/Homepage': (context) => HomeScreen(
          onNavigateToTimeline: () => Navigator.pushNamed(context, '/calendar'),
          onNavigateToReminder: () => Navigator.pushNamed(context, '/ManageReminder'),
          onNavigateToProfile: () => Navigator.pushNamed(context, '/AddData'),
        ),
        '/Register': (context) => RegistrationScreen(
          onCreateProfile: () => Navigator.pushNamed(context, '/AddData'),
        ),
        '/AddData': (context) => AddYourDataScreen(
          onSubmit: () => Navigator.pushNamed(context, '/calendar'),
        ),
        '/calendar': (context) => TimelineScreen(
          onNavigateToReminder: () => Navigator.pushNamed(context, '/ManageReminder'),
        ),
        '/ManageReminder': (context) => ManageReminderScreen(
          onNavigateToTimeline: () => Navigator.pushNamed(context, '/calendar'),
        ),
      },
    );
  }
}
