// // // // import 'package:flutter/material.dart';

// // // // class NavBar extends StatelessWidget {
// // // //   const NavBar({super.key});

// // // //   @override
// // // //   Widget build(BuildContext context) {
// // // //     return Container(
// // // //       padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
// // // //       color: const Color.fromARGB(255, 205, 254, 253), // soft blue background
// // // //       child: Row(
// // // //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
// // // //         children: [
// // // //           // App name
// // // //           const Text(
// // // //             "KirayaEase",
// // // //             style: TextStyle(
// // // //               fontFamily: 'Sans-serif',
// // // //               fontWeight: FontWeight.bold,
// // // //               fontSize: 20,
// // // //               color: Colors.black87,
// // // //             ),
// // // //           ),

// // // //           // Navigation links
// // // //           Row(
// // // //             children: [
// // // //               _navItem("Home", () => Navigator.pushNamed(context, '/')),
// // // //               _navItem("Mission", () {}),
// // // //               _navItem("Landlords", () {}),
// // // //               _navItem("Tenants", () {}),
// // // //               _navItem("Technology", () {}),
// // // //               _navItem("Learn", () {}),
// // // //               _navItem("About", () {}),
// // // //             ],
// // // //           ),
// // // //         ],
// // // //       ),
// // // //     );
// // // //   }

// // // //   static Widget _navItem(String title, VoidCallback onTap) {
// // // //     return TextButton(
// // // //       onPressed: onTap,
// // // //       child: Text(
// // // //         title,
// // // //         style: const TextStyle(
// // // //           fontFamily: 'Sans-serif', // 👈 Added Inter here too
// // // //           fontSize: 16,
// // // //           fontWeight: FontWeight.bold,
// // // //           color: Colors.black87,
// // // //         ),
// // // //       ),
// // // //     );
// // // //   }
// // // // }
// // // import 'package:flutter/material.dart';

// // // class NavBar extends StatelessWidget {
// // //   const NavBar({super.key});

// // //   @override
// // //   Widget build(BuildContext context) {
// // //     return Column(
// // //       children: [
// // //         const SizedBox(height: 24),

// // //         // Logo centered
// // //         Column(
// // //           children: [
// // //             Image.asset(
// // //               'assets/logo.png', // replace with your logo path
// // //               height: 50,
// // //             ),
// // //             const SizedBox(height: 8),
// // //             const Text(
// // //               "KirayaEase",
// // //               style: TextStyle(
// // //                 fontSize: 18,
// // //                 fontWeight: FontWeight.bold,
// // //               ),
// // //             ),
// // //           ],
// // //         ),

// // //         const SizedBox(height: 24),

// // //         // Rounded pill-shaped navigation bar
// // //         Container(
// // //           padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
// // //           margin: const EdgeInsets.symmetric(horizontal: 16),
// // //           decoration: BoxDecoration(
// // //             color: Colors.white.withOpacity(0.4),
// // //             borderRadius: BorderRadius.circular(40),
// // //             boxShadow: [
// // //               BoxShadow(
// // //                 color: Colors.black.withOpacity(0.1),
// // //                 blurRadius: 20,
// // //                 offset: const Offset(0, 10),
// // //               ),
// // //             ],
// // //           ),
// // //           child: Wrap(
// // //             alignment: WrapAlignment.center,
// // //             spacing: 20,
// // //             children: [
// // //               _navItem("Home", () => Navigator.pushNamed(context, '/')),
// // //               _navItem("Mission", () {}),
// // //               _navItem("Landlords", () {}),
// // //               _navItem("Tenants", () {}),
// // //               _navItem("Technology", () {}),
// // //               _navItem("Pricing", () {}),
// // //               _navItem("Learn", () {}),
// // //               _navItem("About", () {}),
// // //             ],
// // //           ),
// // //         ),
// // //         const SizedBox(height: 24),
// // //       ],
// // //     );
// // //   }

// // //   static Widget _navItem(String title, VoidCallback onTap) {
// // //     return TextButton(
// // //       onPressed: onTap,
// // //       child: Text(
// // //         title,
// // //         style: const TextStyle(
// // //           fontSize: 16,
// // //           fontWeight: FontWeight.bold,
// // //           color: Colors.black87,
// // //         ),
// // //       ),
// // //     );
// // //   }
// // // }

// // import 'dart:ui';
// // import 'package:flutter/material.dart';

// // class NavBar extends StatelessWidget {
// //   const NavBar({super.key});

// //   @override
// //   Widget build(BuildContext context) {
// //     return Padding(
// //       padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
// //       child: Row(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: [
// //           // Logo and app name
// //           Column(
// //             children: [
// //               Image.asset(
// //                 'assets/rent_mockup.png', // replace with your logo path
// //                 width: 40,
// //               ),
// //               const SizedBox(height: 4),
// //               const Text(
// //                 'KirayaEase',
// //                 style: TextStyle(
// //                   fontWeight: FontWeight.bold,
// //                   fontSize: 16,
// //                   color: Colors.black87,
// //                 ),
// //               ),
// //             ],
// //           ),
// //           const SizedBox(width: 40),

// //           // Frosted glass nav links
// //           Expanded(
// //             child: Center(
// //               child: ClipRRect(
// //                 borderRadius: BorderRadius.circular(40),
// //                 child: BackdropFilter(
// //                   filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
// //                   child: Container(
// //                     padding: const EdgeInsets.symmetric(
// //                       horizontal: 32,
// //                       vertical: 16,
// //                     ),
// //                     decoration: BoxDecoration(
// //                       color: Colors.white.withOpacity(0.2),
// //                       borderRadius: BorderRadius.circular(40),
// //                       boxShadow: [
// //                         BoxShadow(
// //                           color: Colors.black.withOpacity(0.05),
// //                           blurRadius: 20,
// //                           offset: const Offset(0, 10),
// //                         ),
// //                       ],
// //                     ),
// //                     child: Row(
// //                       mainAxisAlignment: MainAxisAlignment.spaceEvenly,
// //                       children: [
// //                         _navItem(context, "Home", '/'),
// //                         _navItem(context, "Mission", '/'),
// //                         _navItem(context, "Landlords", '/'),
// //                         _navItem(context, "Tenants", '/'),
// //                         _navItem(context, "Technology", '/'),
// //                         _navItem(context, "Pricing", '/'),
// //                         _navItem(context, "Learn", '/'),
// //                         _navItem(context, "About", '/'),
// //                       ],
// //                     ),
// //                   ),
// //                 ),
// //               ),
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   Widget _navItem(BuildContext context, String title, String route) {
// //     return TextButton(
// //       onPressed: () => Navigator.pushNamed(context, route),
// //       child: Text(
// //         title,
// //         style: const TextStyle(
// //           fontSize: 16,
// //           fontWeight: FontWeight.w600,
// //           color: Colors.black87,
// //         ),
// //       ),
// //     );
// //   }
// // }

// import 'dart:ui';
// import 'package:flutter/material.dart';

// class NavBar extends StatelessWidget {
//   const NavBar({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding:
//           const EdgeInsets.fromLTRB(40, 40, 40, 24), // Top padding for spacing
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Logo
//           Column(
//             children: [
//               Image.asset(
//                 'assets/rent_mockup.png', // Your logo
//                 width: 40,
//               ),
//               const SizedBox(height: 4),
//               const Text(
//                 'KirayaEase',
//                 style: TextStyle(
//                   fontWeight: FontWeight.bold,
//                   fontSize: 16,
//                   color: Colors.black87,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(width: 40),

//           // Frosted Nav Container
//           Expanded(
//             child: Center(
//               child: ClipRRect(
//                 borderRadius: BorderRadius.circular(40),
//                 child: BackdropFilter(
//                   filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 32,
//                       vertical: 16,
//                     ),
//                     decoration: BoxDecoration(
//                       color: Colors.white.withOpacity(0.15),
//                       borderRadius: BorderRadius.circular(40),
//                       boxShadow: [
//                         BoxShadow(
//                           color: Colors.black.withOpacity(0.05),
//                           blurRadius: 20,
//                           offset: const Offset(0, 10),
//                         ),
//                       ],
//                     ),
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                       children: [
//                         _navItem(context, "Home", '/'),
//                         _navItem(context, "Mission", '/'),
//                         _navItem(context, "Landlords", '/'),
//                         _navItem(context, "Tenants", '/'),
//                         _navItem(context, "Technology", '/'),
//                         _navItem(context, "Pricing", '/'),
//                         _navItem(context, "Learn", '/'),
//                         _navItem(context, "About", '/'),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _navItem(BuildContext context, String title, String route) {
//     return TextButton(
//       onPressed: () => Navigator.pushNamed(context, route),
//       child: Text(
//         title,
//         style: const TextStyle(
//           fontSize: 16,
//           fontWeight: FontWeight.w600,
//           color: Colors.black87,
//         ),
//       ),
//     );
//   }
// }

import 'dart:ui';
import 'package:flutter/material.dart';

class NavBar extends StatelessWidget {
  const NavBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo and app name
          Column(
            children: [
              Image.asset(
                'assets/logo.png',
                width: 64,
              ),
              const SizedBox(height: 4),
              const Text(
                'KirayaEase',
                style: TextStyle(
                  fontFamily: 'Sans-Serif',
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(width: 40),

          // 👇 Nav links constrained to a max width
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(40),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _navItem(context, "Home", '/'),
                          _navItem(context, "Mission", '/'),
                          _navItem(context, "Landlords", '/'),
                          _navItem(context, "Tenants", '/'),
                          _navItem(context, "Technology", '/'),
                          _navItem(context, "Pricing", '/'),
                          _navItem(context, "Learn", '/'),
                          _navItem(context, "About", '/'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(BuildContext context, String title, String route) {
    return TextButton(
      onPressed: () => Navigator.pushNamed(context, route),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }
}
