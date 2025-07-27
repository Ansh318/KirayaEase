import 'package:flutter/material.dart';

class LandlordDashboard extends StatelessWidget {
  const LandlordDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Landlord Dashboard'),
        backgroundColor: const Color(0xFF00C6A6),
      ),
      body: const Center(
        child: Text(
          '📊 Welcome, Landlord!',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
