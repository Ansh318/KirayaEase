import 'package:flutter/material.dart';
import 'screens/landing_page.dart';
import 'screens/login_page.dart';
import 'screens/home_page.dart';
import 'screens/tenant.dart';
import 'screens/landlord.dart';
import 'screens/property_manager.dart';
import 'screens/splash_screen.dart';
import 'screens/pricing.dart';
import 'screens/mission.dart';

void main() {
  runApp(const KirayaEaseApp());
}

class KirayaEaseApp extends StatelessWidget {
  const KirayaEaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/': (context) => const LandingPage(), // 📣 Intro screen
        '/login': (context) => const LoginPage(), // 🔐 OTP login
        '/home': (context) => const HomePage(), // 🏡 After login
        '/tenant': (context) => const TenantDashboard(), // Tenant Features
        '/landlord': (context) =>
            const LandlordDashboard(), // Landlord Features
        '/property-manager': (context) => const PropertyManagerDashboard(),
        '/pricing': (context) => const PricingPage(),
        '/mission': (context) => const MissionSection(),
      },
    );
  }
}
