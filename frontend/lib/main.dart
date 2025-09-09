import 'package:flutter/material.dart';
// Screens
import 'screens/landing_page.dart';
import 'screens/login_page.dart';
import 'screens/home_page.dart';
import 'screens/tenant.dart';
import 'screens/mission.dart';
import 'screens/tenant_info.dart';
import 'screens/technology_info.dart';
import 'screens/learn.dart';
import 'screens/settings.dart';

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
        '/tenant': (context) => const TenantDashboard(), // 👥 Tenant view
        '/mission': (context) => const MissionSection(), // 🌱 Vision & Mission
        '/tenant-info': (context) => const TenantInfo(), // 📘 Info page
        '/technology': (context) => const TechnologyInfo(), // 💻 Tech
        '/learn': (context) => const LearnPage(),
        '/settings': (context) => const SettingsPage(), // 📚 Learn Hub
      },
    );
  }
}
