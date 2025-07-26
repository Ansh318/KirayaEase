import 'package:flutter/material.dart';
import 'nav_bar.dart';

class BaseScaffold extends StatelessWidget {
  final Widget child;

  const BaseScaffold(
      {super.key, required this.child}); // ✅ make sure `child` is defined

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // ✅ to let content go behind blur
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFA6F0EB), Color(0xFFC2F4FB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Content layer
          Column(
            children: [
              const NavBar(), // ✅ Blurred navbar
              Expanded(child: child), // ✅ Dynamic page content
            ],
          ),
        ],
      ),
    );
  }
}
