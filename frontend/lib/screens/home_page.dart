import 'package:flutter/material.dart';
import '../widgets/base_scaffold.dart';
import '../widgets/footer.dart';
import '../widgets/onboarding_form.dart'; // import the extracted form widget
import 'package:http/http.dart' as http;

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const Color primary = Color(0xFF00C6A6);
  static const Color landlordBg = Color(0xFFE6FFFA);
  static const Color tenantBg = Color(0xFFE8F9FF);

  @override
  Widget build(BuildContext context) {
    // Bullets for each card
    final stepsLandlord = [
      _Bullet(Icons.show_chart, 'Boost NOI and increase rental yield'),
      _Bullet(Icons.analytics, 'ML‑powered insights and analytics'),
      _Bullet(
          Icons.trending_up, 'Minimize delinquencies & ensure sustainability'),
    ];
    final stepsTenant = [
      _Bullet(Icons.calendar_today, 'Convenient payment scheduling'),
      _Bullet(Icons.currency_rupee, 'Build credit and earn rewards'),
      _Bullet(Icons.show_chart, 'ML‑powered budgeting insights'),
    ];

    return BaseScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // === Heading ===
            const Text(
              'Welcome to KirayaEase',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose Your Path',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            const Text(
              "Whether you're a property owner looking to maximize returns "
              "or a tenant seeking financial flexibility, KirayaEase is for you.",
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 32),

            // === Two cards side‑by‑side on wide, stacked on narrow ===
            LayoutBuilder(builder: (ctx, constraints) {
              final isWide = constraints.maxWidth > 700;
              return Flex(
                direction: isWide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildCard(
                      title: 'For Landlords',
                      subtitle:
                          'Maximize your rental income and minimize vacancies '
                          'with our intelligent property management platform.',
                      bgColor: landlordBg,
                      borderColor: primary,
                      bullets: stepsLandlord,
                    ),
                  ),
                  SizedBox(width: isWide ? 24 : 0, height: isWide ? 0 : 24),
                  Expanded(
                    child: _buildCard(
                      title: 'For Tenants',
                      subtitle:
                          'Take control of your rental payments and build your '
                          'financial future with flexible payment options.',
                      bgColor: tenantBg,
                      borderColor: Color.fromARGB(255, 0, 198, 166),
                      bullets: stepsTenant,
                    ),
                  ),
                ],
              );
            }),

            const SizedBox(height: 32),
            // === Onboarding form ===
            const OnboardingForm(),

            const SizedBox(height: 40),
            // === Footer ===
            const Footer(),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required String subtitle,
    required Color bgColor,
    required Color borderColor,
    required List<Widget> bullets,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(title,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          // Subtitle
          Text(subtitle, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 16),
          // Bullets
          ...bullets.map((b) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: b,
              )),
          const SizedBox(height: 24),
          // Begin KYC button
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: borderColor, width: 2),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              // TODO: navigate to KYC flow
            },
            child: Text('Begin KYC',
                style: TextStyle(
                    color: borderColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  static Widget _Bullet(IconData icon, String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
        ],
      );
}
