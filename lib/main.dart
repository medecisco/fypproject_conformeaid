import 'package:flutter/material.dart';
import 'LogIn.dart';
import 'Register.dart';
import 'AddData.dart';
import 'calender.dart';
import 'ManageReminder.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  runApp(const conformeaid());
}

class conformeaid extends StatelessWidget {
  const conformeaid({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'conformeaid',
      theme: ThemeData(
        primarySwatch: Colors.pink,
      ),
      initialRoute: '/LogIn',
      routes: {
        '/LogIn': (context) => LoginScreen(
          onSubmit: () => Navigator.pushNamed(context, '/calendar'),
          onNewUser: () => Navigator.pushNamed(context, '/Register'),
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