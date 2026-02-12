// import 'package:flutter/material.dart';
// import '../widgets/footer.dart';
// // import 'footer.dart'; // ← When ready, uncomment and ensure a <Footer/> widget exists

// /// KirayaEase • About Us (App View)
// /// Sleek, photo-free rows with room for future PNG avatars and experience highlights.
// class AboutUsPage extends StatelessWidget {
//   const AboutUsPage({super.key});

//   // Brand palette derived from your screenshots
//   static const Color mint = Color(0xFFE9FBF6); // page bg
//   static const Color ink = Color(0xFF111827); // primary text
//   static const Color sub = Color(0xFF6B7280); // secondary text

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: mint,
//       appBar: AppBar(
//         backgroundColor: mint,
//         elevation: 0,
//         scrolledUnderElevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back_ios_new_rounded,
//               color: Colors.black87),
//           onPressed: () => Navigator.maybePop(context),
//         ),
//         centerTitle: true,
//         title: const Text('About Us',
//             style:
//                 TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
//       ),
//       body: SafeArea(
//         bottom: false,
//         child: ListView(
//           padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
//           children: [
//             // --- Hero / Mission --
//             // --- Team --

//             TeamRow(
//               name: 'Ansh Agarwal',
//               role: 'Founder',
//               highlights: const [
//                 'Ex SWE UBS / Credit Suisse - Credit Technology',
//                 'Ex AI Engineer — Howso Inc ',
//                 'BSc Data Science & Comp Sci - UW Madison',
//               ],
//             ),
//             const SizedBox(height: 8),
//             TeamRow(
//               name: 'Niranjandas Jayadev',
//               role: 'Co‑Founder',
//               highlights: const [
//                 'Product Manager - Outlook Group',
//                 'Ex Product Manager - Enpointe.io',
//                 'Business Administration - University of London'
//               ],
//             ),
//             const SizedBox(height: 8),
//             TeamRow(
//               name: 'Manu Siddharth',
//               role: 'Founding Engineer',
//               highlights: const [
//                 'Engineering Manager - Kotak Trade Finance',
//                 'BTech Electrical Engineering - University of Mumbai',
//               ],
//             ),

//             const SizedBox(height: 28),

//             // --- Footer placeholder ---
//             Footer()
//           ],
//         ),
//       ),
//     );
//   }
// }

// /// Row layout: Name + Role + optional experience bullets, with a right-side PNG slot you can fill later.
// class TeamRow extends StatelessWidget {
//   const TeamRow(
//       {super.key,
//       required this.name,
//       required this.role,
//       this.highlights = const []});
//   final String name;
//   final String role;
//   final List<String> highlights;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: const [
//           BoxShadow(
//               blurRadius: 16,
//               spreadRadius: 0,
//               offset: Offset(0, 8),
//               color: Color(0x14000000)),
//         ],
//       ),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Text block
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(name,
//                     style: const TextStyle(
//                         fontSize: 18,
//                         fontWeight: FontWeight.w700,
//                         color: AboutUsPage.ink)),
//                 const SizedBox(height: 2),
//                 Text(role,
//                     style:
//                         const TextStyle(fontSize: 14, color: AboutUsPage.sub)),
//                 if (highlights.isNotEmpty) ...[
//                   const SizedBox(height: 10),
//                   for (final h in highlights)
//                     Padding(
//                       padding: const EdgeInsets.only(bottom: 6),
//                       child: Row(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           const Text('•  ',
//                               style: TextStyle(color: AboutUsPage.sub)),
//                           Expanded(
//                             child: Text(
//                               h,
//                               style: const TextStyle(
//                                   color: AboutUsPage.ink, height: 1.3),
//                             ),
//                           )
//                         ],
//                       ),
//                     ),
//                 ],
//               ],
//             ),
//           ),

//           const SizedBox(width: 12),

//           // --- PNG slot (right aligned). Replace the Container with your Image.asset/NetworkImage when ready.
//           ClipRRect(
//             borderRadius: BorderRadius.circular(12),
//             child: SizedBox(
//               width: 56,
//               height: 56,
//               child: Container(
//                 color: const Color(0xFFF4F6F9),
//                 alignment: Alignment.center,
//                 child: const Text('',
//                     style: TextStyle(fontSize: 12, color: AboutUsPage.sub)),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _Heading extends StatelessWidget {
//   const _Heading({required this.title, required this.subtitle});
//   final String title;
//   final String subtitle;

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(title,
//             style: const TextStyle(
//                 fontSize: 28,
//                 fontWeight: FontWeight.w800,
//                 color: AboutUsPage.ink,
//                 letterSpacing: -0.5)),
//         const SizedBox(height: 6),
//         Text(
//           subtitle,
//           style: const TextStyle(color: AboutUsPage.sub, height: 1.35),
//         ),
//       ],
//     );
//   }
// }

// class _SectionTitle extends StatelessWidget {
//   const _SectionTitle(this.text);
//   final String text;
//   @override
//   Widget build(BuildContext context) {
//     return Text(text,
//         style: const TextStyle(
//             fontSize: 16, fontWeight: FontWeight.w700, color: AboutUsPage.ink));
//   }
// }

// class _Bullets extends StatelessWidget {
//   const _Bullets({required this.items});
//   final List<String> items;
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         for (final it in items)
//           Padding(
//             padding: const EdgeInsets.only(bottom: 8),
//             child: Row(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const Text('•  ', style: TextStyle(color: AboutUsPage.sub)),
//                 Expanded(
//                     child: Text(it,
//                         style: const TextStyle(
//                             color: AboutUsPage.ink, height: 1.3))),
//               ],
//             ),
//           ),
//       ],
//     );
//   }
// }

// /// Footer slot — keeps layout stable without requiring footer.dart now.
// class _FooterSlot extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     // When ready, import 'footer.dart' and replace the SizedBox with: `return const Footer();`
//     return const SizedBox(height: 64); // space reserved for footer
//   }
// }

import 'package:flutter/material.dart';
import '../widgets/footer.dart';
// import 'footer.dart'; // ← When ready, uncomment and ensure a <Footer/> widget exists

/// KirayaEase • About Us (App View)
/// Sleek, photo-free rows with room for future experience highlights.
class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  // Brand palette derived from your screenshots
  static const Color mint = Color(0xFFE9FBF6); // page bg
  static const Color ink = Color(0xFF111827); // primary text
  static const Color sub = Color(0xFF6B7280); // secondary text

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mint,
      appBar: AppBar(
        backgroundColor: mint,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.black87),
          onPressed: () => Navigator.maybePop(context),
        ),
        centerTitle: true,
        title: const Text('About Us',
            style:
                TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // --- Team Rows ---
            TeamRow(
              name: 'Ansh Agarwal',
              role: 'Founder',
              highlights: const [
                'Ex SWE UBS / Credit Suisse - Credit Technology',
                'Ex AI Engineer — Howso Inc ',
                'BSc Data Science & Comp Sci - UW Madison',
              ],
            ),
            const SizedBox(height: 8),
            TeamRow(
              name: 'Niranjandas Jayadev',
              role: 'Co-Founder',
              highlights: const [
                'Product Manager - Outlook Group',
                'Ex Product Manager - Enpointe.io',
                'Business Administration - University of London'
              ],
            ),
            const SizedBox(height: 28),

            // --- Footer placeholder ---
            Footer()
          ],
        ),
      ),
    );
  }
}

/// Row layout: Name + Role + optional experience bullets.
class TeamRow extends StatelessWidget {
  const TeamRow(
      {super.key,
      required this.name,
      required this.role,
      this.highlights = const []});
  final String name;
  final String role;
  final List<String> highlights;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              blurRadius: 16,
              spreadRadius: 0,
              offset: Offset(0, 8),
              color: Color(0x14000000)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AboutUsPage.ink)),
          const SizedBox(height: 2),
          Text(role,
              style: const TextStyle(fontSize: 14, color: AboutUsPage.sub)),
          if (highlights.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final h in highlights)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  ', style: TextStyle(color: AboutUsPage.sub)),
                    Expanded(
                      child: Text(
                        h,
                        style: const TextStyle(
                            color: AboutUsPage.ink, height: 1.3),
                      ),
                    )
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AboutUsPage.ink,
                letterSpacing: -0.5)),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(color: AboutUsPage.sub, height: 1.35),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w700, color: AboutUsPage.ink));
  }
}

class _Bullets extends StatelessWidget {
  const _Bullets({required this.items});
  final List<String> items;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final it in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  ', style: TextStyle(color: AboutUsPage.sub)),
                Expanded(
                    child: Text(it,
                        style: const TextStyle(
                            color: AboutUsPage.ink, height: 1.3))),
              ],
            ),
          ),
      ],
    );
  }
}

/// Footer slot — keeps layout stable without requiring footer.dart now.
class _FooterSlot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // When ready, import 'footer.dart' and replace the SizedBox with: `return const Footer();`
    return const SizedBox(height: 64); // space reserved for footer
  }
}
