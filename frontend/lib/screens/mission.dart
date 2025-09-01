import 'package:flutter/material.dart';
import '../widgets/footer.dart';

class MissionSection extends StatelessWidget {
  const MissionSection({super.key});

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFFEFFFFD);
    const highlightColor = Color(0xFF00C6A6);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Our Mission'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // AAA section at the top
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: const [
                      _ValueTile(
                        label: 'Affordable',
                        desc:
                            'Smart, low-cost solutions for easy rental access.',
                      ),
                      _ValueTile(
                        label: 'Accessible',
                        desc: 'Seamless experience designed for everyone.',
                      ),
                      _ValueTile(
                        label: 'Actionable',
                        desc: 'Turn rent data into clear, immediate actions.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Mission statement block below
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border:
                          Border.all(color: highlightColor.withOpacity(0.3)),
                    ),
                    child: const Text(
                      "KirayaEase is on a mission to revolutionize India’s rental real estate landscape by breaking down the barriers of fragmentation and inefficiency that have long defined the sector. We envision a future where every tenant, landlord, and real estate professional can access rental intelligence that is actionable, empowering, and sustainable. Our goal is to make rental real estate an accessible, intelligently managed asset class by making it smarter, fairer, and informed.",
                      style: TextStyle(fontSize: 15, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          const Footer()
        ],
      ),
    );
  }
}

class _ValueTile extends StatelessWidget {
  final String label;
  final String desc;

  const _ValueTile({
    required this.label,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    const circleColor = Color(0xFFB8F4EA);
    const circleText = 'A';

    return Flexible(
      child: Column(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: circleColor,
            child: const Text(
              circleText,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            style: const TextStyle(fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
