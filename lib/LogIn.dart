import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fypproject/Register.dart';
import 'package:google_fonts/google_fonts.dart';

import 'Homepage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Login Screen',
      theme: ThemeData(
        fontFamily: GoogleFonts.oswald().fontFamily,  // Set Oswald as the main font
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: LoginScreen(
        onSubmit: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => MyHomeScreen()), // Redirect to home screen
          );
        },
        onNewUser: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => RegistrationScreen(onCreateProfile: onCreateProfile)), // Redirect to registration screen
          );
        },
      ),
    );
  }

  @override
  State<StatefulWidget> createState() {
    // TODO: implement createState
    throw UnimplementedError();
  }

  void onCreateProfile() {}
}

class LoginScreen extends StatelessWidget {
  final VoidCallback onSubmit;
  final VoidCallback onNewUser;

  // Controllers for Firebase database username and password
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  LoginScreen({super.key, required this.onSubmit, required this.onNewUser});

  // Reusable TextField Widget to avoid code duplication....supaya tak ulang code sama banyak kali...inheritance :')
  Widget buildTextField(TextEditingController controller, String hintText) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.lightBlue[300],
        hintText: hintText,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30.0),
          borderSide: BorderSide.none,
        ),
      ),
    );
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
            stops: [
              0.3,
              0.7,
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 50.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          SystemNavigator.pop();
                        },
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 50.0),
                CircleAvatar(
                  radius: 60.0,
                  backgroundColor: Colors.purple[200],
                  child: const Icon(
                    Icons.medical_information,
                    size: 70.0,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 50.0),

                // Reusable text fields
                buildTextField(usernameController, 'Username'),
                const SizedBox(height: 20.0),
                buildTextField(passwordController, 'Password'),

                const SizedBox(height: 30.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Submit Button with error handling
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          await FirebaseAuth.instance.signInWithEmailAndPassword(
                            email: usernameController.text.trim(),
                            password: passwordController.text.trim(),
                          );
                          onSubmit(); // Move to Calendar
                        } catch (e) {
                          print("Login failed: $e");
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Login failed. Please check your credentials.')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lightGreen[800],
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        textStyle: const TextStyle(fontSize: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                      ),
                      child: const Text('submit', style: TextStyle(color: Colors.black)),
                    ),
                    const SizedBox(width: 20.0),

                    // Corrected the onPressed method for "new user" button
                    ElevatedButton(
                      onPressed: onNewUser,  // Just pass the function without invoking it
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lightBlue[800],
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                        textStyle: const TextStyle(fontSize: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                      ),
                      child: const Text('new user', style: TextStyle(color: Colors.black)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
