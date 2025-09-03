import 'package:flutter/material.dart';

class LandlordInfoPage extends StatelessWidget {
  const LandlordInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
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
          "Landlord Info",
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
                  // Feature Box
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "AI for the Everyday Landlord",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 12),
                        Bullet(
                            text:
                                "Higher retention rates & renter satisfaction"),
                        Bullet(
                            text:
                                "Stronger financial forecasting with predictable payments"),
                        Bullet(
                            text:
                                "Reduce overhead, increase staff productivity"),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Tagline Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 24, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 10),
                      ],
                    ),
                    child: const Column(
                      children: [
                        Text(
                          "Cash flow, without the chaos.",
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Simplify rent. Maximize returns. Stress-free every month.",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 15, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Benefit Cards
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 16,
                    children: const [
                      BenefitCard(
                        title: "Smart Tenant Screening",
                        desc:
                            "Onboard trusted renters fast with instant background checks and credit insights.",
                      ),
                      BenefitCard(
                        title: "Never Miss a Rent Payment",
                        desc:
                            "Automated payments keep cash flowing — on time, every time.",
                      ),
                      BenefitCard(
                        title: "AI-Powered Rent Manager",
                        desc:
                            "Track properties, cut expenses, and get clear financial insights before your next lease cycle.",
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Bullet extends StatelessWidget {
  final String text;
  const Bullet({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("• ", style: TextStyle(fontSize: 16)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

class BenefitCard extends StatelessWidget {
  final String title;
  final String desc;
  const BenefitCard({super.key, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: Card(
        color: Colors.white, // force consistent white background
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                desc,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
