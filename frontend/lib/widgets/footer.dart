// import 'package:flutter/material.dart';

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
//           // Main footer row
//           LayoutBuilder(
//             builder: (context, constraints) {
//               return Wrap(
//                 alignment: WrapAlignment.spaceBetween,
//                 runSpacing: 24,
//                 spacing: 40,
//                 children: [
//                   _footerSection("KirayaEase LLP", []),
//                   _footerSection("Explore", const [
//                     Text("About us"),
//                     Text("Contact"),
//                     Text("Services"),
//                   ]),
//                   _footerSection("Follow us", const [
//                     Text("LinkedIn"),
//                     Text("Facebook"),
//                     Text("Instagram"),
//                   ]),
//                   _footerSection("Download Our App", const [
//                     Text("Coming soon to App Store"),
//                     Text("and Google Play"),
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
// }

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class Footer extends StatelessWidget {
  const Footer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 48),
      margin: const EdgeInsets.only(top: 60),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return Wrap(
                alignment: WrapAlignment.spaceBetween,
                runSpacing: 24,
                spacing: 40,
                children: [
                  _footerSection("KirayaEase LLP", []),
                  _footerSection("Explore", [
                    _linkText("About us", "https://kirayaease.com/about"),
                    _linkText("Contact", "https://kirayaease.com/contact"),
                    _linkText("Services", "https://kirayaease.com/services"),
                  ]),
                  _footerSection("Follow us", [
                    _linkText(
                        "LinkedIn", "https://linkedin.com/company/kirayaease"),
                    _linkText("Facebook", "https://facebook.com/kirayaease"),
                    _linkText("Instagram", "https://instagram.com/kirayaease"),
                  ]),
                  _footerSection("Download Our App", [
                    const Text("Coming soon to App Store"),
                    const Text("and Google Play"),
                  ]),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          const Divider(height: 1, thickness: 0.7, color: Colors.black26),
          const SizedBox(height: 10),
          const Text(
            "© 2025 KirayaEase LLP. All rights reserved.",
            style: TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ],
      ),
    );
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
          color: Color.fromARGB(255, 0, 0, 0),
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  void _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }
}
