import 'package:flutter/material.dart';

class AddHabitPage extends StatelessWidget {
  final TextEditingController controller = TextEditingController();

  AddHabitPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Habit"),
        backgroundColor: const Color.fromRGBO(31, 31, 31, 1),
      ),
      backgroundColor: const Color.fromRGBO(31, 31, 31, 1),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "নতুন Habit লিখুন (যেমন: Study 1 hour)",
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, controller.text);
                },
                child: const Text("Save"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
