import 'package:flutter/material.dart';

class TenantDashboard extends StatelessWidget {
  const TenantDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tenant Dashboard'),
        backgroundColor: const Color(0xFF00C6A6),
      ),
      body: const Center(
        child: Text(
          '🏠 Welcome, Tenant!',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
