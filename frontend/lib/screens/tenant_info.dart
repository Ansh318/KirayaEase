import 'package:flutter/material.dart';

class TenantInfo extends StatelessWidget {
  const TenantInfo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9FCFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE9FCFB),
        elevation: 0,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: const Text("For Tenants",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 12),
            const Text(
              "Make renting easier with KirayaEase. Pay rent, split expenses, and manage your rental life in one place.",
              style: TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Only the bullet points card, no dashboard preview
            Container(
              width: double.infinity,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text("KirayaEase is for tenants",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                  SizedBox(height: 12),
                  Bullet(
                      text:
                          "Schedule your rent payments at your convenience with flexible timing options"),
                  Bullet(
                      text:
                          "Break down your rent into manageable payments to help you budget better"),
                  Bullet(
                      text:
                          "Build your credit score with on-time rent payments"),
                  Bullet(text: "No binding long-term commitments required"),
                  Bullet(
                      text:
                          "Split expenses and manage your rental life in one place"),
                  SizedBox(height: 16),
                  Center(
                    child: ElevatedButton(
                      onPressed: null,
                      style: ButtonStyle(
                        backgroundColor: MaterialStatePropertyAll(Colors.teal),
                        padding: MaterialStatePropertyAll(
                            EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                      ),
                      child: Text("View Demo"),
                    ),
                  )
                ],
              ),
            ),

            const SizedBox(height: 32),

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
                  Text("Rent Simple. Live Easy.",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  Text(
                    "Financial freedom starts with simple rent management",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.black54),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: const [
                BenefitCard(
                  title: "Convenient payment scheduling",
                  desc:
                      "Schedule your rent payments at your convenience with flexible timing options that work with your budget.",
                ),
                BenefitCard(
                  title: "Encourages better budgeting",
                  desc:
                      "Break down your rent into manageable payments to help you budget better and maintain financial stability.",
                ),
                BenefitCard(
                  title: "Builds credit history",
                  desc:
                      "Your on-time rent payments help build your credit score, improving your financial future.",
                ),
                BenefitCard(
                  title: "No long term contract",
                  desc:
                      "Flexibility when you need it most with no binding long-term commitments required.",
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
