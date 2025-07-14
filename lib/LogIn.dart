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
  State<StatefulWidget> createState() {
    return _MyAppState();
  }

  void onCreateProfile() {}
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Login Screen',
      theme: ThemeData(
        fontFamily: GoogleFonts.oswald().fontFamily,
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: LoginScreen(
        onSubmit: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => HomeScreen(
                      onNavigateToTimeline: () {},
                      onNavigateToReminder: () {},
                      onNavigateToProfile: () {},
                ),
            ),
          );
        },
        onNewUser: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => RegistrationScreen(onCreateProfile: widget.onCreateProfile)),
          );
        },
      ),
    );
  }
}


class LoginScreen extends StatefulWidget {
  final VoidCallback onSubmit;
  final VoidCallback onNewUser;

  const LoginScreen({super.key, required this.onSubmit, required this.onNewUser});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _obscureText = true;

  Widget buildTextField(TextEditingController controller, String hintText, {IconData? prefixIcon, bool isPassword = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? _obscureText : false,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(0.9),
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey[700]),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: Colors.grey[700]) : null,
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(
            _obscureText ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey[700],
          ),
          onPressed: () {
            setState(() {
              _obscureText = !_obscureText;
            });
          },
        )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30.0),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30.0),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30.0),
          borderSide: BorderSide.none,
        ),
      ),
      style: const TextStyle(color: Colors.black),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    // Estimate the height of the fixed header Row including its top padding
    // 48.0 is a common height for an IconButton/Text, + 20.0 padding
    const double fixedHeaderTotalHeight = kToolbarHeight; // Use kToolbarHeight for standard app bar height
    // Or, a custom fixed height based on current padding and content:
    // const double fixedHeaderHeight = 24.0 + (48.0); // fontSize + approx icon/text height + 20.0 padding
    // So, total fixed height will be statusBarHeight + 20.0 (top padding) + the height of the row content itself.
    // Let's use an approximate height for the row for calculation purposes.
    const double rowContentHeight = 48.0; // Standard height for IconButton/Text in a row
    final double totalFixedHeaderArea = statusBarHeight + 20.0 + rowContentHeight;


    return Scaffold(
      backgroundColor: Colors.transparent, // Ensure Scaffold background is transparent
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
        child: Stack(
          children: [
            // 1. Scrollable content area (avatar, inputs, buttons)
            Positioned.fill(
              // The content starts below the fixed header area
              top: totalFixedHeaderArea,
              child: SingleChildScrollView(
                // Apply horizontal padding here for the scrollable content
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // This SizedBox now provides the space *below* the fixed header.
                    // It effectively acts as the 'original' 100.0 space that was
                    // below the header before it became fixed.
                    const SizedBox(height: 100.0),
                    CircleAvatar(
                      radius: 60.0,
                      backgroundColor: Colors.white,
                      child: const Icon(
                        Icons.medical_information,
                        size: 70.0,
                        color: Colors.amber,
                      ),
                    ),
                    const SizedBox(height: 70.0), // Space between avatar and text fields

                    buildTextField(usernameController, 'Email', prefixIcon: Icons.email),
                    const SizedBox(height: 20.0),
                    buildTextField(passwordController, 'Password', prefixIcon: Icons.vpn_key, isPassword: true),

                    const SizedBox(height: 30.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            try {
                              await FirebaseAuth.instance.signInWithEmailAndPassword(
                                email: usernameController.text.trim(),
                                password: passwordController.text.trim(),
                              );
                              widget.onSubmit();
                            } on FirebaseAuthException catch (e) {
                              String errorMessage = 'Login failed. Please check your credentials.';
                              if (e.code == 'user-not-found') {
                                errorMessage = 'No user found for that email.';
                              } else if (e.code == 'wrong-password') {
                                errorMessage = 'Wrong password provided for that user.';
                              }
                              print("Login failed: $e");
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(errorMessage)),
                              );
                            } catch (e) {
                              print("An unexpected error occurred: $e");
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('An unexpected error occurred. Please try again.')),
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
                          child: const Text('submit', style: TextStyle(color: Colors.white)),
                        ),
                        const SizedBox(width: 20.0),

                        ElevatedButton(
                          onPressed: widget.onNewUser,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.lightBlue[800],
                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                            textStyle: const TextStyle(fontSize: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20.0),
                            ),
                          ),
                          child: const Text('new user', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                    // Add padding at the bottom to ensure content above keyboard is visible and scrollable
                    SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? MediaQuery.of(context).viewInsets.bottom + 20 : 20),
                  ],
                ),
              ),
            ),

            // 2. Fixed Header (x button and Login text)
            Positioned(
              top: statusBarHeight + 20.0, // Top padding for the header to match Register screen level
              left: 16.0, // Horizontal padding for the header to match scrollable content
              right: 16.0,
              // The height property is not strictly necessary here as the row will size itself,
              // but can be added for clarity if desired.
              // height: fixedHeaderHeight,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black),
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
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48.0), // Placeholder to center "Login" text
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}