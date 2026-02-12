import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;

  // Google auth is temporarily disabled. We still route based on DB user status.
  Future<void> login() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final email = (prefs.getString('user_email') ?? '').trim();

      // Without an authenticated email, treat as new user -> onboarding.
      if (email.isEmpty) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home');
        return;
      }

      final response = await http.post(
        Uri.parse(ApiConfig.userStatusEndpoint),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final exists = data['exists'] == true;
        final onboarded = data['onboarded'] == true;
        final role = (data['role'] ?? 'tenant').toString().toLowerCase();

        await prefs.setString(
            'user_role', role == 'landlord' ? 'landlord' : 'tenant');

        if (!mounted) return;
        if (exists && onboarded) {
          Navigator.pushReplacementNamed(context, '/tenant');
        } else {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🎨 Background gradient
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFA6F0EB), Color(0xFFC2F4FB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // 🔙 Back to Home Button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topLeft,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.black87,
                    backgroundColor: Colors.white.withOpacity(0.4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/');
                  },
                  icon: const Icon(Icons.arrow_back_ios_new, size: 16),
                  label: const Text("Back to Home"),
                ),
              ),
            ),
          ),

          // 🔐 Login Card
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                child: Container(
                  width: 500,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/logo.png',
                        height: 60,
                        width: 60,
                        cacheWidth: 180,
                        cacheHeight: 180,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Sign In",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 0, 0, 0),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // COMMENTED OUT: Email field - keeping for future use
                      // TextField(
                      //   controller: emailController,
                      //   style: const TextStyle(
                      //       color: Color.fromARGB(255, 0, 0, 0)),
                      //   decoration: InputDecoration(
                      //     hintText: 'Email Address',
                      //     hintStyle: const TextStyle(
                      //         color: Color.fromARGB(179, 0, 0, 0)),
                      //     prefixIcon:
                      //         const Icon(Icons.email, color: Colors.white54),
                      //     filled: true,
                      //     fillColor: Colors.white.withOpacity(0.15),
                      //     border: OutlineInputBorder(
                      //       borderRadius: BorderRadius.circular(12),
                      //       borderSide: BorderSide.none,
                      //     ),
                      //   ),
                      // ),
                      // const SizedBox(height: 16),
                      // COMMENTED OUT: OTP field - bypassed for now
                      // if (otpSent)
                      //   TextField(
                      //     controller: otpController,
                      //     style: const TextStyle(
                      //         color: Color.fromARGB(255, 0, 0, 0)),
                      //     decoration: InputDecoration(
                      //       hintText: 'Enter OTP',
                      //       hintStyle: const TextStyle(
                      //           color: Color.fromARGB(179, 0, 0, 0)),
                      //       prefixIcon: const Icon(Icons.lock_outline,
                      //           color: Colors.white54),
                      //       filled: true,
                      //       fillColor: Colors.white.withOpacity(0.15),
                      //       border: OutlineInputBorder(
                      //         borderRadius: BorderRadius.circular(12),
                      //         borderSide: BorderSide.none,
                      //       ),
                      //     ),
                      //     keyboardType: TextInputType.number,
                      //   ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (!_isLoading)
                                Image.asset(
                                  'assets/google.png',
                                  height: 20,
                                  width: 20,
                                ),
                              if (_isLoading)
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.black),
                                  ),
                                ),
                              const SizedBox(width: 12),
                              Text(
                                _isLoading
                                    ? "Checking account..."
                                    : "Login with Google",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // COMMENTED OUT: OTP send button - bypassed for now
                      // const SizedBox(height: 12),
                      // if (otpSent)
                      //   SizedBox(
                      //     width: double.infinity,
                      //     child: ElevatedButton(
                      //       onPressed: login,
                      //       style: ElevatedButton.styleFrom(
                      //         backgroundColor: Colors.white,
                      //         foregroundColor: Colors.black,
                      //         padding: const EdgeInsets.symmetric(vertical: 14),
                      //         shape: RoundedRectangleBorder(
                      //           borderRadius: BorderRadius.circular(12),
                      //         ),
                      //       ),
                      //       child: const Text("Login"),
                      //     ),
                      //   ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
