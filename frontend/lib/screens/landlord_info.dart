import 'package:flutter/material.dart';

class LandlordInfoPage extends StatelessWidget {
  const LandlordInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9FCFB),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            const Text(
              "For Landlords",
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              "Maximize your rental yield with KirayaEase. From boosting Net Operating Income to simulating virtual portfolios, we’ve got you covered.",
              style: TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Feature + Dashboard Box
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, 4))
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left column: bullets
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text("KirayaEase is for property managers",
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w600)),
                        SizedBox(height: 12),
                        Bullet(
                            text:
                                "Higher retention rates & renter satisfaction"),
                        Bullet(
                            text:
                                "Integration with property management systems and Payment portals"),
                        Bullet(
                            text:
                                "Stronger financial forecasting with predictable payments"),
                        Bullet(
                            text:
                                "Reduce overhead, increase staff productivity"),
                        Bullet(text: "Free of cost to operators"),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: null,
                          style: ButtonStyle(
                            backgroundColor:
                                MaterialStatePropertyAll(Colors.teal),
                            padding: MaterialStatePropertyAll(
                                EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12)),
                          ),
                          child: Text("View Demo"),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Right column: simulated dashboard UI
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F9F8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("KirayaEase",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          const Text("Dashboard > Residents",
                              style: TextStyle(
                                  fontSize: 13, color: Colors.black54)),
                          const SizedBox(height: 12),
                          Container(
                            height: 120,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white,
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: const Center(
                              child: Text("Simulated Resident Table",
                                  style: TextStyle(color: Colors.black45)),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Tagline
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 10)
                ],
              ),
              child: Column(
                children: const [
                  Text("Put rent management on autopilot",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  Text(
                    "Empower greater cash flow management",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.black54),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Benefit Cards
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: const [
                BenefitCard(
                  title: "Tenant Screening",
                  desc:
                      "Comprehensive background checks and credit verification to help you find reliable tenants.",
                ),
                BenefitCard(
                  title: "Automated Rent Collection",
                  desc:
                      "Set up automatic rent collection and never worry about late payments again.",
                ),
                BenefitCard(
                  title: "Property Management",
                  desc:
                      "Manage multiple properties, track expenses, and generate financial reports.",
                ),
              ],
            ),
            const SizedBox(height: 48),
          ],
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
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(desc, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}
