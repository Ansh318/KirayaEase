import 'package:flutter/material.dart';

/// KirayaEase brand colors for pricing page
class _PricingColors {
  static const Color primary = Color(0xFF00C6A6);
  static const Color bg = Color(0xFFEFFFFD);
  static const Color cardBg = Colors.white;
  static const Color ink = Color(0xFF111827);
  static const Color sub = Color(0xFF6B7280);
}

class PricingPlan {
  final String name;
  final String price;
  final String propertyLimit;
  final String description;
  final bool recommended;

  const PricingPlan({
    required this.name,
    required this.price,
    required this.propertyLimit,
    required this.description,
    this.recommended = false,
  });
}

class PricingPage extends StatelessWidget {
  const PricingPage({super.key});

  static const List<PricingPlan> plans = [
    PricingPlan(
      name: 'Starter Plan',
      price: '₹499',
      propertyLimit: 'Up to 5 properties',
      description: 'Ideal for independent landlords managing a few rental units.',
    ),
    PricingPlan(
      name: 'Growth Plan',
      price: '₹999',
      propertyLimit: '5–10 properties',
      description: 'For landlords growing their rental portfolio.',
      recommended: true,
    ),
    PricingPlan(
      name: 'Pro Plan',
      price: '₹1499',
      propertyLimit: '10–15 properties',
      description: 'Designed for landlords managing larger portfolios.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _PricingColors.bg,
      appBar: AppBar(
        backgroundColor: _PricingColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
          onPressed: () => Navigator.maybePop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Pricing',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.black87,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ...plans.map((plan) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _PricingCard(plan: plan),
                )),
          ],
        ),
      ),
    );
  }
}

class _PricingCard extends StatelessWidget {
  final PricingPlan plan;

  const _PricingCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final isRecommended = plan.recommended;

    return Container(
      decoration: BoxDecoration(
        color: _PricingColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRecommended
              ? _PricingColors.primary
              : _PricingColors.primary.withOpacity(0.2),
          width: isRecommended ? 2.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isRecommended ? 0.08 : 0.04),
            blurRadius: isRecommended ? 16 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (isRecommended)
            Positioned(
              top: -10,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: _PricingColors.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: _PricingColors.primary.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Recommended',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, isRecommended ? 26 : 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  plan.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _PricingColors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      plan.price,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: _PricingColors.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      '/ month',
                      style: TextStyle(
                        fontSize: 14,
                        color: _PricingColors.sub,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.home_work_outlined,
                      size: 18,
                      color: _PricingColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        plan.propertyLimit,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _PricingColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  plan.description,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: _PricingColors.sub,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
