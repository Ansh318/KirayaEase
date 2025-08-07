import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/ai_assistant.dart';

class LandlordDashboard extends StatefulWidget {
  const LandlordDashboard({super.key});

  @override
  State<LandlordDashboard> createState() => _LandlordDashboardState();
}

class _LandlordDashboardState extends State<LandlordDashboard> {
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
    String greeting;
    if (hour < 12) {
      greeting = "Good morning";
    } else if (hour < 17) {
      greeting = "Good afternoon";
    } else {
      greeting = "Good evening";
    }
    return "$greeting, ${userProfile?['first_name'] ?? ''}!";
  }

  void _showGlassyProfilePopup() {
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
                    Row(
                      children: const [
                        Icon(Icons.person, color: Colors.black87),
                        SizedBox(width: 8),
                        Text(
                          'Your Profile',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildProfileRow("Name",
                        "${userProfile!['first_name']} ${userProfile!['last_name']}"),
                    _buildProfileRow("Role", userProfile!["role"]),
                    _buildProfileRow("Aadhaar",
                        userProfile!["aadhar_card"]?.toString() ?? "—"),
                    _buildProfileRow(
                        "PAN", userProfile!["pan_card"]?.toString() ?? "—"),
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
      child: Text(
        "$label: ${value ?? '—'}",
        style: const TextStyle(color: Colors.black87),
      ),
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

  Widget buildAlert(String message, String actionLabel) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
              child:
                  Text(message, style: const TextStyle(color: Colors.black87))),
          const SizedBox(width: 12),
          TextButton(onPressed: () {}, child: Text(actionLabel)),
        ],
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
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20.0),
                            child: Text(
                              getGreetingMessage(),
                              style: const TextStyle(
                                fontSize: 26,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              buildMetricCard("Total Properties", "4",
                                  Icons.home_work_outlined),
                              buildMetricCard("Rent Collected", "₹75,000",
                                  Icons.attach_money),
                              buildMetricCard(
                                  "Upcoming Dues", "2", Icons.hourglass_bottom),
                            ],
                          ),
                          const SizedBox(height: 16),
                          buildAlert(
                              "Tenant Ravi's rent due in 3 days", "Remind"),
                          buildAlert(
                              "Lease agreement pending for Flat 2B", "Review"),
                          buildAlert(
                              "Incomplete KYC for Akash (Flat 3C)", "Resolve"),
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
                _showGlassyProfilePopup();
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
