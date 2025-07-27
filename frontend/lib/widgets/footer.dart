// import 'package:flutter/material.dart';
// import 'package:url_launcher/url_launcher.dart';

// class Footer extends StatelessWidget {
//   const Footer({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 48),
//       margin: const EdgeInsets.only(top: 60),
//       width: double.infinity,
//       decoration: BoxDecoration(
//         color: Colors.white.withOpacity(0.15),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           LayoutBuilder(
//             builder: (context, constraints) {
//               return Wrap(
//                 alignment: WrapAlignment.spaceBetween,
//                 runSpacing: 24,
//                 spacing: 40,
//                 children: [
//                   _footerSection("KirayaEase LLP", []),
//                   _footerSection("Explore", [
//                     _linkText("About us", "https://kirayaease.com/about"),
//                     _linkText("Contact", "https://kirayaease.com/contact"),
//                     _linkText("Services", "https://kirayaease.com/services"),
//                   ]),
//                   _footerSection("Follow us", [
//                     _linkText(
//                         "LinkedIn", "https://linkedin.com/company/kirayaease"),
//                     _linkText("Facebook", "https://facebook.com/kirayaease"),
//                     _linkText("Instagram", "https://instagram.com/kirayaease"),
//                   ]),
//                   _footerSection("Download Our App", [
//                     const Text("Coming soon to App Store"),
//                     const Text("and Google Play"),
//                   ]),
//                 ],
//               );
//             },
//           ),
//           const SizedBox(height: 24),
//           const Divider(height: 1, thickness: 0.7, color: Colors.black26),
//           const SizedBox(height: 10),
//           const Text(
//             "© 2025 KirayaEase LLP. All rights reserved.",
//             style: TextStyle(fontSize: 12, color: Colors.black87),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _footerSection(String title, List<Widget> children) {
//     return ConstrainedBox(
//       constraints: const BoxConstraints(minWidth: 150),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             title,
//             style: const TextStyle(
//               fontWeight: FontWeight.bold,
//               fontSize: 16,
//               color: Colors.black87,
//             ),
//           ),
//           const SizedBox(height: 8),
//           ...children.map(
//             (child) => Padding(
//               padding: const EdgeInsets.only(bottom: 4),
//               child: child,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _linkText(String text, String url) {
//     return InkWell(
//       onTap: () => _launchURL(url),
//       child: Text(
//         text,
//         style: const TextStyle(
//           color: Color.fromARGB(255, 0, 0, 0),
//           decoration: TextDecoration.underline,
//         ),
//       ),
//     );
//   }

//   void _launchURL(String url) async {
//     final uri = Uri.parse(url);
//     if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
//       throw 'Could not launch $url';
//     }
//   }
// }

// import 'package:flutter/material.dart';
// import 'package:url_launcher/url_launcher.dart';

// class Footer extends StatelessWidget {
//   const Footer({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
//       margin: const EdgeInsets.only(top: 60),
//       decoration: BoxDecoration(
//         color: Colors.white.withOpacity(0.15),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           LayoutBuilder(
//             builder: (context, constraints) {
//               final isMobile = constraints.maxWidth < 600;

//               return isMobile
//                   ? Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: _footerSections(isMobile),
//                     )
//                   : Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: _footerSections(isMobile),
//                     );
//             },
//           ),
//           const SizedBox(height: 24),
//           const Divider(height: 1, thickness: 0.7, color: Colors.black26),
//           const SizedBox(height: 10),
//           const Center(
//             child: Text(
//               "© 2025 KirayaEase LLP. All rights reserved.",
//               style: TextStyle(fontSize: 12, color: Colors.black87),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   List<Widget> _footerSections(bool isMobile) {
//     return [
//       _footerSection("KirayaEase LLP", [], isMobile),
//       _footerSection(
//           "Explore",
//           [
//             _linkText("About us", "https://kirayaease.com/about"),
//             _linkText("Contact", "https://kirayaease.com/contact"),
//             _linkText("Services", "https://kirayaease.com/services"),
//           ],
//           isMobile),
//       _footerSection(
//           "Follow us",
//           [
//             _linkText("LinkedIn", "https://linkedin.com/company/kirayaease"),
//             _linkText("Facebook", "https://facebook.com/kirayaease"),
//             _linkText("Instagram", "https://instagram.com/kirayaease"),
//           ],
//           isMobile),
//       _footerSection(
//           "Download Our App",
//           const [
//             Text("Coming soon to App Store"),
//             Text("and Google Play"),
//           ],
//           isMobile),
//     ];
//   }

//   Widget _footerSection(String title, List<Widget> children, bool isMobile) {
//     return Padding(
//       padding: EdgeInsets.only(bottom: isMobile ? 24 : 0),
//       child: ConstrainedBox(
//         constraints: const BoxConstraints(minWidth: 150),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               title,
//               style: const TextStyle(
//                 fontWeight: FontWeight.bold,
//                 fontSize: 16,
//                 color: Colors.black87,
//               ),
//             ),
//             const SizedBox(height: 8),
//             ...children.map(
//               (child) => Padding(
//                 padding: const EdgeInsets.only(bottom: 4),
//                 child: child,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _linkText(String text, String url) {
//     return InkWell(
//       onTap: () => _launchURL(url),
//       child: Text(
//         text,
//         style: const TextStyle(
//           color: Colors.black87,
//           decoration: TextDecoration.underline,
//         ),
//       ),
//     );
//   }

//   Future<void> _launchURL(String url) async {
//     final uri = Uri.parse(url);
//     if (!await launchUrl(uri)) {
//       throw Exception("Could not launch $url");
//     }
//   }
// }

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class Footer extends StatelessWidget {
  const Footer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      margin: const EdgeInsets.only(top: 60),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 700;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ROW 1: KirayaEase LLP
              _footerSection("KirayaEase LLP", []),

              const SizedBox(height: 32),

              // ROW 2: Explore + Follow us side-by-side or stacked
              isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _footerSection("Explore", _exploreLinks()),
                        const SizedBox(height: 16),
                        _footerSection("Follow us", _socialLinks()),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _footerSection("Explore", _exploreLinks()),
                        const SizedBox(width: 80),
                        _footerSection("Follow us", _socialLinks()),
                      ],
                    ),

              const SizedBox(height: 32),

              // ROW 3: Download App
              _footerSection(
                "Download Our App",
                const [
                  Text("Coming soon to App Store"),
                  Text("and Google Play"),
                ],
              ),

              const SizedBox(height: 24),
              const Divider(height: 1, thickness: 0.7, color: Colors.black26),
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  "© 2025 KirayaEase LLP. All rights reserved.",
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _exploreLinks() {
    return [
      _linkText("About us", "https://kirayaease.com/about"),
      _linkText("Contact", "https://kirayaease.com/contact"),
      _linkText("Services", "https://kirayaease.com/services"),
    ];
  }

  List<Widget> _socialLinks() {
    return [
      _linkText("LinkedIn", "https://linkedin.com/company/kirayaease"),
      _linkText("Instagram", "https://instagram.com/kirayaease"),
    ];
  }

  Widget _footerSection(String title, List<Widget> children) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 150),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          ...children.map(
            (child) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _linkText(String text, String url) {
    return InkWell(
      onTap: () => _launchURL(url),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.black87,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw Exception("Could not launch $url");
    }
  }
}
