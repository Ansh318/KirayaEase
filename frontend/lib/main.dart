import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_mobile_options.dart';
import 'firebase_messaging_background.dart';
import 'route_observer.dart';
import 'package:kirayaease_flutter/screens/lease_management.dart';
import 'package:kirayaease_flutter/screens/payments_page.dart';
// Screens
import 'screens/landing_page.dart';
import 'screens/login_page.dart';
import 'screens/home_page.dart';
import 'screens/tenant.dart';
import 'screens/mission.dart';
import 'screens/tenant_info.dart';
import 'screens/landlord_info.dart';
import 'screens/technology_info.dart';
import 'screens/learn.dart';
import 'screens/settings.dart';
import 'screens/faq.dart';
import 'screens/about.dart';
import 'screens/pricing.dart';
import 'screens/rent_reporting.dart';
import 'screens/account.dart';
import 'dart:io' show Platform;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with explicit options from GoogleService-Info.plist
  // This is needed because the plist file might not be properly linked in Xcode
  try {
    if (Platform.isIOS) {
      debugPrint('Initializing Firebase for iOS...');
      await Firebase.initializeApp(options: kIosFirebaseOptions);
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      debugPrint('Firebase initialized successfully for iOS');
    } else {
      debugPrint('Initializing Firebase for other platform...');
      await Firebase.initializeApp();
      debugPrint('Firebase initialized successfully');
    }
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    // Try default initialization as fallback
    try {
      await Firebase.initializeApp();
      debugPrint('Firebase initialized with default options');
    } catch (e2) {
      debugPrint('Firebase initialization completely failed: $e2');
      // Continue anyway - some features might still work
    }
  }
  
  runApp(const KirayaEaseApp());
}

class KirayaEaseApp extends StatelessWidget {
  const KirayaEaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [appRouteObserver],
      debugShowCheckedModeBanner: false,
      // Configure text theme to support emojis and Unicode characters
      theme: ThemeData(
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontFamily: null), // Use system default which supports emojis
          bodyMedium: TextStyle(fontFamily: null),
          bodySmall: TextStyle(fontFamily: null),
          displayLarge: TextStyle(fontFamily: null),
          displayMedium: TextStyle(fontFamily: null),
          displaySmall: TextStyle(fontFamily: null),
          headlineLarge: TextStyle(fontFamily: null),
          headlineMedium: TextStyle(fontFamily: null),
          headlineSmall: TextStyle(fontFamily: null),
          titleLarge: TextStyle(fontFamily: null),
          titleMedium: TextStyle(fontFamily: null),
          titleSmall: TextStyle(fontFamily: null),
          labelLarge: TextStyle(fontFamily: null),
          labelMedium: TextStyle(fontFamily: null),
          labelSmall: TextStyle(fontFamily: null),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LandingPage(), // 📣 Intro screen
        '/login': (context) => const LoginPage(), // 🔐 OTP login
        '/home': (context) => const HomePage(), // 🏡 After login
        '/tenant': (context) => const TenantDashboardV2(), // 👥 Tenant view
        '/mission': (context) => const MissionSection(), // 🌱 Vision & Mission
        '/tenant-info': (context) => const TenantInfo(), // 📘 Info page
        '/landlord-info': (context) => const LandlordInfo(), // 🏢 Info page
        '/technology': (context) => const TechnologyInfo(), // 💻 Tech
        '/learn': (context) => const LearnPage(),
        '/settings': (context) => const SettingsPage(), // 📚 Learn Hub
        '/faq': (context) => const FaqPage(),
        '/about-us': (context) => const AboutUsPage(),
        '/pricing': (context) => const PricingPage(),
        '/rent-reporting': (context) => const RentReportingPage(),
        '/lease-manager': (context) => const LeasePage(),
        '/payments': (context) => const PaymentsPage(),
        '/account': (context) => const AccountPage()
      },
    );
  }
}
