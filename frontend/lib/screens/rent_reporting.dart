// lib/rent_reporting_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RentReportingPage extends StatefulWidget {
  const RentReportingPage({Key? key}) : super(key: key);

  @override
  State<RentReportingPage> createState() => _RentReportingPageState();
}

class _RentReportingPageState extends State<RentReportingPage> {
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    _loadPref();
  }

  Future<void> _loadPref() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _enabled = prefs.getBool('rent_reporting_enabled') ?? true;
    });
  }

  Future<void> _savePref(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rent_reporting_enabled', v);
  }

  @override
  Widget build(BuildContext context) {
    const cardShadow = BoxShadow(
      blurRadius: 20,
      offset: Offset(0, 10),
      color: Color(0x14000000),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            // Back button
            Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F3F6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        color: Colors.black87),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Title
            const Text(
              'Rent reporting',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 10),

            // Subtitle
            const Text(
              "When you pay rent with KirayaEase, we’ll report your on-time payments to the following credit bureau:",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            // TransUnion logo (falls back to text if asset missing)
            Center(
              child: Image.asset(
                'assets/transunion.png',
                height: 28,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Text(
                  'CIBIL TransUnion',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1AA5E6),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            // Bullets card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [cardShadow],
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                children: const [
                  SizedBox(height: 8),
                  _TickRow(text: 'Establish on-time payment history'),
                  SizedBox(height: 8),
                  _TickRow(text: 'Build your credit profile'),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Learn more
            Center(
              child: GestureDetector(
                onTap: () {
                  // TODO: open your help center URL
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Open “Learn more” link…')));
                },
                child: const Text(
                  'Learn more',
                  style: TextStyle(
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                    decorationThickness: 1.2,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Toggle card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [cardShadow],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile.adaptive(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    title: const Text(
                      'Rent reporting',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    value: _enabled,
                    activeColor:
                        const Color(0xFF6A5AE0), // purple-ish like mock
                    onChanged: (v) {
                      setState(() => _enabled = v);
                      _savePref(v);
                    },
                  ),
                  const Divider(height: 1, color: Color(0xFFECECEC)),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 10, 16, 16),
                    child: Text(
                      'Reporting preferences must be made by the 20th of the month to apply to the current month.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TickRow extends StatelessWidget {
  final String text;
  const _TickRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_circle_outline, size: 22, color: Colors.black87),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              height: 1.25,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
