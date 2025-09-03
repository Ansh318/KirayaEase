import 'package:flutter/material.dart';
import '../widgets/base_scaffold.dart';
import '../widgets/footer.dart';
import '../widgets/onboarding_form.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const Color primary = Color(0xFF00C6A6);
  static const Color landlordBg = Color(0xFFE6FFFA);
  static const Color tenantBg = Color(0xFFE8F9FF);

  @override
  Widget build(BuildContext context) {
    final stepsLandlord = [
      _Bullet(Icons.show_chart, 'On-time rent, steady cash flow'),
      _Bullet(Icons.analytics, 'Smart pricing to retain tenants'),
      _Bullet(
          Icons.trending_up, 'Lower defaults, higher yield - no extra effort'),
    ];
    final stepsTenant = [
      _Bullet(Icons.calendar_today, 'Pay rent your way, on your schedule.'),
      _Bullet(Icons.currency_rupee, 'Turn every rent payment into a reward.'),
      _Bullet(Icons.show_chart, 'Smart budgeting that adapts to you.'),
    ];

    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 700;

    return BaseScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'For Renters & Landlords',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            const SizedBox(height: 32),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: isWide ? (screenWidth - 64) / 2 : double.infinity,
                  child: _buildCard(
                    title: 'Landlords',
                    subtitle:
                        'Keep units full and income flowing with smart rental management.',
                    bgColor: landlordBg,
                    borderColor: primary,
                    bullets: stepsLandlord,
                  ),
                ),
                SizedBox(
                  width: isWide ? (screenWidth - 64) / 2 : double.infinity,
                  child: _buildCard(
                    title: 'Tenants',
                    subtitle:
                        'Own your rent, shape your future - with payment plans that work for you.',
                    bgColor: tenantBg,
                    borderColor: primary,
                    bullets: stepsTenant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const OnboardingForm(),
            const SizedBox(height: 40),
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
          Text(title,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 16),
          ...bullets.map((b) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: b,
              )),
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
