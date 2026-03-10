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
                      ),
                      _ValueTile(
                        label: 'Accessible',
                      ),
                      _ValueTile(
                        label: 'Actionable',
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
                      "Our mission is to simplify rental management for modern landlords. With Agentic AI, KirayaEase helps property owners stay organized, reduce manual work, and run their rentals on autopilot.",
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

  const _ValueTile({
    required this.label,
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
        ],
      ),
    );
  }
}
