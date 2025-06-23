import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddYourDataScreen extends StatefulWidget {
  final VoidCallback onSubmit;

  const AddYourDataScreen({super.key, required this.onSubmit});



  @override
  State<AddYourDataScreen> createState() => _AddYourDataScreenState();
}

class _AddYourDataScreenState extends State<AddYourDataScreen> {
  final TextEditingController ageController = TextEditingController();
  // symptomController is no longer needed
  List<String> selectedSymptoms = []; // Renamed from 'symptoms' for clarity with checkboxes
  String selectedContraception = '';

  final Model _model = Model();
  String predictedStart = '';
  String predictedEnd = '';


  // Predefined list of common menstrual cycle symptoms
  final List<String> menstrualCycleSymptoms = [
    'Cramps',
    'Bloating',
    'Headache',
    'Fatigue',
    'Mood swings',
    'Breast tenderness',
    'Acne',
    'Backache',
    'Nausea',
    'Diarrhea/Constipation',
    'Food cravings',
    'Irritability',
    'Anxiety',
    'Depression',
    'Difficulty concentrating',
  ];

  bool _boldText = false;
  double _fontSizeScale = 1.0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // addSymptom() method is no longer needed

  void selectContraception(String type) {
    setState(() {
      selectedContraception = type;
    });
  }

  void saveData() async {
    // Ensure Firebase is initialized before using Firestore/Auth
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'default_user_id'; // Fallback for testing

    if (userId == null) {
      // User is not logged in. Show an error or prompt to log in.
      print("Error saving data: User not authenticated.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Please log in to save your data.')),
      );
      return; // Stop execution if user is not authenticated
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'age': ageController.text.isNotEmpty ? int.parse(ageController.text) : null, // Convert age to int
        'symptoms': selectedSymptoms, // Save the list of selected symptoms
        'contraception': selectedContraception,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // Use merge: true to update existing doc without overwriting

      print("Data saved successfully!");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data saved successfully!')),
      );
      widget.onSubmit();
    } catch (e) {
      print("Error saving data: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving data: $e')),
      );
    }
  }

  // Helper widget for timeline sections (no change to this)
  Widget _buildTimelineInputSection({
    required IconData dotIcon,
    required Widget content,
    required bool showTopLine,
    required bool showBottomLine,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 2.0,
                height: 20.0,
                color: showTopLine ? Colors.white70 : Colors.transparent,
              ),
              Container(
                width: 28.0,
                height: 28.0,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red.shade400, width: 2.0),
                ),
                child: Center(
                  child: Icon(dotIcon, size: 16.0, color: Colors.red.shade400),
                ),
              ),
              Expanded(
                child: Container(
                  width: 2.0,
                  color: showBottomLine ? Colors.white70 : Colors.transparent,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16.0),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: content,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _boldText = prefs.getBool('boldText') ?? false;
      _fontSizeScale = prefs.getDouble('fontSizeScale') ?? 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title:  Text('Add Your Data', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 20 * _fontSizeScale,)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child:  Text('Cancel', style: TextStyle(color: Colors.black54, fontSize: 16 * _fontSizeScale,)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.orange.shade300,
              Colors.red.shade400,
            ],
          ),
        ),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Age Input Section (unchanged)
                    _buildTimelineInputSection(
                      dotIcon: Icons.calendar_today,
                      showTopLine: false,
                      showBottomLine: true,
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           Text('Age', style: TextStyle(fontSize: 16 * _fontSizeScale, color: Colors.black54)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: ageController,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration('Enter your age'),
                          ),
                        ],
                      ),
                    ),
                    // Symptom Checkbox Section (NEW)
                    _buildTimelineInputSection(
                      dotIcon: Icons.sick_outlined,
                      showTopLine: true,
                      showBottomLine: true,
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           Text('Symptoms', style: TextStyle(fontSize: 16 * _fontSizeScale, color: Colors.black54)),
                          const SizedBox(height: 8),
                          // user will have to choose symptom based on predefined symptoms using checkboxes
                          ...menstrualCycleSymptoms.map((symptom) {
                            return CheckboxListTile(
                              title: Text(symptom, style: const TextStyle(color: Colors.black87)),
                              value: selectedSymptoms.contains(symptom),
                              onChanged: (bool? isChecked) {
                                setState(() {
                                  if (isChecked == true) {
                                    selectedSymptoms.add(symptom);
                                  } else {
                                    selectedSymptoms.remove(symptom);
                                  }
                                });
                              },
                              activeColor: Colors.red.shade400, // Color when checked
                              checkColor: Colors.white, // Color of the checkmark
                              tileColor: Colors.white.withOpacity(0.6), // Background color of the tile
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.0), // Rounded corners for tiles
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                    // Contraception Type Section (unchanged in content, only wrapper)
                    _buildTimelineInputSection(
                      dotIcon: Icons.medication_outlined,
                      showTopLine: true,
                      showBottomLine: false,
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           Text('Type of contraception', style: TextStyle(fontSize: 16 * _fontSizeScale, fontWeight: _boldText ? FontWeight.bold : FontWeight.normal, color: Colors.black)),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: <Widget>[
                              _buildContraceptionOption(icon: Icons.medication_rounded, label: 'ORAL PILL'),
                             _buildContraceptionOption(icon: Icons.calendar_month, label: 'SELF REGULATION'),//USER WILL CHOOSE THIS IF THEY DONT USE ANY CONTRACEPTION
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Submit Button (unchanged)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  saveData();
                  await _runPredictionAndSave();
                  widget.onSubmit();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.lightBlue.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                ),
                child:  Text('SUBMIT', style: TextStyle(fontSize: 18 * _fontSizeScale, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }



  Future<void> _runPredictionAndSave() async {
    await _model.loadModel();

    // Example input — replace this with user data
    List<List<List<double>>> inputData = [
      [
        [0.1, 0.2, 0.3, 0.4, 0.5],
        [0.2, 0.3, 0.4, 0.5, 0.6],
        [0.3, 0.4, 0.5, 0.6, 0.7],
        [0.4, 0.5, 0.6, 0.7, 0.8],
        [0.5, 0.6, 0.7, 0.8, 0.9],
      ]
    ];

    List<dynamic> prediction = await _model.predict(inputData);

    int daysUntilNextPeriod = prediction[0].round();
    DateTime predictedStartDate = DateTime.now().add(Duration(days: daysUntilNextPeriod));
    DateTime predictedEndDate = predictedStartDate.add(Duration(days: 5)); // Example: 5-day period

    // Update UI with predicted dates
    setState(() {
      predictedStart = predictedStartDate.toIso8601String();
      predictedEnd = predictedEndDate.toIso8601String();
    });

    // Save to Firebase
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      await FirebaseFirestore.instance.collection('users').doc(userId).collection('predictions').doc('nextCycle').set({
        'expectedStart': predictedStartDate.toIso8601String(),
        'expectedEnd': predictedEndDate.toIso8601String(),
      });
      print('Prediction saved to Firebase.');
    }
  }


  InputDecoration _inputDecoration(String hintText) {
    return InputDecoration(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30.0),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: Colors.white.withOpacity(0.8),
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.black45),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
    );
  }

  Widget _buildContraceptionOption({required IconData icon, required String label}) {
    final isSelected = selectedContraception == label;
    return GestureDetector(
      onTap: () => selectContraception(label),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: isSelected ? Colors.pink.shade100.withOpacity(0.8) : Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(25.0),
              border: isSelected ? Border.all(color: Colors.pink, width: 2) : null,
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: Colors.pink.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Icon(icon, size: 30, color: Colors.pink.shade200),
          ),
          const SizedBox(height: 8),
          Text(label, style:  TextStyle(fontSize: 12 * _fontSizeScale, color: Colors.black87)),
        ],
      ),
    );
  }
}
