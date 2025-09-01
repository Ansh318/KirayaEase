import 'package:flutter/material.dart';

// Screens
import 'screens/landing_page.dart';
import 'screens/login_page.dart';
import 'screens/home_page.dart';
import 'screens/tenant.dart';
import 'screens/landlord.dart';
import 'screens/property_manager.dart';
import 'screens/splash_screen.dart';
import 'screens/pricing.dart';
import 'screens/mission.dart';
import 'screens/landlord_info.dart';
import 'screens/tenant_info.dart';
import 'screens/technology_info.dart';
import 'screens/learn.dart';

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
        '/splash': (context) => const SplashScreen(),
        '/': (context) => const LandingPage(), // 📣 Intro screen
        '/login': (context) => const LoginPage(), // 🔐 OTP login
        '/home': (context) => const HomePage(), // 🏡 After login
        '/tenant': (context) => const TenantDashboard(), // 👥 Tenant view
        '/landlord': (context) =>
            const LandlordDashboard(), // 🧑‍💼 Landlord view
        '/pricing': (context) => const PricingPage(), // 💰 Plans
        '/mission': (context) => const MissionSection(), // 🌱 Vision & Mission
        '/landlord-info': (context) => const LandlordInfoPage(), // 📘 Info page
        '/tenant-info': (context) => const TenantInfo(), // 📘 Info page
        '/technology': (context) => const TechnologyInfo(), // 💻 Tech
        '/learn': (context) => const LearnPage(), // 📚 Learn Hub
        '/properties': (context) => const PropertyPage(),
      },
    );
  }
}
