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
        title: const Text(
          "Tenant Info",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            // Tagline card
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
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
                    "AI for the Everyday Tenant.",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Financial flexibility starts with smarter rent management",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.black54),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Benefit Cards (concise copy + consistent white)
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: const [
                BenefitCard(
                  title: "Convenient Scheduling",
                  desc: "Pay rent on your own schedule.",
                ),
                BenefitCard(
                  title: "Smarter Budgeting",
                  desc: "Split rent into smaller chunks.",
                ),
                BenefitCard(
                  title: "Build Credit",
                  desc: "On-time payments boost your score.",
                ),
                BenefitCard(
                  title: "No Lock-Ins",
                  desc: "Flexibility without long contracts.",
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
        color: Colors.white,
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
