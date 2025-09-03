import 'package:flutter/material.dart';
import '../widgets/footer.dart';

class TechnologyInfo extends StatelessWidget {
  const TechnologyInfo({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> techList = [
      {
        'title': 'Automation',
        'description':
            'No paperwork, no chasing — agreements & payments flow on autopilot.',
      },
      {
        'title': 'Intelligence',
        'description':
            'Spot market shifts early — from yields to tenant patterns.',
      },
      {
        'title': 'Cloud',
        'description': 'From 1 flat to a 100 — built to grow with you.',
      },
      {
        'title': 'Trust',
        'description': 'RBI Compliant and 256-bit Encrypted.',
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFE9FCFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE9FCFB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Technology",
          style: TextStyle(color: Colors.black87),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 12),
                  const Text(
                    "Built with cutting-edge technology to provide a seamless rental experience for landlords and tenants.",
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Tech cards
                  ...techList.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Card(
                        color: Colors.white, // pure white background
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 20,
                            horizontal: 16,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: const Color.fromARGB(
                                    255, 26, 205, 187), // ✅ greenish badge
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['title']!,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      item['description']!,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),

                  const SizedBox(height: 16),
                  const Footer(), // footer after content
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
