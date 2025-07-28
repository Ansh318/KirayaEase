// import 'dart:convert';
// import 'dart:ui';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
// import '../widgets/ai_assistant.dart';

// class LandlordDashboard extends StatefulWidget {
//   const LandlordDashboard({super.key});

//   @override
//   State<LandlordDashboard> createState() => _LandlordDashboardState();
// }

// class _LandlordDashboardState extends State<LandlordDashboard> {
//   Map<String, dynamic>? userProfile;
//   bool isLoading = true;
//   String? error;

//   @override
//   void initState() {
//     super.initState();
//     fetchProfile();
//   }

//   Future<void> fetchProfile() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final token = prefs.getString('session_token');

//       final response = await http.get(
//         Uri.parse('http://127.0.0.1:8000/user-profile'),
//         headers: {
//           'Authorization': 'Bearer $token',
//         },
//       );

//       if (response.statusCode == 200) {
//         setState(() {
//           userProfile = jsonDecode(response.body);
//           isLoading = false;
//         });
//       } else {
//         setState(() {
//           error = 'Failed to fetch profile';
//           isLoading = false;
//         });
//       }
//     } catch (e) {
//       setState(() {
//         error = 'Error: $e';
//         isLoading = false;
//       });
//     }
//   }

//   String getGreetingMessage() {
//     final hour = DateTime.now().hour;
//     String greeting;

//     if (hour < 12) {
//       greeting = "Good morning";
//     } else if (hour < 17) {
//       greeting = "Good afternoon";
//     } else {
//       greeting = "Good evening";
//     }

//     return "$greeting, ${userProfile!['first_name']}!";
//   }

//   void _showGlassyProfilePopup() {
//     if (userProfile == null) return;

//     showDialog(
//       context: context,
//       barrierColor: Colors.black.withOpacity(0.2),
//       builder: (BuildContext context) {
//         return Dialog(
//           backgroundColor: Colors.transparent,
//           insetPadding: const EdgeInsets.all(20),
//           child: ClipRRect(
//             borderRadius: BorderRadius.circular(24),
//             child: BackdropFilter(
//               filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
//               child: Container(
//                 padding: const EdgeInsets.all(20),
//                 decoration: BoxDecoration(
//                   color: Colors.white.withOpacity(0.25),
//                   borderRadius: BorderRadius.circular(24),
//                   border: Border.all(color: Colors.white.withOpacity(0.4)),
//                 ),
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       children: const [
//                         Icon(Icons.person, color: Colors.black87),
//                         SizedBox(width: 8),
//                         Text(
//                           'Your Profile',
//                           style: TextStyle(
//                             fontSize: 18,
//                             fontWeight: FontWeight.w600,
//                             color: Colors.black87,
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 16),
//                     _buildProfileRow("Name",
//                         "${userProfile!["first_name"]} ${userProfile!["last_name"]}"),
//                     _buildProfileRow("Role", userProfile!["role"]),
//                     _buildProfileRow("Aadhaar",
//                         userProfile!["aadhar_card"]?.toString() ?? "—"),
//                     _buildProfileRow(
//                         "PAN", userProfile!["pan_card"]?.toString() ?? "—"),
//                     _buildProfileRow("DOB", userProfile!["dob"]),
//                     const SizedBox(height: 20),
//                     Align(
//                       alignment: Alignment.centerRight,
//                       child: TextButton(
//                         onPressed: () => Navigator.of(context).pop(),
//                         child: const Text(
//                           "Close",
//                           style: TextStyle(color: Colors.black87),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }

//   static Widget _buildProfileRow(String label, String? value) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4),
//       child: Text(
//         "$label: ${value ?? '—'}",
//         style: const TextStyle(color: Colors.black87),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFCBF8F3),
//       appBar: AppBar(
//         backgroundColor: const Color(0xFF00C6A6),
//         centerTitle: true,
//         title: Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             IconButton(
//               icon: const Icon(Icons.home_work_outlined,
//                   size: 30, color: Colors.black),
//               onPressed: () {
//                 // TODO: Navigate to Properties screen
//               },
//               tooltip: 'Properties',
//             ),
//             const SizedBox(width: 16),
//             IconButton(
//               icon: const Icon(Icons.payments, size: 30, color: Colors.black),
//               onPressed: () {
//                 // TODO: Navigate to Payments screen
//               },
//               tooltip: 'Payments',
//             ),
//             const SizedBox(width: 16),
//             IconButton(
//               icon: const Icon(Icons.account_circle,
//                   size: 30, color: Colors.black),
//               onPressed: isLoading || userProfile == null
//                   ? null
//                   : _showGlassyProfilePopup,
//               tooltip: 'View Profile',
//             ),
//             IconButton(
//               icon: const Icon(Icons.description_outlined,
//                   size: 30, color: Colors.black),
//               onPressed: () {
//                 // TODO: Navigate to Documents
//               },
//               tooltip: 'Documents',
//             ),
//             IconButton(
//               icon: const Icon(Icons.logout, size: 30, color: Colors.black),
//               onPressed: () {
//                 // TODO: Handle Sign Out
//               },
//               tooltip: 'Sign Out',
//             ),
//           ],
//         ),
//         automaticallyImplyLeading: false,
//       ),
//       body: isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : error != null
//               ? Center(child: Text(error!))
//               : Stack(
//                   children: [
//                     Padding(
//                       padding: const EdgeInsets.only(left: 20.0, top: 24.0),
//                       child: Align(
//                         alignment: Alignment.topLeft,
//                         child: Text(
//                           getGreetingMessage(),
//                           style: const TextStyle(
//                             fontSize: 30,
//                             fontFamily: 'Inter',
//                             color: Colors.black87,
//                           ),
//                         ),
//                       ),
//                     ),
//                     Positioned(
//                       bottom: 20,
//                       right: 20,
//                       child: AIAssistantButton(
//                         onTap: () {
//                           // TODO: Handle assistant logic
//                         },
//                       ),
//                     ),
//                   ],
//                 ),
//     );
//   }
// }

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
  Offset _assistantOffset = const Offset(300, 500);

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
        headers: {
          'Authorization': 'Bearer $token',
        },
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

    return "$greeting, ${userProfile!['first_name']}!";
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
                        child: const Text(
                          "Close",
                          style: TextStyle(color: Colors.black87),
                        ),
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
        "$label: \${value ?? '—'}",
        style: const TextStyle(color: Colors.black87),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFCBF8F3),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00C6A6),
        centerTitle: true,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.home_work_outlined,
                  size: 30, color: Colors.black),
              onPressed: () {},
              tooltip: 'Properties',
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.payments, size: 30, color: Colors.black),
              onPressed: () {},
              tooltip: 'Payments',
            ),
            IconButton(
              icon: const Icon(Icons.account_circle,
                  size: 30, color: Colors.black),
              onPressed: isLoading || userProfile == null
                  ? null
                  : _showGlassyProfilePopup,
              tooltip: 'View Profile',
            ),
            IconButton(
              icon: const Icon(Icons.description_outlined,
                  size: 30, color: Colors.black),
              onPressed: () {},
              tooltip: 'Documents',
            ),
            IconButton(
              icon: const Icon(Icons.logout, size: 30, color: Colors.black),
              onPressed: () {},
              tooltip: 'Sign Out',
            ),
          ],
        ),
        automaticallyImplyLeading: false,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 20.0, top: 24.0),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          getGreetingMessage(),
                          style: const TextStyle(
                            fontSize: 30,
                            fontFamily: 'Inter',
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: _assistantOffset.dx,
                      top: _assistantOffset.dy,
                      child: GestureDetector(
                        onPanUpdate: (details) {
                          setState(() {
                            final Size screenSize = MediaQuery.of(context).size;
                            final double buttonSize = 60;
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
                        child: AIAssistantButton(
                          onTap: () {},
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
