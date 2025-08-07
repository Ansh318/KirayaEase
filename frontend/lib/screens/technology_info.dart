import 'package:flutter/material.dart';
import '../widgets/footer.dart';

class TechnologyInfo extends StatelessWidget {
  const TechnologyInfo({super.key});

  @override
  Widget build(BuildContext context) {
    final techList = [
      {
        'title': 'Artificial Intelligence',
        'description':
            'Automates rent agreements and support using smart assistants.',
        'icon': '🧠',
      },
      {
        'title': 'Machine Learning',
        'description':
            'Learns tenant behavior to offer insights and forecasts.',
        'icon': '📈',
      },
      {
        'title': 'Cloud',
        'description': 'Securely stores data and powers real-time operations.',
        'icon': '☁️',
      },
      {
        'title': 'Security',
        'description':
            'Protects sensitive information using encryption & compliance.',
        'icon': '🔐',
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFE9FCFB),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 24),
                  const Text(
                    "Our Technology",
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Built with cutting-edge technology to provide a seamless rental experience for everyone.",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ...techList.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 20, horizontal: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.teal,
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${item['icon']} ${item['title']}',
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      item['description']!,
                                      style: const TextStyle(
                                          fontSize: 15, color: Colors.black87),
                                    ),
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList()
                ],
              ),
            ),
            const Footer(), // ✅ Added footer
          ],
        ),
      ),
    );
  }
}
