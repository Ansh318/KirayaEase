import 'package:flutter/material.dart';
import '../widgets/footer.dart';

class LearnPage extends StatelessWidget {
  const LearnPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9FCFB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: const Text(
          "Learn & Resources",
          style: TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    "Everything you need to know about paying rent, and making the most of KirayaEase.",
                    style: TextStyle(fontSize: 15, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // Cards
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 16,
                    children: const [
                      LearnCard(
                        title: "Getting Started Guide",
                        description:
                            "New to KirayaEase? Learn how to set up your account and get the most out of our platform.",
                      ),
                      LearnCard(
                        title: "Rental Market Insights",
                        description:
                            "Stay updated with the latest rental market trends and pricing information.",
                      ),
                      LearnCard(
                        title: "Legal Resources",
                        description:
                            "Understand your rights and responsibilities as a landlord or tenant.",
                      ),
                      LearnCard(
                        title: "FAQ",
                        description:
                            "Find answers to the most commonly asked questions about our platform.",
                      ),
                    ],
                  ),

                  // Small, sane spacing before footer
                  const SizedBox(height: 16),

                  // Footer lives inside the scroll; no pinning, no overlaps
                  const Footer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LearnCard extends StatelessWidget {
  final String title;
  final String description;
  const LearnCard({super.key, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: Card(
        color: Colors.white, // force white background
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
