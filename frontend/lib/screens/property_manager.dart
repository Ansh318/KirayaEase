import 'package:flutter/material.dart';

class PropertyManagerDashboard extends StatelessWidget {
  const PropertyManagerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Property Manager Dashboard'),
        backgroundColor: const Color(0xFF00C6A6),
      ),
      body: const Center(
        child: Text(
          '🛠️ Welcome, Property Manager!',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
