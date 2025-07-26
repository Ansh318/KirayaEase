import 'package:flutter/material.dart';
import 'screens/landing_page.dart';
import 'screens/login_page.dart';
import 'screens/home_page.dart';

void main() {
  runApp(const KirayaEaseApp());
}

class KirayaEaseApp extends StatelessWidget {
  const KirayaEaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const LandingPage(), // 📣 Intro screen
        '/login': (context) => const LoginPage(), // 🔐 OTP login
        '/home': (context) => const HomePage(), // 🏡 After login
      },
    );
  }
}
