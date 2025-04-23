import 'package:flutter/material.dart';

class AddYourDataScreen extends StatefulWidget {
  final VoidCallback onSubmit;

  const AddYourDataScreen({super.key, required this.onSubmit});

  @override
  State<AddYourDataScreen> createState() => _AddYourDataScreenState();
}

class _AddYourDataScreenState extends State<AddYourDataScreen> {
  final TextEditingController ageController = TextEditingController();
  final TextEditingController symptomController = TextEditingController();
  List<String> symptoms = [];
  String selectedContraception = '';

  void addSymptom() {
    final text = symptomController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        symptoms.add(text);
        symptomController.clear();
      });
    }
  }

  void selectContraception(String type) {
    setState(() {
      selectedContraception = type;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange.shade300,
        title: const Text('Add Your Data', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('cancel', style: TextStyle(color: Colors.black54)),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('age', style: TextStyle(fontSize: 16, color: Colors.black54)),
            const SizedBox(height: 8),
            TextField(
              controller: ageController,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration('Enter your age'),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('symptom', style: TextStyle(fontSize: 16, color: Colors.black54)),
                IconButton(
                  onPressed: addSymptom,
                  icon: const Icon(Icons.add_circle_outline, color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: symptomController,
              decoration: _inputDecoration('Enter your symptom'),
            ),
            ...symptoms.map((symptom) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, size: 18, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(symptom),
                ],
              ),
            )),
            const SizedBox(height: 24),
            const Text('Type of contraception', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                _buildContraceptionOption(icon: Icons.format_shapes, label: 'IUD'),
                _buildContraceptionOption(icon: Icons.view_agenda, label: 'ORAL PILL'),
                _buildContraceptionOption(icon: Icons.local_hospital, label: 'INJECTION'),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  print('Age: ${ageController.text}');
                  print('Symptoms: $symptoms');
                  print('Contraception: $selectedContraception');
                  widget.onSubmit();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.lightBlue.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                ),
                child: const Text('SUBMIT', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hintText) {
    return InputDecoration(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30.0),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: Colors.lightBlue.shade100,
      hintText: hintText,
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
              color: isSelected ? Colors.pink.shade100 : Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(25.0),
              border: isSelected ? Border.all(color: Colors.pink, width: 2) : null,
            ),
            child: Icon(icon, size: 30, color: Colors.pink.shade200),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
