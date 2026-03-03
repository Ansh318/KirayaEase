import 'package:flutter/material.dart';
import '../widgets/footer.dart';

class TenantInfo extends StatelessWidget {
  const TenantInfo({super.key});

  static const Color kBg = Color(0xFFE9FCFB);
  static const Color kAccent = Color(0xFF00C6A6);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
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

            _InfoSection(
              heading: "Tenant Value",
              title: "Rent Without the Stress.",
              subtitle:
                  "Stay on time. Build Credibility. Avoid surprises.",
              benefits: const [
                _BenefitItem(
                  title: "Convenient Scheduling",
                  desc: "Pay rent on your own schedule.",
                ),
                _BenefitItem(
                  title: "Smarter Budgeting",
                  desc: "Split rent into smaller chunks.",
                ),
                _BenefitItem(
                  title: "Build Credit",
                  desc: "On-time payments boost your score.",
                ),
                _BenefitItem(
                  title: "No Lock-Ins",
                  desc: "Flexibility without long contracts.",
                ),
              ],
            ),
            const SizedBox(height: 48),

            // Footer at bottom
            const Footer(),
          ],
        ),
      ),
    );
  }
}

class BenefitCard extends StatelessWidget {
  final int? number; // optional, but we'll use it in .numbered
  final String title;
  final String desc;

  const BenefitCard({
    super.key,
    this.number,
    required this.title,
    required this.desc,
  });

  const BenefitCard.numbered({
    super.key,
    required this.number,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    const kAccent = TenantInfo.kAccent;

    return SizedBox(
      width: 300,
      child: Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row with numbered badge and title
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (number != null)
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: kAccent,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black12,
                              blurRadius: 6,
                              offset: Offset(0, 2)),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "$number",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 28, height: 28),

                  const SizedBox(width: 12),

                  // Title + description
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          desc,
                          style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Decorative progress underline
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 4,
                  child: Stack(
                    children: [
                      Container(color: const Color(0xFFECECEC)),
                      FractionallySizedBox(
                        widthFactor: 0.35,
                        child: Container(color: kAccent),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String heading;
  final String title;
  final String subtitle;
  final List<_BenefitItem> benefits;

  const _InfoSection({
    required this.heading,
    required this.title,
    required this.subtitle,
    required this.benefits,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
          ),
          child: Column(
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: Colors.black54),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: List.generate(
            benefits.length,
            (index) => BenefitCard.numbered(
              number: index + 1,
              title: benefits[index].title,
              desc: benefits[index].desc,
            ),
          ),
        ),
      ],
    );
  }
}

class _BenefitItem {
  final String title;
  final String desc;

  const _BenefitItem({required this.title, required this.desc});
}
