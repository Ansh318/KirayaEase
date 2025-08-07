import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/ai_assistant.dart';

class TenantDashboard extends StatefulWidget {
  const TenantDashboard({super.key});

  @override
  State<TenantDashboard> createState() => _TenantDashboardState();
}

class _TenantDashboardState extends State<TenantDashboard> {
  Map<String, dynamic>? userProfile;
  bool isLoading = true;
  String? error;
  Offset _assistantOffset = const Offset(20, 600);

  @override
  void initState() {
    super.initState();
    fetchProfile();
  }

  Future<void> fetchProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('session_token');

      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/user-profile'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          userProfile = jsonDecode(response.body);
          isLoading = false;
        });
      } else {
        setState(() {
          error = 'Failed to fetch profile';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error: $e';
        isLoading = false;
      });
    }
  }

  String getGreetingMessage() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good morning, ${userProfile?['first_name'] ?? ''}!";
    if (hour < 17)
      return "Good afternoon, ${userProfile?['first_name'] ?? ''}!";
    return "Good evening, ${userProfile?['first_name'] ?? ''}!";
  }

  void _showProfilePopup() {
    if (userProfile == null) return;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.2),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.4)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.person, color: Colors.black87),
                        SizedBox(width: 8),
                        Text('Your Profile',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildProfileRow(
                      "Name",
                      "${userProfile!['first_name']} ${userProfile!['last_name']}",
                    ),
                    _buildProfileRow("Role", userProfile!['role']),
                    _buildProfileRow(
                        "Aadhaar", userProfile!["aadhar_card"] ?? "—"),
                    _buildProfileRow("PAN", userProfile!["pan_card"] ?? "—"),
                    _buildProfileRow("DOB", userProfile!["dob"]),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text("Close",
                            style: TextStyle(color: Colors.black87)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _buildProfileRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text("$label: ${value ?? '—'}",
          style: const TextStyle(color: Colors.black87)),
    );
  }

  Widget buildMetricCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30, color: Colors.black87),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(value,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFCBF8F3),
      appBar: null,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : Stack(
                  children: [
                    Positioned.fill(
                      child: ListView(
                        padding: const EdgeInsets.only(top: 80, bottom: 100),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              getGreetingMessage(),
                              style: const TextStyle(
                                  fontSize: 26,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              buildMetricCard("Active Lease", "1",
                                  Icons.assignment_turned_in_outlined),
                              buildMetricCard("Next Payment", "₹12,500",
                                  Icons.payments_outlined),
                              buildMetricCard("Split Status", "Enabled",
                                  Icons.swap_calls_outlined),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 40,
                      left: 20,
                      child: Image.asset(
                        'assets/logo.png',
                        height: 48,
                        width: 48,
                      ),
                    ),
                    Positioned(
                      left: _assistantOffset.dx,
                      top: _assistantOffset.dy,
                      child: GestureDetector(
                        onPanUpdate: (details) {
                          setState(() {
                            final Size screenSize = MediaQuery.of(context).size;
                            const double buttonSize = 60;
                            double newX =
                                _assistantOffset.dx + details.delta.dx;
                            double newY =
                                _assistantOffset.dy + details.delta.dy;
                            newX =
                                newX.clamp(0.0, screenSize.width - buttonSize);
                            newY = newY.clamp(
                                0.0,
                                screenSize.height -
                                    buttonSize -
                                    kToolbarHeight);
                            _assistantOffset = Offset(newX, newY);
                          });
                        },
                        child: const AIAssistantChatWidget(),
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey[600],
        backgroundColor: const Color(0xFF00C6A6),
        type: BottomNavigationBarType.fixed,
        onTap: (index) async {
          switch (index) {
            case 0:
              break;
            case 1:
              break;
            case 2:
              if (!isLoading && userProfile != null) {
                _showProfilePopup();
              }
              break;
            case 3:
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('session_token');
              if (!mounted) return;
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/', (route) => false);
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_work_outlined), label: 'Properties'),
          BottomNavigationBarItem(
              icon: Icon(Icons.payments), label: 'Payments'),
          BottomNavigationBarItem(
              icon: Icon(Icons.account_circle), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.logout), label: 'Sign Out'),
        ],
      ),
    );
  }
}
